//! Key/cert generation and decryption of the Apple Business server token (.p7m).
//! Uses the system `openssl` binary; decrypted content stays in memory only.

use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

use base64::Engine;
use serde_json::Value;

use crate::credentials::{Credentials, ToolError};

pub const KEY_NAME: &str = "mdm_private.key";
pub const CERT_NAME: &str = "mdm_public_cert.pem";
pub const CERT_CN: &str = "Omnissa Beta Token Utility";

fn openssl_bin() -> &'static str {
    for path in ["/usr/bin/openssl", "/opt/homebrew/bin/openssl"] {
        let p = Path::new(path);
        if p.is_file() {
            use std::os::unix::fs::PermissionsExt;
            if let Ok(meta) = fs::metadata(p) {
                if meta.permissions().mode() & 0o111 != 0 {
                    return path;
                }
            }
        }
    }
    "openssl"
}

fn run_openssl(args: &[&str], input: Option<&[u8]>) -> Result<(i32, Vec<u8>, Vec<u8>), ToolError> {
    let mut cmd = Command::new(openssl_bin());
    cmd.args(args)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped());
    let mut child = cmd
        .spawn()
        .map_err(|e| ToolError::msg(format!("'{}' not found: {e}", openssl_bin())))?;
    if let Some(data) = input {
        use std::io::Write;
        if let Some(mut stdin) = child.stdin.take() {
            stdin
                .write_all(data)
                .map_err(|e| ToolError::msg(format!("openssl stdin: {e}")))?;
        }
    }
    let out = child
        .wait_with_output()
        .map_err(|e| ToolError::msg(format!("openssl failed to run: {e}")))?;
    Ok((out.status.code().unwrap_or(1), out.stdout, out.stderr))
}

pub fn ensure_workdir(workdir: &Path) -> Result<(), ToolError> {
    fs::create_dir_all(workdir).map_err(|e| ToolError::msg(format!("mkdir: {e}")))?;
    let mut perms = fs::metadata(workdir)
        .map_err(|e| ToolError::msg(e.to_string()))?
        .permissions();
    perms.set_mode(0o700);
    fs::set_permissions(workdir, perms).map_err(|e| ToolError::msg(e.to_string()))?;
    exclude_from_time_machine(workdir);
    Ok(())
}

/// Best-effort Time Machine exclusion (macOS). No-op if `tmutil` is unavailable.
fn exclude_from_time_machine(path: &Path) {
    let _ = std::process::Command::new("tmutil")
        .args(["addexclusion", &path.to_string_lossy()])
        .status();
}

fn libc_umask(mask: u32) -> u32 {
    extern "C" {
        fn umask(mask: u32) -> u32;
    }
    unsafe { umask(mask) }
}

pub fn generate_keypair(workdir: &Path, days: u32) -> Result<(PathBuf, PathBuf), ToolError> {
    ensure_workdir(workdir)?;
    let key = workdir.join(KEY_NAME);
    let cert = workdir.join(CERT_NAME);
    if key.exists() || cert.exists() {
        return Err(ToolError::msg(format!(
            "{KEY_NAME}/{CERT_NAME} already exist in {}; refusing to overwrite. Remove them to start over.",
            workdir.display()
        )));
    }

    let old = libc_umask(0o177);
    let subj = format!("/CN={CERT_CN}");
    let key_s = key.to_string_lossy().into_owned();
    let cert_s = cert.to_string_lossy().into_owned();
    let days_s = days.to_string();
    let result = run_openssl(
        &[
            "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-sha256", "-keyout", &key_s, "-out",
            &cert_s, "-days", &days_s, "-subj", &subj,
        ],
        None,
    );
    libc_umask(old);
    let (code, _, err) = result?;
    if code != 0 {
        return Err(ToolError::msg(format!(
            "openssl failed: {}",
            String::from_utf8_lossy(&err)
        )));
    }
    let mut perms = fs::metadata(&key)
        .map_err(|e| ToolError::msg(e.to_string()))?
        .permissions();
    perms.set_mode(0o600);
    fs::set_permissions(&key, perms).map_err(|e| ToolError::msg(e.to_string()))?;
    // Hide from Finder so "open workdir" does not advertise the private key next to the .pem.
    hide_from_finder(&key);
    Ok((key, cert))
}

/// Best-effort Finder hidden flag (macOS `chflags hidden`). No-op if unavailable.
fn hide_from_finder(path: &Path) {
    let _ = std::process::Command::new("chflags")
        .args(["hidden", &path.to_string_lossy()])
        .status();
}

pub fn find_p7m(workdir: &Path) -> Option<PathBuf> {
    let mut files: Vec<_> = fs::read_dir(workdir)
        .ok()?
        .filter_map(|e| e.ok())
        .map(|e| e.path())
        .filter(|p| p.extension().and_then(|s| s.to_str()) == Some("p7m"))
        .collect();
    files.sort_by_key(|p| fs::metadata(p).and_then(|m| m.modified()).ok());
    files.pop()
}

/// Delete key, certificate, and any `*.p7m` files under `workdir`.
/// Errors if the directory is missing or nothing matching was found.
pub fn cleanup_workdir(workdir: &Path) -> Result<Vec<PathBuf>, ToolError> {
    if !workdir.is_dir() {
        return Err(ToolError::msg(format!(
            "Workdir does not exist: {}",
            workdir.display()
        )));
    }
    let mut targets = vec![workdir.join(KEY_NAME), workdir.join(CERT_NAME)];
    if let Ok(rd) = fs::read_dir(workdir) {
        for e in rd.flatten() {
            let p = e.path();
            if p.extension().and_then(|s| s.to_str()) == Some("p7m") {
                targets.push(p);
            }
        }
    }
    let mut removed = Vec::new();
    for p in targets {
        if p.is_file() {
            fs::remove_file(&p)
                .map_err(|e| ToolError::msg(format!("Failed to delete {}: {e}", p.display())))?;
            removed.push(p);
        }
    }
    if removed.is_empty() {
        return Err(ToolError::msg(format!(
            "No key, certificate, or .p7m files found in {}",
            workdir.display()
        )));
    }
    Ok(removed)
}

