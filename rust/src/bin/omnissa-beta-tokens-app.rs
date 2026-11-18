//! Native macOS GUI (egui) — same Rust core as the CLI.
//!
//! Callers: `tools/make_app.sh` via `cargo build --release --bin omnissa-beta-tokens-app`
//! (bundles as Contents/MacOS/OmnissaBetaTokens). No other GUI entry exists (SwiftUI removed).
//! Data: local workdir key/cert/*.p7m under ~/.omnissa-beta-tokens; Apple ABM via shared lib.
//! User: "yeah do whatever works best here. Convert as well." → egui rewrite of the macOS app.

use std::path::PathBuf;
use std::process::Command;
use std::sync::mpsc::{self, Receiver, TryRecvError};
use std::thread;

use eframe::egui::{self, Color32, RichText, Sense, Vec2};
use eframe::App;

use omnissa_beta_tokens::abm::{self, default_transport};
use omnissa_beta_tokens::credentials::{access_token_expired, BetaToken};
use omnissa_beta_tokens::render::{self, uem_paste_block};
use omnissa_beta_tokens::servertoken::{self, CERT_NAME, KEY_NAME};

const SERVICE_NAME: &str = "Workspace One Beta Token Service";
const APPLE_ADD_URL: &str =
    "https://business.apple.com/main/devices/managementservices/mdmservers/add";

const NAVY: Color32 = Color32::from_rgb(0x00, 0x1E, 0x60);
const INDIGO: Color32 = Color32::from_rgb(0x4A, 0x12, 0xF0);
const MAGENTA: Color32 = Color32::from_rgb(0xD6, 0x00, 0xFF);
const MUTED: Color32 = Color32::from_rgb(0x6E, 0x6E, 0x73);
const TEXT: Color32 = Color32::from_rgb(0x1D, 0x1D, 0x1F);
const CARD: Color32 = Color32::from_rgb(0xFF, 0xFF, 0xFF);
const SURFACE: Color32 = Color32::from_rgb(0xF5, 0xF5, 0xF7);

