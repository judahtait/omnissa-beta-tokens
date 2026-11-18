//! Native macOS GUI (egui) — same Rust core as the CLI.
//! Visual target: match the prior SwiftUI Brand (gradient header, pill buttons,
//! full-width frosted cards, backdrop glow).
//!
//! Callers: `tools/make_app.sh` via `cargo build --release --bin omnissa-beta-tokens-app`.
//! User: screenshots show egui looked worse than Swift — polish to close the gap.

use std::path::PathBuf;
use std::process::Command;
use std::sync::mpsc::{self, Receiver, TryRecvError};
use std::thread;

use eframe::egui::{self, Color32, CornerRadius, FontFamily, FontId, Frame, Margin, Pos2, Rect, RichText, Sense, Stroke, Vec2};
use eframe::App;

use omnissa_beta_tokens::abm::{self, default_transport};
use omnissa_beta_tokens::credentials::{access_token_expired, BetaToken};
use omnissa_beta_tokens::render::{self, uem_paste_block};
use omnissa_beta_tokens::servertoken::{self, CERT_NAME, KEY_NAME};

const SERVICE_NAME: &str = "Workspace One Beta Token Service";
const APPLE_ADD_URL: &str =
    "https://business.apple.com/main/devices/managementservices/mdmservers/add";

// Omnissa Brand (light) — matches former Brand.swift
const NAVY: Color32 = Color32::from_rgb(0x00, 0x1E, 0x60);
const HEADING: Color32 = Color32::from_rgb(0x1C, 0x1C, 0x20);
const INDIGO: Color32 = Color32::from_rgb(0x4A, 0x12, 0xF0);
const MAGENTA: Color32 = Color32::from_rgb(0xD6, 0x00, 0xFF);
const MUTED: Color32 = Color32::from_rgb(0x6E, 0x6E, 0x73);
const TEXT: Color32 = Color32::from_rgb(0x1D, 0x1D, 0x1F);
const RULE: Color32 = Color32::from_rgb(0xD1, 0xD1, 0xD6);
const CARD: Color32 = Color32::from_rgb(0xFF, 0xFF, 0xFF);
const SURFACE: Color32 = Color32::from_rgb(0xF5, 0xF5, 0xF7);
const OK: Color32 = Color32::from_rgb(0x24, 0x8A, 0x3D);

fn lerp_color(a: Color32, b: Color32, t: f32) -> Color32 {
    let t = t.clamp(0.0, 1.0);
    Color32::from_rgba_unmultiplied(
        (a.r() as f32 + (b.r() as f32 - a.r() as f32) * t) as u8,
        (a.g() as f32 + (b.g() as f32 - a.g() as f32) * t) as u8,
        (a.b() as f32 + (b.b() as f32 - a.b() as f32) * t) as u8,
        255,
    )
}

fn header_gradient_at(t: f32) -> Color32 {
    // navy → indigo → magenta (Swift Brand.headerGradient)
    if t < 0.5 {
        lerp_color(NAVY, INDIGO, t / 0.5)
    } else {
        lerp_color(INDIGO, MAGENTA, (t - 0.5) / 0.5)
    }
}

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
        apply_brand_style(&cc.egui_ctx);
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

fn apply_brand_style(ctx: &egui::Context) {
    let mut style = (*ctx.style()).clone();
    style.spacing.item_spacing = Vec2::new(10.0, 10.0);
    style.spacing.button_padding = Vec2::new(16.0, 8.0);
    style.spacing.window_margin = Margin::same(0);
    style.visuals.window_fill = SURFACE;
    style.visuals.panel_fill = SURFACE;
    style.visuals.override_text_color = Some(TEXT);
    style.visuals.widgets.inactive.corner_radius = CornerRadius::same(255);
    style.visuals.widgets.hovered.corner_radius = CornerRadius::same(255);
    style.visuals.widgets.active.corner_radius = CornerRadius::same(255);
    style.visuals.widgets.inactive.bg_fill = CARD;
    style.visuals.widgets.inactive.fg_stroke = Stroke::new(1.0_f32, INDIGO);
    style.visuals.widgets.hovered.bg_fill = Color32::from_rgb(0xF0, 0xEC, 0xFF);
    style.visuals.widgets.hovered.fg_stroke = Stroke::new(1.0_f32, INDIGO);
    ctx.set_style(style);
}

