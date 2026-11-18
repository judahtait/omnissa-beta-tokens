//! Build branded offline HTML from docs/guide.md.
//!
//! Callers: `tools/release.sh` Guide step via
//! `cargo run --release --bin build-guide`.
//! No other guide builder remains after deleting `tools/build_guide.py`.
//! Reads: docs/guide.md (+ relative images), assets/fonts/*.ttf.
//! Writes: dist/omnissa-beta-guide.html (or argv paths).
//! User instruction: "dot eh leftover." / "do the leftover."

use std::fs;
use std::path::{Path, PathBuf};

use base64::Engine;
use pulldown_cmark::{html, Options, Parser};

const CSS: &str = r#"
:root{--navy:#1C1C20;--indigo:#4A12F0;--text:#1D1D1F;--slate:#6E6E73;--tint:#D1D1D6;--bg:#F5F5F7;--page:#FFFFFF;--thbg:#001E60;--magenta:#D600FF}
@media(prefers-color-scheme:dark){:root{--navy:#F2F2F7;--indigo:#7050FF;--text:#E5E5E7;--slate:#A1A1A6;--tint:#3A3A3C;--bg:#1E1E21;--page:#141416;--thbg:#1B2A66}}
*{box-sizing:border-box}
body{margin:0;background:var(--page);color:var(--text);font-family:'Outfit','Outfit Light',system-ui,-apple-system,Segoe UI,sans-serif;font-weight:300;font-size:16px;line-height:1.6}
header{background:linear-gradient(100deg,#001E60,#4A12F0,#D600FF);color:#fff;padding:48px 16px 40px}
.wrap{max-width:900px;margin:0 auto;padding:0 16px}
header .wrap{padding:0}
.eyebrow{font-weight:500;letter-spacing:.12em;text-transform:uppercase;font-size:13px;opacity:.9}
h1{font-weight:500;font-size:34px;line-height:1.2;margin:10px 0 16px;color:#fff}
.meta{font-size:14px;opacity:.95}.meta span{margin-right:20px;display:inline-block}
.draft{background:var(--bg);border-left:4px solid var(--indigo);padding:12px 16px;margin:28px 0 8px;font-size:14px}
.claim{background:var(--bg);padding:14px 16px;border-radius:6px;font-size:15px;margin:8px 0}
h2{font-weight:500;color:var(--navy);font-size:24px;margin:40px 0 8px;padding-bottom:6px;border-bottom:2px solid var(--tint)}
h3{font-weight:500;color:var(--indigo);font-size:18px;margin:26px 0 4px}
strong{font-weight:500;color:var(--navy)}a{color:var(--indigo)}
code{font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;font-size:.88em;background:var(--bg);color:var(--navy);padding:1px 5px;border-radius:4px;word-break:break-word}
table{border-collapse:collapse;width:100%;margin:14px 0;font-size:15px;display:block;overflow-x:auto}
th{background:var(--thbg);color:#fff;font-weight:500;text-align:left;padding:8px 12px}
td{padding:8px 12px;border-bottom:1px solid var(--tint);vertical-align:top}
tr:nth-child(even) td{background:var(--bg)}li{margin:4px 0}
footer{border-top:2px solid var(--tint);margin-top:48px;padding:20px 0 40px;font-size:13px;color:var(--slate)}
img{max-width:100%;height:auto;border:1px solid var(--tint);border-radius:8px;margin:10px 0 2px;display:block}
.btn{display:inline-block;background:var(--indigo);color:#fff!important;font-weight:500;text-decoration:none;padding:10px 18px;border-radius:999px;border:0;cursor:pointer;font-family:inherit;font-size:15px}
.download{background:var(--bg);border-left:4px solid var(--indigo);padding:16px;margin:16px 0;border-radius:6px}
details summary{cursor:pointer;color:var(--indigo);font-weight:500;margin-top:8px}
pre{background:var(--page);border:1px solid var(--tint);border-radius:6px;padding:12px;overflow:auto;max-height:480px;font-size:12.5px;line-height:1.45}
pre code{background:none;padding:0}
@media print{header,th,tr:nth-child(even) td{-webkit-print-color-adjust:exact;print-color-adjust:exact}h2{break-after:avoid}table,li{break-inside:avoid}}
"#;

fn repo_root() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .map(Path::to_path_buf)
        .unwrap_or_else(|| PathBuf::from("."))
}

fn utility_block() -> &'static str {
    r#"<div class="download">
<p><strong>Download (Rust)</strong></p>
<ul>
<li><code>omnissa-beta-tokens-&lt;ver&gt;-macos-arm64</code> — CLI</li>
<li><code>Omnissa-Beta-Token-Utility-&lt;ver&gt;-macos.zip</code> — macOS app (same Rust core)</li>
</ul>
<p>From a release: verify with <code>SHA256SUMS</code>, then:</p>
<pre><code>chmod +x omnissa-beta-tokens-*-macos-arm64
./omnissa-beta-tokens-*-macos-arm64 init
./omnissa-beta-tokens-*-macos-arm64 fetch --watch</code></pre>
<p>Or build from source:</p>
<pre><code>cd rust &amp;&amp; cargo build --release
./target/release/omnissa-beta-tokens --help
./target/release/omnissa-beta-tokens-app</code></pre>
</div>"#
}

fn font_css(root: &Path) -> String {
    let mut out = String::new();
    for (weight, name) in [(300, "Outfit-Light"), (500, "Outfit-Medium")] {
        let f = root.join("assets/fonts").join(format!("{name}.ttf"));
        if let Ok(bytes) = fs::read(&f) {
            let b64 = base64::engine::general_purpose::STANDARD.encode(bytes);
            out.push_str(&format!(
                "@font-face{{font-family:'Outfit';font-weight:{weight};src:url(data:font/ttf;base64,{b64}) format('truetype')}}\n"
            ));
        }
    }
    out
}

fn field(meta: &str, name: &str) -> String {
    let needle = format!("**{name}:** ");
    for line in meta.lines() {
        if let Some(rest) = line.strip_prefix(&needle) {
            return rest.to_string();
        }
    }
    String::new()
}

fn esc_inline(t: &str) -> String {
    let re_code = regex::Regex::new(r"`([^`]+)`").unwrap();
    let s = re_code
        .replace_all(t, |caps: &regex::Captures| {
            let inner = caps[1]
                .replace('&', "&amp;")
                .replace('<', "&lt;")
                .replace('>', "&gt;");
            format!("<code>{inner}</code>")
        })
        .into_owned();
    let re_strong = regex::Regex::new(r"\*\*([^*]+)\*\*").unwrap();
    re_strong
        .replace_all(&s, "<strong>$1</strong>")
        .into_owned()
}

fn md_to_html(md: &str) -> String {
    let mut opts = Options::empty();
    opts.insert(Options::ENABLE_TABLES);
    opts.insert(Options::ENABLE_STRIKETHROUGH);
    let parser = Parser::new_ext(md, opts);
    let mut html_out = String::new();
    html::push_html(&mut html_out, parser);
    html_out
}

fn inline_images(body: &str, img_root: &Path) -> Result<String, String> {
    // Avoid look-ahead (not supported by the default regex crate).
    let re = regex::Regex::new(r#"(<img[^>]*\ssrc=")([^"]+)(")"#).unwrap();
    let mut err: Option<String> = None;
    let out = re.replace_all(body, |caps: &regex::Captures| {
        if err.is_some() {
            return caps[0].to_string();
        }
        let rel = &caps[2];
        if rel.starts_with("data:") || rel.starts_with("http://") || rel.starts_with("https://") {
            return caps[0].to_string();
        }
        let f = img_root.join(rel);
        match fs::read(&f) {
            Ok(bytes) => {
                let mime = if f
                    .extension()
                    .and_then(|e| e.to_str())
                    .map(|e| e.eq_ignore_ascii_case("png"))
                    .unwrap_or(false)
                {
                    "image/png"
                } else {
                    "image/jpeg"
                };
                let b64 = base64::engine::general_purpose::STANDARD.encode(bytes);
                format!("{}data:{mime};base64,{}{}", &caps[1], b64, &caps[3])
            }
            Err(_) => {
                err = Some(format!("ERROR: image not found: {}", f.display()));
                caps[0].to_string()
            }
        }
    });
    if let Some(e) = err {
        return Err(e);
    }
    Ok(out.into_owned())
}

fn main() {
    let root = repo_root();
    let args: Vec<String> = std::env::args().skip(1).collect();
    let src = args
        .first()
        .map(PathBuf::from)
        .unwrap_or_else(|| root.join("docs/guide.md"));
    let out = args
        .get(1)
        .map(PathBuf::from)
        .unwrap_or_else(|| root.join("dist/omnissa-beta-guide.html"));

    let s = fs::read_to_string(&src).unwrap_or_else(|e| {
        eprintln!("ERROR: read {}: {e}", src.display());
        std::process::exit(1);
    });
    let Some((meta, body_md)) = s.split_once("\n---\n") else {
        eprintln!("ERROR: expected meta then \\n---\\n then body");
        std::process::exit(1);
    };
    let title = meta
        .lines()
        .find_map(|l| l.strip_prefix("# "))
        .unwrap_or("Guide")
        .to_string();
    let mut body = md_to_html(body_md);
    body = body.replace("<!-- UTILITY_DOWNLOAD -->", utility_block());
    let img_root = src.parent().unwrap_or(Path::new("."));
    body = match inline_images(&body, img_root) {
        Ok(b) => b,
        Err(e) => {
            eprintln!("{e}");
            std::process::exit(1);
        }
    };

    let status = field(meta, "Status");
    let date = field(meta, "Date");
    let author = field(meta, "Author");
    let claim = field(meta, "Ticket claim");

    let draft_html = if status.starts_with("Draft only") {
        let rest = status.strip_prefix("Draft only. ").unwrap_or(&status);
        format!(r#"<div class="draft"><strong>Draft only.</strong> {rest}</div>"#)
    } else {
        String::new()
    };
    let claim_html = if claim.is_empty() {
        String::new()
    } else {
        format!(
            r#"<div class="claim"><strong>Ticket claim:</strong> {}</div>"#,
            esc_inline(&claim)
        )
    };

    let html = format!(
        r#"<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{title}</title>
<style>{fonts}{CSS}</style></head><body>
<header><div class="wrap"><div class="eyebrow">Omnissa &middot; Workspace ONE UEM &middot; Guide</div>
<h1>{title}</h1>
<div class="meta"><span>{date}</span><span>{author}</span></div></div></header>
<main class="wrap">
{draft_html}
{claim_html}
{body}
<footer>Omnissa &middot; Draft for review. Do not share tokens, server tokens (.p7m) or private keys. Outfit font: SIL Open Font License 1.1.</footer>
</main></body></html>"#,
        fonts = font_css(&root),
    );

    if let Some(parent) = out.parent() {
        let _ = fs::create_dir_all(parent);
    }
    fs::write(&out, html).unwrap_or_else(|e| {
        eprintln!("ERROR: write {}: {e}", out.display());
        std::process::exit(1);
    });
    println!("wrote {}", out.display());
}