fn default_workdir() -> PathBuf {
    std::env::var_os("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("."))
        .join(".omnissa-beta-tokens")
}

fn has_keypair(workdir: &std::path::Path) -> bool {
    workdir.join(KEY_NAME).is_file() && workdir.join(CERT_NAME).is_file()
}

fn copy_clipboard(text: &str) -> bool {
    Command::new("pbcopy")
        .stdin(std::process::Stdio::piped())
        .spawn()
        .and_then(|mut c| {
            if let Some(mut stdin) = c.stdin.take() {
                use std::io::Write;
                stdin.write_all(text.as_bytes())?;
            }
            c.wait().map(|s| s.success())
        })
        .unwrap_or(false)
}

fn open_url(url: &str) {
    let _ = Command::new("open").arg(url).spawn();
}

fn reveal_in_finder(path: &std::path::Path) {
    let _ = Command::new("open")
        .args(["-R", &path.to_string_lossy()])
        .spawn();
}

enum FetchMsg {
    Ok {
        tokens: Vec<BetaToken>,
        expired: bool,
        expiry: String,
    },
    Err(String),
}

struct BetaApp {
    workdir: PathBuf,
    has_keypair: bool,
    p7m: Option<PathBuf>,
    tokens: Vec<BetaToken>,
    search: String,
    os_filter: String,
    selected: Option<usize>,
    reveal_token: bool,
    message: Option<String>,
    error: Option<String>,
    confirm_teardown: bool,
    fetch_rx: Option<Receiver<FetchMsg>>,
    fetching: bool,
}

impl BetaApp {
    fn new(cc: &eframe::CreationContext<'_>) -> Self {
        let mut style = (*cc.egui_ctx.style()).clone();
        style.visuals.window_fill = SURFACE;
        style.visuals.panel_fill = SURFACE;
        style.visuals.override_text_color = Some(TEXT);
        cc.egui_ctx.set_style(style);
        try_load_outfit(&cc.egui_ctx);

        let workdir = default_workdir();
        let p7m = servertoken::find_p7m(&workdir);
        Self {
            has_keypair: has_keypair(&workdir),
            workdir,
            p7m,
            tokens: Vec::new(),
            search: String::new(),
            os_filter: "All".into(),
            selected: None,
            reveal_token: false,
            message: None,
            error: None,
            confirm_teardown: false,
            fetch_rx: None,
            fetching: false,
        }
    }

    fn refresh(&mut self) {
        self.has_keypair = has_keypair(&self.workdir);
        if self.p7m.is_none() {
            self.p7m = servertoken::find_p7m(&self.workdir);
        }
    }

    fn filtered(&self) -> Vec<(usize, &BetaToken)> {
        let os = if self.os_filter == "All" {
            None
        } else {
            Some(self.os_filter.as_str())
        };
        let match_text = if self.search.trim().is_empty() {
            None
        } else {
            Some(self.search.as_str())
        };
        let filtered = render::filter_tokens(&self.tokens, os, match_text);
        self.tokens
            .iter()
            .enumerate()
            .filter(|(_, t)| filtered.iter().any(|f| f.title == t.title && f.token == t.token))
            .collect()
    }

    fn os_options(&self) -> Vec<String> {
        let mut set: Vec<String> = self
            .tokens
            .iter()
            .map(|t| t.os_display().to_string())
            .collect();
        set.sort_by_key(|s| s.to_ascii_lowercase());
        set.dedup();
        let mut out = vec!["All".into()];
        out.extend(set);
        out
    }

    fn create_cert(&mut self) {
        self.error = None;
        match servertoken::generate_keypair(&self.workdir, 365) {
            Ok((_, cert)) => {
                self.message = Some(
                    "Certificate created. Upload the .pem to Apple Business, then download the .p7m."
                        .into(),
                );
                self.refresh();
                reveal_in_finder(&cert);
            }
            Err(e) => self.error = Some(e.to_string()),
        }
    }

    fn start_fetch(&mut self) {
        let Some(p7m) = self.p7m.clone() else {
            return;
        };
        if !self.has_keypair || self.fetching {
            return;
        }
        self.fetching = true;
        self.error = None;
        self.message = None;
        let workdir = self.workdir.clone();
        let (tx, rx) = mpsc::channel();
        self.fetch_rx = Some(rx);
        thread::spawn(move || {
            let result = (|| {
                let creds = servertoken::decrypt_server_token(&p7m, &workdir)?;
                let expired = access_token_expired(&creds, None);
                let expiry = creds.access_token_expiry.clone();
                let transport = default_transport();
                let tokens = abm::fetch_beta_tokens(&creds, &transport)?;
                Ok::<_, omnissa_beta_tokens::ToolError>((tokens, expired, expiry))
            })();
            let _ = tx.send(match result {
                Ok((tokens, expired, expiry)) => FetchMsg::Ok {
                    tokens,
                    expired,
                    expiry,
                },
                Err(e) => FetchMsg::Err(e.to_string()),
            });
        });
    }

    fn poll_fetch(&mut self) {
        let Some(rx) = &self.fetch_rx else {
            return;
        };
        match rx.try_recv() {
            Ok(FetchMsg::Ok {
                tokens,
                expired,
                expiry,
            }) => {
                self.fetching = false;
                self.fetch_rx = None;
                self.tokens = tokens;
                self.selected = None;
                if expired {
                    self.error = Some(format!(
                        "The Apple Business server token expired{}. Regenerate the .p7m in Apple Business.",
                        if expiry.is_empty() {
                            String::new()
                        } else {
                            format!(" ({expiry})")
                        }
                    ));
                    self.message = Some(format!(
                        "Loaded {} beta programs, but the server token is expired.",
                        self.tokens.len()
                    ));
                } else {
                    self.message = Some(format!("Loaded {} beta programs.", self.tokens.len()));
                }
            }
            Ok(FetchMsg::Err(e)) => {
                self.fetching = false;
                self.fetch_rx = None;
                self.tokens.clear();
                self.error = Some(e);
            }
            Err(TryRecvError::Empty) => {}
            Err(TryRecvError::Disconnected) => {
                self.fetching = false;
                self.fetch_rx = None;
                self.error = Some("Fetch cancelled.".into());
            }
        }
    }

    fn teardown(&mut self) {
        self.error = None;
        match servertoken::cleanup_workdir(&self.workdir) {
            Ok(_) => {
                self.p7m = None;
                self.tokens.clear();
                self.selected = None;
                self.refresh();
                self.message = Some(format!(
                    "Deleted local key, certificate, and .p7m files. Also delete the \"{SERVICE_NAME}\" management service in Apple Business if you no longer need it."
                ));
            }
            Err(e) => self.error = Some(e.to_string()),
        }
        self.confirm_teardown = false;
    }

    fn set_note(&mut self, note: impl Into<String>) {
        self.message = Some(note.into());
        self.error = None;
    }
}

fn try_load_outfit(ctx: &egui::Context) {
    let candidates = [
        PathBuf::from("Fonts"),
        PathBuf::from("../Resources/Fonts"),
        {
            let mut p = std::env::current_exe().unwrap_or_default();
            p.pop();
            p.pop();
            p.push("Resources");
            p.push("Fonts");
            p
        },
    ];
    for dir in candidates {
        let light = dir.join("Outfit-Light.ttf");
        if light.is_file() {
            let mut fonts = egui::FontDefinitions::default();
            if let Ok(bytes) = std::fs::read(&light) {
                fonts
                    .font_data
                    .insert("Outfit".into(), egui::FontData::from_owned(bytes).into());
                fonts
                    .families
                    .entry(egui::FontFamily::Proportional)
                    .or_default()
                    .insert(0, "Outfit".into());
            }
            ctx.set_fonts(fonts);
            return;
        }
    }
}

fn header_ui(ui: &mut egui::Ui) {
    let rect = ui.available_rect_before_wrap();
    let h = 88.0;
    let header = egui::Rect::from_min_size(rect.min, Vec2::new(rect.width(), h));
    let painter = ui.painter_at(header);
    painter.rect_filled(header, 0.0, NAVY);
    let mid = header.left() + header.width() * 0.45;
    painter.rect_filled(
        egui::Rect::from_min_max(
            egui::pos2(mid, header.top()),
            egui::pos2(header.right(), header.bottom()),
        ),
        0.0,
        INDIGO,
    );
    painter.rect_filled(
        egui::Rect::from_min_max(
            egui::pos2(header.right() - header.width() * 0.22, header.top()),
            egui::pos2(header.right(), header.bottom()),
        ),
        0.0,
        MAGENTA,
    );
    ui.allocate_new_ui(
        egui::UiBuilder::new().max_rect(header.shrink2(Vec2::new(20.0, 14.0))),
        |ui| {
            ui.vertical(|ui| {
                ui.label(
                    RichText::new("OMNISSA  |  WORKSPACE ONE UEM")
                        .size(11.0)
                        .color(Color32::from_white_alpha(230)),
                );
                ui.label(
                    RichText::new("Beta Token Utility")
                        .size(26.0)
                        .strong()
                        .color(Color32::WHITE),
                );
                ui.label(
                    RichText::new(
                        "Get Apple beta enrollment tokens for your declarative Software Update profile.",
                    )
                    .size(13.0)
                    .color(Color32::from_white_alpha(220)),
                );
            });
        },
    );
    ui.add_space(h);
}

fn card(ui: &mut egui::Ui, number: u32, title: &str, add: impl FnOnce(&mut egui::Ui)) {
    egui::Frame::NONE
        .fill(CARD)
        .corner_radius(12.0)
        .inner_margin(16.0)
        .stroke(egui::Stroke::new(
            1.0_f32,
            Color32::from_rgb(0xD1, 0xD1, 0xD6),
        ))
        .shadow(egui::Shadow {
            offset: [0, 4],
            blur: 12,
            spread: 0,
            color: Color32::from_black_alpha(25),
        })
        .show(ui, |ui| {
            ui.horizontal(|ui| {
                let (rect, _) = ui.allocate_exact_size(Vec2::splat(22.0), Sense::hover());
                ui.painter().circle_filled(rect.center(), 11.0, INDIGO);
                ui.painter().text(
                    rect.center(),
                    egui::Align2::CENTER_CENTER,
                    number.to_string(),
                    egui::FontId::proportional(12.0),
                    Color32::WHITE,
                );
                ui.label(RichText::new(title).size(15.0).strong().color(NAVY));
            });
            ui.add_space(8.0);
            add(ui);
        });
    ui.add_space(12.0);
}

impl App for BetaApp {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        self.poll_fetch();
        if self.fetching {
            ctx.request_repaint();
        }

        egui::CentralPanel::default()
            .frame(egui::Frame::NONE.fill(SURFACE))
            .show(ctx, |ui| {
                header_ui(ui);
                egui::ScrollArea::vertical()
                    .auto_shrink([false, false])
                    .show(ui, |ui| {
                        ui.add_space(12.0);
                        ui.horizontal(|ui| {
                            ui.add_space(20.0);
                            ui.vertical(|ui| {
                                ui.set_max_width(ui.available_width() - 20.0);
                                self.steps(ui);
                            });
                        });
                    });
            });

        if self.confirm_teardown {
            egui::Window::new("Delete local credentials?")
                .collapsible(false)
                .resizable(false)
                .anchor(egui::Align2::CENTER_CENTER, [0.0, 0.0])
                .show(ctx, |ui| {
                    ui.label(format!(
                        "This deletes the private key, certificate, and any .p7m files in {}.\nAlso delete the management service in Apple Business if you no longer need it.",
                        self.workdir.display()
                    ));
                    ui.horizontal(|ui| {
                        if ui
                            .add(
                                egui::Button::new(RichText::new("Delete").color(Color32::WHITE))
                                    .fill(MAGENTA),
                            )
                            .clicked()
                        {
                            self.teardown();
                        }
                        if ui.button("Cancel").clicked() {
                            self.confirm_teardown = false;
                        }
                    });
                });
        }
    }
}