pub fn decrypt_server_token(p7m: &Path, workdir: &Path) -> Result<Credentials, ToolError> {
    let key = workdir.join(KEY_NAME);
    let cert = workdir.join(CERT_NAME);
    for f in [p7m, key.as_path(), cert.as_path()] {
        if !f.is_file() {
            return Err(ToolError::msg(format!("Missing file: {}", f.display())));
        }
    }
    let cert_s = cert.to_string_lossy().into_owned();
    let key_s = key.to_string_lossy().into_owned();
    let p7m_s = p7m.to_string_lossy().into_owned();
    let (code, stdout, _) = run_openssl(
        &[
            "smime", "-decrypt", "-recip", &cert_s, "-inkey", &key_s, "-inform", "SMIME", "-in",
            &p7m_s,
        ],
        None,
    )?;
    let stdout = if code != 0 {
        let text = fs::read_to_string(p7m).unwrap_or_default();
        let lines: Vec<&str> = text.lines().collect();
        let b64 = if lines.len() > 5 {
            lines[5..].join("")
        } else {
            String::new()
        };
        let der = base64::engine::general_purpose::STANDARD
            .decode(b64.replace('\n', ""))
            .unwrap_or_default();
        if der.is_empty() {
            return Err(ToolError::msg(
                "Failed to decrypt the .p7m. Does it match the PEM that was uploaded to Apple Business?",
            ));
        }
        let (code2, out2, _) = run_openssl(
            &[
                "smime", "-decrypt", "-recip", &cert_s, "-inkey", &key_s, "-inform", "DER",
            ],
            Some(&der),
        )?;
        if code2 != 0 {
            return Err(ToolError::msg(
                "Failed to decrypt the .p7m. Does it match the PEM that was uploaded to Apple Business?",
            ));
        }
        out2
    } else {
        stdout
    };

    let s = String::from_utf8_lossy(&stdout);
    let start = s
        .find('{')
        .ok_or_else(|| ToolError::msg("No JSON payload found in decrypted server token."))?;
    let end = s
        .rfind('}')
        .ok_or_else(|| ToolError::msg("No JSON payload found in decrypted server token."))?;
    let data: Value = serde_json::from_str(&s[start..=end])
        .map_err(|e| ToolError::msg(format!("Server token payload is malformed: {e}")))?;
    let field = |k: &str| -> Result<String, ToolError> {
        data.get(k)
            .and_then(|v| v.as_str())
            .map(str::to_string)
            .ok_or_else(|| ToolError::msg(format!("Server token payload is missing {k}.")))
    };
    Ok(Credentials {
        consumer_key: field("consumer_key")?,
        consumer_secret: field("consumer_secret")?,
        access_token: field("access_token")?,
        access_secret: field("access_secret")?,
        access_token_expiry: data
            .get("access_token_expiry")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string(),
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;
    use std::process::Command;

    #[test]
    fn keygen_perms_and_no_overwrite() {
        let dir = tempfile::tempdir().unwrap();
        let wd = dir.path().join("wd");
        let (key, _) = generate_keypair(&wd, 1).unwrap();
        let mode = fs::metadata(&key).unwrap().permissions().mode() & 0o777;
        assert_eq!(mode, 0o600);
        assert!(generate_keypair(&wd, 1).is_err());
    }

    #[test]
    fn decrypt_roundtrip() {
        let dir = tempfile::tempdir().unwrap();
        let wd = dir.path().join("wd");
        generate_keypair(&wd, 1).unwrap();
        let payload = br#"{"consumer_key":"CK_FAKE","consumer_secret":"CS_FAKE","access_token":"AT_FAKE","access_secret":"AS_FAKE","access_token_expiry":"2099-01-01T00:00:00Z"}"#;
        let p7m = wd.join("fake.p7m");
        let cert = wd.join(CERT_NAME);
        let mut child = Command::new(openssl_bin())
            .args([
                "smime",
                "-encrypt",
                "-aes256",
                "-out",
                p7m.to_str().unwrap(),
                cert.to_str().unwrap(),
            ])
            .stdin(Stdio::piped())
            .stdout(Stdio::null())
            .stderr(Stdio::piped())
            .spawn()
            .unwrap();
        child.stdin.as_mut().unwrap().write_all(payload).unwrap();
        assert!(child.wait().unwrap().success());
        let creds = decrypt_server_token(&p7m, &wd).unwrap();
        assert_eq!(creds.consumer_key, "CK_FAKE");
        assert_eq!(creds.access_secret, "AS_FAKE");
    }

    #[test]
    fn cleanup_removes_key_cert_p7m() {
        let dir = tempfile::tempdir().unwrap();
        let wd = dir.path().join("wd");
        generate_keypair(&wd, 1).unwrap();
        let p7m = wd.join("token.p7m");
        fs::write(&p7m, b"fake").unwrap();
        let removed = cleanup_workdir(&wd).unwrap();
        assert!(removed.len() >= 3);
        assert!(!wd.join(KEY_NAME).exists());
        assert!(!wd.join(CERT_NAME).exists());
        assert!(!p7m.exists());
        assert!(cleanup_workdir(&wd).is_err());
    }
}
