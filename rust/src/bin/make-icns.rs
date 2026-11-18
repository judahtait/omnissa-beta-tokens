//! Pack an .iconset folder into an .icns file (PNG chunks).
//!
//! Callers: branding workflow / docs (manual):
//! `cargo run --release --bin make-icns -- assets/AppIcon.iconset assets/AppIcon.icns`
//! Replaces deleted `tools/make_icns.py`. No other ICNS packer remains.
//! Reads icon_*.png under the iconset dir; writes ICNS binary.
//! User instruction: "dot eh leftover." (= do the leftover).

use std::fs;
use std::path::PathBuf;
use std::process::ExitCode;

const CHUNKS: &[(&str, &[u8; 4])] = &[
    ("icon_16x16.png", b"icp4"),
    ("icon_16x16@2x.png", b"ic11"),
    ("icon_32x32.png", b"icp5"),
    ("icon_32x32@2x.png", b"ic12"),
    ("icon_128x128.png", b"ic07"),
    ("icon_128x128@2x.png", b"ic13"),
    ("icon_256x256.png", b"ic08"),
    ("icon_256x256@2x.png", b"ic14"),
    ("icon_512x512.png", b"ic09"),
    ("icon_512x512@2x.png", b"ic10"),
];
const PNG_MAGIC: &[u8] = b"\x89PNG\r\n\x1a\n";

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    if args.len() != 2 {
        eprintln!("Usage: make-icns <iconset-dir> <out.icns>");
        return ExitCode::from(2);
    }
    let src = PathBuf::from(&args[0]);
    let out = PathBuf::from(&args[1]);
    let mut body = Vec::new();
    for (name, kind) in CHUNKS {
        let f = src.join(name);
        let data = match fs::read(&f) {
            Ok(d) => d,
            Err(_) => {
                eprintln!("[ERROR] missing {}", f.display());
                return ExitCode::FAILURE;
            }
        };
        if !data.starts_with(PNG_MAGIC) {
            eprintln!("[ERROR] {} is not a PNG", f.display());
            return ExitCode::FAILURE;
        }
        body.extend_from_slice(*kind);
        let len = (data.len() + 8) as u32;
        body.extend_from_slice(&len.to_be_bytes());
        body.extend_from_slice(&data);
    }
    let mut file = Vec::new();
    file.extend_from_slice(b"icns");
    let total = (body.len() + 8) as u32;
    file.extend_from_slice(&total.to_be_bytes());
    file.extend_from_slice(&body);
    if let Err(e) = fs::write(&out, &file) {
        eprintln!("[ERROR] write {}: {e}", out.display());
        return ExitCode::FAILURE;
    }
    println!(
        "wrote {} ({} bytes, {} sizes)",
        out.display(),
        file.len(),
        CHUNKS.len()
    );
    ExitCode::SUCCESS
}
