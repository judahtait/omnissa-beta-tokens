//! Command line interface: omnissa-beta-tokens {init,fetch,cleanup}.

use std::fs;
use std::io::{self, Write};
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::thread;
use std::time::Duration;

use clap::{Parser, Subcommand, ValueEnum};

use crate::abm::{self, default_transport};
use crate::credentials::access_token_expired;
use crate::render;
use crate::servertoken::{self, CERT_NAME};

pub const VERSION: &str = env!("CARGO_PKG_VERSION");
pub const SERVICE_NAME: &str = "Workspace One AppleSeed Beta Token Service";
pub const APPLE_ADD_SERVICE_URL: &str =
    "https://business.apple.com/main/devices/managementservices/mdmservers/add";

fn dirs_home() -> Option<PathBuf> {
    std::env::var_os("HOME").map(PathBuf::from)
}

fn default_workdir() -> PathBuf {
    dirs_home()
        .unwrap_or_else(|| PathBuf::from("."))
        .join(".omnissa-beta-tokens")
}

fn expand_path(p: PathBuf) -> PathBuf {
    let s = p.to_string_lossy();
    if s == "~" {
        return dirs_home().unwrap_or(p);
    }
    if let Some(rest) = s.strip_prefix("~/") {
        return dirs_home().map(|h| h.join(rest)).unwrap_or(p);
    }
    p
}

#[derive(Parser, Debug)]
#[command(
    name = "omnissa-beta-tokens",
    version = VERSION,
    about = "Primary CLI: get Apple beta enrollment tokens for Workspace ONE UEM."
)]
pub struct Args {
    #[arg(long, global = true)]
    pub no_banner: bool,

    #[arg(long, global = true, default_value_os_t = default_workdir(), value_parser = parse_path)]
    pub workdir: PathBuf,

    #[command(subcommand)]
    pub command: Commands,
}

fn parse_path(s: &str) -> Result<PathBuf, String> {
    Ok(expand_path(PathBuf::from(s)))
}

#[derive(Subcommand, Debug)]
pub enum Commands {
    /// Generate key + certificate to upload to Apple Business
    Init,
    /// Decrypt the .p7m and list beta tokens
    Fetch {
        #[arg(long, value_parser = parse_path)]
        p7m: Option<PathBuf>,
        #[arg(long)]
        watch: bool,
        #[arg(long, default_value_t = 5)]
        interval: u64,
        #[arg(long = "os")]
        os_filter: Option<String>,
        #[arg(long = "match")]
        match_text: Option<String>,
        #[arg(long, value_enum, default_value_t = OutputFormat::Table)]
        format: OutputFormat,
        #[arg(long)]
        reveal: bool,
        /// Print UEM paste block for exactly one filtered program (not declaration JSON)
        #[arg(long = "uem-block")]
        uem_block: bool,
    },
    /// Delete key, certificate, and .p7m files in --workdir
    Cleanup {
        /// Required confirmation (non-interactive safety)
        #[arg(long)]
        yes: bool,
    },
}

#[derive(Clone, Debug, ValueEnum)]
pub enum OutputFormat {
    Table,
    Json,
    Csv,
}

fn banner(enabled: bool) {
    if !enabled {
        return;
    }
    let _ = writeln!(
        io::stderr(),
        "OMNISSA  Beta Token Utility v{VERSION}\nWorkspace ONE UEM - Apple beta enrollment tokens\n"
    );
}

fn err(msg: impl AsRef<str>) -> i32 {
    let _ = writeln!(io::stderr(), "[ERROR] {}", msg.as_ref());
    1
}

fn info(msg: impl AsRef<str>) {
    let _ = writeln!(io::stderr(), "[INFO] {}", msg.as_ref());
}

fn warn(msg: impl AsRef<str>) {
    let _ = writeln!(io::stderr(), "[WARNING] {}", msg.as_ref());
}

fn copy_clipboard(text: &str) -> bool {
    Command::new("pbcopy")
        .stdin(std::process::Stdio::piped())
        .spawn()
        .and_then(|mut c| {
            if let Some(mut stdin) = c.stdin.take() {
                use std::io::Write as _;
                stdin.write_all(text.as_bytes())?;
            }
            c.wait().map(|s| s.success())
        })
        .unwrap_or(false)
}

fn watch_downloads(workdir: &Path, interval: u64) -> Result<PathBuf, i32> {
    let downloads = dirs_home()
        .unwrap_or_else(|| PathBuf::from("."))
        .join("Downloads");
    let seen: std::collections::HashSet<PathBuf> = fs::read_dir(&downloads)
        .into_iter()
        .flatten()
        .flatten()
        .map(|e| e.path())
        .filter(|p| p.extension().and_then(|s| s.to_str()) == Some("p7m"))
        .collect();
    info(format!(
        "Watching {} for a new .p7m (Ctrl+C to stop)...",
        downloads.display()
    ));
    loop {
        if let Ok(rd) = fs::read_dir(&downloads) {
            for e in rd.flatten() {
                let p = e.path();
                if p.extension().and_then(|s| s.to_str()) == Some("p7m") && !seen.contains(&p) {
                    let dest = workdir.join(p.file_name().unwrap());
                    if fs::copy(&p, &dest).is_ok() {
                        let _ = fs::set_permissions(&dest, fs::Permissions::from_mode(0o600));
                        info(format!(
                            "Found {}",
                            p.file_name().unwrap().to_string_lossy()
                        ));
                        return Ok(dest);
                    }
                }
            }
        }
        thread::sleep(Duration::from_secs(interval));
    }
}