fn try_load_outfit(ctx: &egui::Context) {
    let mut candidates = vec![
        PathBuf::from("Fonts"),
        PathBuf::from("../Resources/Fonts"),
        PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../assets/fonts"),
    ];
    if let Ok(exe) = std::env::current_exe() {
        let mut p = exe;
        p.pop();
        p.pop();
        p.push("Resources");
        p.push("Fonts");
        candidates.push(p);
    }
    for dir in candidates {
        let light = dir.join("Outfit-Light.ttf");
        let medium = dir.join("Outfit-Medium.ttf");
        if !light.is_file() {
            continue;
        }
        let mut fonts = egui::FontDefinitions::default();
        if let Ok(bytes) = std::fs::read(&light) {
            fonts
                .font_data
                .insert("Outfit".into(), egui::FontData::from_owned(bytes).into());
            fonts
                .families
                .entry(FontFamily::Proportional)
                .or_default()
                .insert(0, "Outfit".into());
        }
        if medium.is_file() {
            if let Ok(bytes) = std::fs::read(&medium) {
                fonts.font_data.insert(
                    "OutfitMedium".into(),
                    egui::FontData::from_owned(bytes).into(),
                );
                fonts
                    .families
                    .entry(FontFamily::Name("OutfitMedium".into()))
                    .or_default()
                    .insert(0, "OutfitMedium".into());
            }
        }
        ctx.set_fonts(fonts);
        return;
    }
}

fn paint_backdrop(ui: &mut egui::Ui) {
    let rect = ui.max_rect();
    let painter = ui.painter();
    painter.rect_filled(rect, 0.0, SURFACE);
    // Soft indigo / magenta glow (Swift GlassBackdrop)
    painter.circle_filled(
        Pos2::new(rect.left() + 80.0, rect.top() + 160.0),
        220.0,
        Color32::from_rgba_unmultiplied(0x4A, 0x12, 0xF0, 40),
    );
    painter.circle_filled(
        Pos2::new(rect.right() - 40.0, rect.bottom() - 80.0),
        200.0,
        Color32::from_rgba_unmultiplied(0xD6, 0x00, 0xFF, 28),
    );
}