impl BetaApp {
    fn steps(&mut self, ui: &mut egui::Ui) {
        card(ui, 1, "Create certificate", |ui| {
            ui.label(
                RichText::new(
                    "In Apple Business go to Devices > Management Services > Add, name the service, and upload the .pem file. Then download the .p7m server token.",
                )
                .size(13.0)
                .color(TEXT),
            );
            ui.add_space(6.0);
            ui.horizontal(|ui| {
                ui.label(RichText::new("Service name:").size(12.0).color(MUTED));
                ui.monospace(SERVICE_NAME);
                if ui.button("Copy name").clicked()
                    && copy_clipboard(SERVICE_NAME)
                {
                    self.set_note(
                        "Service name copied. Paste it into the Service Name field in Apple Business.",
                    );
                }
            });
            ui.horizontal(|ui| {
                if self.has_keypair {
                    ui.colored_label(Color32::from_rgb(0x24, 0x8A, 0x3D), "Certificate ready");
                    if ui.button("Show in Finder").clicked() {
                        reveal_in_finder(&self.workdir.join(CERT_NAME));
                    }
                } else if ui
                    .add(
                        egui::Button::new(
                            RichText::new("Create certificate").color(Color32::WHITE),
                        )
                        .fill(INDIGO),
                    )
                    .clicked()
                {
                    self.create_cert();
                }
                if ui.button("Open Apple Business").clicked() {
                    let _ = copy_clipboard(SERVICE_NAME);
                    open_url(APPLE_ADD_URL);
                    self.set_note(
                        "Service name copied. Paste it into the Service Name field in Apple Business.",
                    );
                }
                if (self.has_keypair || self.p7m.is_some())
                    && ui.button("Delete local credentials…").clicked()
                {
                    self.confirm_teardown = true;
                }
            });
        });

        card(ui, 2, "Choose server token (.p7m)", |ui| {
            ui.horizontal(|ui| {
                if ui.button("Choose file…").clicked() {
                    if let Some(path) = rfd::FileDialog::new()
                        .add_filter("Apple server token", &["p7m"])
                        .pick_file()
                    {
                        self.p7m = Some(path);
                    }
                }
                let label = self
                    .p7m
                    .as_ref()
                    .and_then(|p| p.file_name())
                    .map(|s| s.to_string_lossy().into_owned())
                    .unwrap_or_else(|| "No file selected".into());
                ui.label(RichText::new(label).size(12.0).color(MUTED));
            });
        });

        card(ui, 3, "Get beta programs", |ui| {
            ui.horizontal(|ui| {
                let can = self.p7m.is_some() && self.has_keypair && !self.fetching;
                if ui
                    .add_enabled(
                        can,
                        egui::Button::new(
                            RichText::new(if self.fetching {
                                "Fetching…"
                            } else {
                                "Fetch beta tokens"
                            })
                            .color(Color32::WHITE),
                        )
                        .fill(INDIGO),
                    )
                    .clicked()
                {
                    self.start_fetch();
                }
                if self.fetching {
                    ui.spinner();
                }
            });
        });

        if !self.tokens.is_empty() {
            let os_opts = self.os_options();
            card(ui, 4, "Choose a program", |ui| {
                ui.horizontal(|ui| {
                    ui.label("OS");
                    egui::ComboBox::from_id_salt("os_filter")
                        .selected_text(&self.os_filter)
                        .show_ui(ui, |ui| {
                            for o in &os_opts {
                                ui.selectable_value(&mut self.os_filter, o.clone(), o);
                            }
                        });
                    ui.label("Search");
                    ui.text_edit_singleline(&mut self.search);
                });
                ui.add_space(6.0);

                let filtered: Vec<(usize, BetaToken)> = self
                    .filtered()
                    .into_iter()
                    .map(|(i, t)| (i, t.clone()))
                    .collect();

                egui::ScrollArea::vertical()
                    .max_height(200.0)
                    .show(ui, |ui| {
                        for (idx, t) in &filtered {
                            let selected = self.selected == Some(*idx);
                            let label = format!("{}  —  {}", t.title, t.os_display());
                            if ui.selectable_label(selected, label).clicked() {
                                self.selected = Some(*idx);
                            }
                        }
                    });

                if let Some(idx) = self.selected {
                    if let Some(t) = self.tokens.get(idx).cloned() {
                        ui.add_space(8.0);
                        ui.separator();
                        ui.label(RichText::new(&t.title).size(15.0).strong().color(NAVY));
                        let unsupported =
                            render::unsupported_uem_beta_oses(std::slice::from_ref(&t));
                        if !unsupported.is_empty() {
                            ui.colored_label(
                                MAGENTA,
                                format!(
                                    "{} is not supported: the Beta setting cannot deliver this program via Software Update:Settings.",
                                    t.os_display()
                                ),
                            );
                        }
                        ui.horizontal(|ui| {
                            let shown = if self.reveal_token {
                                t.token.clone()
                            } else {
                                t.masked_token()
                            };
                            ui.monospace(shown);
                            ui.checkbox(&mut self.reveal_token, "Reveal");
                            if ui
                                .add(
                                    egui::Button::new(
                                        RichText::new("Copy token").color(Color32::WHITE),
                                    )
                                    .fill(INDIGO),
                                )
                                .clicked()
                                && copy_clipboard(&t.token)
                            {
                                self.set_note("Token copied to clipboard.");
                            }
                            if ui.button("Copy for UEM").clicked() {
                                let block = uem_paste_block(&t);
                                if copy_clipboard(&block) {
                                    self.set_note(
                                        "UEM paste block copied (title, token, and field checklist).",
                                    );
                                }
                            }
                        });
                        ui.label(
                            RichText::new(
                                "Workspace ONE UEM Software Update:Settings > Beta — Mode guidance is field checklist only (not declaration JSON).",
                            )
                            .size(12.0)
                            .color(MUTED),
                        );
                    }
                }
            });
        }

        if let Some(e) = &self.error {
            ui.colored_label(MAGENTA, format!("⚠ {e}"));
        } else if let Some(m) = &self.message {
            ui.colored_label(MUTED, format!("ℹ {m}"));
        }
    }
}

fn main() -> eframe::Result<()> {
    let options = eframe::NativeOptions {
        viewport: egui::ViewportBuilder::default()
            .with_inner_size([820.0, 720.0])
            .with_min_inner_size([640.0, 520.0])
            .with_title("Omnissa Beta Token Utility"),
        ..Default::default()
    };
    eframe::run_native(
        "Omnissa Beta Token Utility",
        options,
        Box::new(|cc| Ok(Box::new(BetaApp::new(cc)))),
    )
}