pub fn run(args: Args) -> i32 {
    banner(!args.no_banner);
    match args.command {
        Commands::Init => cmd_init(&args.workdir),
        Commands::Fetch {
            p7m,
            watch,
            interval,
            os_filter,
            match_text,
            format,
            reveal,
            uem_block,
        } => cmd_fetch(
            &args.workdir,
            p7m,
            watch,
            interval,
            os_filter.as_deref(),
            match_text.as_deref(),
            format,
            reveal,
            uem_block,
        ),
        Commands::Cleanup { yes } => cmd_cleanup(&args.workdir, yes),
    }
}

fn cmd_init(workdir: &Path) -> i32 {
    match servertoken::generate_keypair(workdir, 365) {
        Ok((_, cert)) => {
            info(format!(
                "Created key and certificate in {} (private key mode 600).",
                workdir.display()
            ));
            let copied = if copy_clipboard(SERVICE_NAME) {
                " (copied to clipboard - paste it into the form)"
            } else {
                ""
            };
            let workdir_opt = {
                let def = default_workdir();
                if workdir == def {
                    String::new()
                } else {
                    format!("--workdir {} ", workdir.display())
                }
            };
            let _ = writeln!(
                io::stderr(),
                "\nNext steps in Apple Business:\n\
                 1. Devices > Management Services > Add\n   {APPLE_ADD_SERVICE_URL}\n\
                 2. Service Name: {SERVICE_NAME}{copied}\n\
                 3. Upload this file: {}\n\
                 4. Download the .p7m server token\n\
                 5. Run: omnissa-beta-tokens {workdir_opt}fetch --watch\n",
                cert.display()
            );
            0
        }
        Err(e) => err(e.to_string()),
    }
}

fn cmd_cleanup(workdir: &Path, yes: bool) -> i32 {
    if !yes {
        return err(
            "cleanup requires --yes to delete key, certificate, and .p7m files in --workdir.",
        );
    }
    match servertoken::cleanup_workdir(workdir) {
        Ok(removed) => {
            for p in &removed {
                info(format!("Deleted {}", p.display()));
            }
            let _ = writeln!(
                io::stderr(),
                "\nReminder: also delete the management service in Apple Business\n\
                 (Devices > Management Services — typically '{SERVICE_NAME}').\n\
                 Local key/cert/*.p7m are gone; the ABM service is not removed by this tool.\n"
            );
            0
        }
        Err(e) => err(e.to_string()),
    }
}

#[allow(clippy::too_many_arguments)]
fn cmd_fetch(
    workdir: &Path,
    p7m: Option<PathBuf>,
    watch: bool,
    interval: u64,
    os_filter: Option<&str>,
    match_text: Option<&str>,
    format: OutputFormat,
    reveal: bool,
    uem_block: bool,
) -> i32 {
    if let Err(e) = servertoken::ensure_workdir(workdir) {
        return err(e.to_string());
    }
    if !workdir.join(CERT_NAME).exists() {
        return err(format!(
            "No key/cert in {}. Run 'omnissa-beta-tokens init' first.",
            workdir.display()
        ));
    }

    let p7m_path = if let Some(p) = p7m {
        p
    } else if let Some(p) = servertoken::find_p7m(workdir) {
        p
    } else if watch {
        match watch_downloads(workdir, interval) {
            Ok(p) => p,
            Err(c) => return c,
        }
    } else {
        return err(format!(
            "No .p7m found. Pass --p7m PATH, use --watch, or copy it into {}",
            workdir.display()
        ));
    };

    let creds = match servertoken::decrypt_server_token(&p7m_path, workdir) {
        Ok(c) => c,
        Err(e) => return err(e.to_string()),
    };
    info(format!("Server token read: {creds:?}"));
    if access_token_expired(&creds, None) {
        warn(
            "Server token access_token_expiry is in the past. \
             Regenerate the server token in Apple Business and retry.",
        );
    }

    let transport = default_transport();
    let tokens = match abm::fetch_beta_tokens(&creds, &transport) {
        Ok(t) => render::filter_tokens(&t, os_filter, match_text),
        Err(e) => return err(e.to_string()),
    };
    if tokens.is_empty() {
        return err("No beta programs matched.");
    }

    let unsupported = render::unsupported_uem_beta_oses(&tokens);
    if !unsupported.is_empty() {
        warn(format!(
            "UEM Software Update:Settings > Beta cannot deliver {}. \
             Those platforms are not applicable for this setting.",
            unsupported.join(", ")
        ));
    }

    let out = match format {
        OutputFormat::Json => render::to_json(&tokens),
        OutputFormat::Csv => render::to_csv(&tokens),
        OutputFormat::Table => render::to_table(&tokens, reveal),
    };
    println!("{out}");

    if uem_block {
        if tokens.len() != 1 {
            return err(format!(
                "--uem-block needs exactly one program; got {}. \
                 Narrow with --os and/or --match.",
                tokens.len()
            ));
        }
        let block = render::uem_paste_block(&tokens[0]);
        println!("\n{block}");
        if copy_clipboard(&block) {
            info("UEM paste block copied to clipboard.");
        }
    }
    0
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn expand_tilde_home() {
        let home = dirs_home().expect("HOME");
        assert_eq!(expand_path(PathBuf::from("~")), home);
        assert_eq!(
            expand_path(PathBuf::from("~/foo/bar")),
            home.join("foo/bar")
        );
    }
}