fn header_ui(ui: &mut egui::Ui) {
    let full = ui.available_rect_before_wrap();
    let h = 108.0_f32;
    let header = Rect::from_min_size(full.min, Vec2::new(full.width(), h));
    let painter = ui.painter_at(header);

    // Smooth navy → indigo → magenta (many strips — not 3 hard blocks)
    let strips = 96;
    let w = header.width() / strips as f32;
    for i in 0..strips {
        let t = i as f32 / (strips - 1).max(1) as f32;
        let x0 = header.left() + i as f32 * w;
        let strip = Rect::from_min_max(
            Pos2::new(x0, header.top()),
            Pos2::new(x0 + w + 0.6, header.bottom()),
        );
        painter.rect_filled(strip, 0.0, header_gradient_at(t));
    }
    // Top gloss
    painter.rect_filled(
        Rect::from_min_size(header.min, Vec2::new(header.width(), 28.0)),
        0.0,
        Color32::from_white_alpha(28),
    );
    // Magenta/indigo accent rule under header (Swift edge)
    let rule = Rect::from_min_max(
        Pos2::new(header.left(), header.bottom() - 3.0),
        Pos2::new(header.right(), header.bottom()),
    );
    for i in 0..48 {
        let t = i as f32 / 47.0;
        let x0 = rule.left() + rule.width() * (i as f32 / 48.0);
        let x1 = rule.left() + rule.width() * ((i + 1) as f32 / 48.0);
        painter.rect_filled(
            Rect::from_min_max(Pos2::new(x0, rule.top()), Pos2::new(x1, rule.bottom())),
            0.0,
            lerp_color(INDIGO, MAGENTA, t),
        );
    }

    ui.allocate_new_ui(
        egui::UiBuilder::new().max_rect(header.shrink2(Vec2::new(24.0, 18.0))),
        |ui| {
            ui.vertical(|ui| {
                ui.label(
                    RichText::new("OMNISSA  |  WORKSPACE ONE UEM")
                        .size(11.0)
                        .color(Color32::from_white_alpha(230)),
                );
                ui.add_space(2.0);
                ui.label(
                    RichText::new("Beta Token Utility")
                        .size(28.0)
                        .color(Color32::WHITE),
                );
                ui.add_space(2.0);
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

fn pill_primary(ui: &mut egui::Ui, label: &str, enabled: bool) -> egui::Response {
    let text = RichText::new(label).size(13.0).color(Color32::WHITE);
    let fill = if enabled { INDIGO } else { RULE };
    let btn = egui::Button::new(text)
        .fill(fill)
        .corner_radius(CornerRadius::same(255))
        .min_size(Vec2::new(0.0, 32.0));
    ui.add_enabled(enabled, btn)
}

fn pill_secondary(ui: &mut egui::Ui, label: &str) -> egui::Response {
    let text = RichText::new(label).size(13.0).color(INDIGO);
    let btn = egui::Button::new(text)
        .fill(Color32::from_rgba_unmultiplied(255, 255, 255, 200))
        .stroke(Stroke::new(1.2_f32, INDIGO))
        .corner_radius(CornerRadius::same(255))
        .min_size(Vec2::new(0.0, 32.0));
    ui.add(btn)
}

fn card(ui: &mut egui::Ui, number: u32, title: &str, add: impl FnOnce(&mut egui::Ui)) {
    let width = ui.available_width();
    Frame::NONE
        .fill(Color32::from_rgba_unmultiplied(255, 255, 255, 230))
        .corner_radius(16.0)
        .inner_margin(Margin::symmetric(18, 16))
        .stroke(Stroke::new(1.0_f32, Color32::from_rgba_unmultiplied(255, 255, 255, 180)))
        .shadow(egui::Shadow {
            offset: [0, 6],
            blur: 18,
            spread: 0,
            color: Color32::from_black_alpha(28),
        })
        .show(ui, |ui| {
            ui.set_min_width(width - 4.0);
            ui.set_max_width(width);
            ui.horizontal(|ui| {
                let (rect, _) = ui.allocate_exact_size(Vec2::splat(24.0), Sense::hover());
                ui.painter().circle_filled(rect.center(), 12.0, INDIGO);
                ui.painter().text(
                    rect.center(),
                    egui::Align2::CENTER_CENTER,
                    number.to_string(),
                    FontId::proportional(12.0),
                    Color32::WHITE,
                );
                ui.add_space(4.0);
                ui.label(RichText::new(title).size(16.0).color(HEADING));
            });
            ui.add_space(10.0);
            add(ui);
        });
    ui.add_space(14.0);
}

impl App for BetaApp {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        self.poll_fetch();
        if self.fetching {
            ctx.request_repaint();
        }

        egui::CentralPanel::default()
            .frame(Frame::NONE)
            .show(ctx, |ui| {
                paint_backdrop(ui);
                header_ui(ui);
                egui::ScrollArea::vertical()
                    .auto_shrink([false, false])
                    .show(ui, |ui| {
                        ui.add_space(16.0);
                        ui.horizontal(|ui| {
                            let side = 24.0_f32;
                            ui.add_space(side);
                            ui.vertical(|ui| {
                                ui.set_width((ui.available_width() - side).max(320.0));
                                self.steps(ui);
                            });
                        });
                        ui.add_space(24.0);
                    });
            });

        if self.confirm_teardown {
            egui::Window::new("Delete local credentials?")
                .collapsible(false)
                .resizable(false)
                .anchor(egui::Align2::CENTER_CENTER, [0.0, 0.0])
                .frame(
                    Frame::window(&ctx.style())
                        .fill(CARD)
                        .corner_radius(14.0)
                        .inner_margin(16.0),
                )
                .show(ctx, |ui| {
                    ui.set_min_width(420.0);
                    ui.label(
                        RichText::new(format!(
                            "This deletes the private key, certificate, and any .p7m files in {}.\nAlso delete the management service in Apple Business if you no longer need it.",
                            self.workdir.display()
                        ))
                        .size(13.0)
                        .color(TEXT),
                    );
                    ui.add_space(12.0);
                    ui.horizontal(|ui| {
                        if pill_primary(ui, "Delete", true).clicked() {
                            self.teardown();
                        }
                        if pill_secondary(ui, "Cancel").clicked() {
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
            ui.add_space(8.0);
            ui.horizontal_wrapped(|ui| {
                ui.spacing_mut().item_spacing.x = 8.0;
                ui.label(RichText::new("Service name:").size(12.0).color(MUTED));
                ui.label(
                    RichText::new(SERVICE_NAME)
                        .size(12.0)
                        .family(FontFamily::Monospace)
                        .color(HEADING),
                );
                if pill_secondary(ui, "Copy name").clicked() && copy_clipboard(SERVICE_NAME) {
                    self.set_note(
                        "Service name copied. Paste it into the Service Name field in Apple Business.",
                    );
                }
            });
            ui.add_space(4.0);
            ui.horizontal_wrapped(|ui| {
                ui.spacing_mut().item_spacing.x = 8.0;
                if self.has_keypair {
                    ui.label(RichText::new("✓  Certificate ready").size(13.0).color(OK));
                    if pill_secondary(ui, "Show in Finder").clicked() {
                        reveal_in_finder(&self.workdir.join(CERT_NAME));
                    }
                } else if pill_primary(ui, "Create certificate", true).clicked() {
                    self.create_cert();
                }
                if pill_secondary(ui, "Open Apple Business").clicked() {
                    let _ = copy_clipboard(SERVICE_NAME);
                    open_url(APPLE_ADD_URL);
                    self.set_note(
                        "Service name copied. Paste it into the Service Name field in Apple Business.",
                    );
                }
                if (self.has_keypair || self.p7m.is_some())
                    && pill_secondary(ui, "Delete local credentials…").clicked()
                {
                    self.confirm_teardown = true;
                }
            });
        });

        card(ui, 2, "Choose server token (.p7m)", |ui| {
            ui.horizontal(|ui| {
                if pill_secondary(ui, "Choose file…").clicked() {
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
                let label = if self.fetching {
                    "Fetching…"
                } else {
                    "Fetch beta tokens"
                };
                if pill_primary(ui, label, can).clicked() {
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
                    ui.label(RichText::new("OS").size(12.0).color(MUTED));
                    egui::ComboBox::from_id_salt("os_filter")
                        .selected_text(&self.os_filter)
                        .show_ui(ui, |ui| {
                            for o in &os_opts {
                                ui.selectable_value(&mut self.os_filter, o.clone(), o);
                            }
                        });
                    ui.label(RichText::new("Search").size(12.0).color(MUTED));
                    ui.add(
                        egui::TextEdit::singleline(&mut self.search)
                            .desired_width(220.0)
                            .hint_text("Search title"),
                    );
                });
                ui.add_space(6.0);

                let filtered: Vec<(usize, BetaToken)> = self
                    .filtered()
                    .into_iter()
                    .map(|(i, t)| (i, t.clone()))
                    .collect();

                Frame::NONE
                    .fill(Color32::from_rgba_unmultiplied(255, 255, 255, 160))
                    .corner_radius(8.0)
                    .stroke(Stroke::new(1.0_f32, RULE))
                    .inner_margin(8.0)
                    .show(ui, |ui| {
                        egui::ScrollArea::vertical()
                            .max_height(200.0)
                            .show(ui, |ui| {
                                for (idx, t) in &filtered {
                                    let selected = self.selected == Some(*idx);
                                    let label = format!("{}  —  {}", t.title, t.os_display());
                                    if ui
                                        .selectable_label(
                                            selected,
                                            RichText::new(label).size(13.0).color(TEXT),
                                        )
                                        .clicked()
                                    {
                                        self.selected = Some(*idx);
                                    }
                                }
                            });
                    });

                if let Some(idx) = self.selected {
                    if let Some(t) = self.tokens.get(idx).cloned() {
                        ui.add_space(10.0);
                        ui.separator();
                        ui.add_space(6.0);
                        ui.label(RichText::new(&t.title).size(15.0).color(HEADING));
                        let unsupported =
                            render::unsupported_uem_beta_oses(std::slice::from_ref(&t));
                        if !unsupported.is_empty() {
                            ui.label(
                                RichText::new(format!(
                                    "{} is not supported: the Beta setting cannot deliver this program via Software Update:Settings.",
                                    t.os_display()
                                ))
                                .size(12.0)
                                .color(MAGENTA),
                            );
                        }
                        ui.horizontal_wrapped(|ui| {
                            ui.spacing_mut().item_spacing.x = 8.0;
                            let shown = if self.reveal_token {
                                t.token.clone()
                            } else {
                                t.masked_token()
                            };
                            ui.label(
                                RichText::new(shown)
                                    .size(12.0)
                                    .family(FontFamily::Monospace)
                                    .color(HEADING),
                            );
                            ui.checkbox(&mut self.reveal_token, "Reveal");
                            if pill_primary(ui, "Copy token", true).clicked()
                                && copy_clipboard(&t.token)
                            {
                                self.set_note("Token copied to clipboard.");
                            }
                            if pill_secondary(ui, "Copy for UEM").clicked() {
                                let block = uem_paste_block(&t);
                                if copy_clipboard(&block) {
                                    self.set_note(
                                        "UEM paste block copied (title, token, and field checklist).",
                                    );
                                }
                            }
                        });
                        ui.add_space(4.0);
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
            ui.horizontal(|ui| {
                ui.label(RichText::new("⚠").color(MAGENTA));
                ui.label(RichText::new(e).size(13.0).color(MAGENTA));
            });
        } else if let Some(m) = &self.message {
            ui.horizontal(|ui| {
                ui.label(RichText::new("ℹ").color(MUTED));
                ui.label(RichText::new(m).size(13.0).color(MUTED));
            });
        }
    }
}

fn main() -> eframe::Result<()> {
    let options = eframe::NativeOptions {
        viewport: egui::ViewportBuilder::default()
            .with_inner_size([880.0, 760.0])
            .with_min_inner_size([700.0, 560.0])
            .with_title("Omnissa Beta Token Utility"),
        ..Default::default()
    };
    eframe::run_native(
        "Omnissa Beta Token Utility",
        options,
        Box::new(|cc| Ok(Box::new(BetaApp::new(cc)))),
    )
}
