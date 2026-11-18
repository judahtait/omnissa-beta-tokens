//! OAuth 1.0a (HMAC-SHA1) header builder for Apple's /session endpoint.

use base64::Engine;
use hmac::{Hmac, Mac};
use sha1::Sha1;

type HmacSha1 = Hmac<Sha1>;

pub const REALM: &str = "ADM";

/// RFC 3986 percent-encoding (unreserved: A-Z a-z 0-9 - . _ ~).
pub fn urlenc(value: &str) -> String {
    let mut out = String::with_capacity(value.len());
    for b in value.bytes() {
        match b {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'.' | b'_' | b'~' => {
                out.push(b as char);
            }
            _ => out.push_str(&format!("%{b:02X}")),
        }
    }
    out
}

#[allow(clippy::too_many_arguments)] // Matches Python/Swift signature for parity.
pub fn build_oauth_header(
    method: &str,
    url: &str,
    consumer_key: &str,
    consumer_secret: &str,
    access_token: &str,
    access_secret: &str,
    timestamp: Option<u64>,
    nonce: Option<&str>,
) -> String {
    let ts = timestamp.unwrap_or_else(|| {
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_secs())
            .unwrap_or(0)
    });
    let nonce = nonce
        .map(str::to_string)
        .unwrap_or_else(|| format!("{:x}", uuid::Uuid::new_v4().as_u128()));

    let mut params = vec![
        ("oauth_consumer_key", consumer_key.to_string()),
        ("oauth_nonce", nonce),
        ("oauth_signature_method", "HMAC-SHA1".to_string()),
        ("oauth_timestamp", ts.to_string()),
        ("oauth_token", access_token.to_string()),
        ("oauth_version", "1.0".to_string()),
    ];
    params.sort_by(|a, b| a.0.cmp(b.0));

    let param_string = params
        .iter()
        .map(|(k, v)| format!("{}={}", urlenc(k), urlenc(v)))
        .collect::<Vec<_>>()
        .join("&");
    let base_string = format!(
        "{}&{}&{}",
        urlenc(&method.to_uppercase()),
        urlenc(url),
        urlenc(&param_string)
    );
    let signing_key = format!("{}&{}", urlenc(consumer_secret), urlenc(access_secret));

    let mut mac = HmacSha1::new_from_slice(signing_key.as_bytes()).expect("HMAC key");
    mac.update(base_string.as_bytes());
    let sig = base64::engine::general_purpose::STANDARD.encode(mac.finalize().into_bytes());
    params.push(("oauth_signature", sig));

    let parts = params
        .iter()
        .map(|(k, v)| format!(r#"{k}="{}""#, urlenc(v)))
        .collect::<Vec<_>>()
        .join(",");
    format!(r#"OAuth realm="{REALM}",{parts}"#)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn urlenc_matches_python() {
        assert_eq!(urlenc("a b/c~"), "a%20b%2Fc~");
    }

    #[test]
    fn header_deterministic_and_matches_python() {
        let a = build_oauth_header(
            "GET",
            "https://x/y",
            "k",
            "cs",
            "t",
            "as",
            Some(1),
            Some("n"),
        );
        let b = build_oauth_header(
            "GET",
            "https://x/y",
            "k",
            "cs",
            "t",
            "as",
            Some(1),
            Some("n"),
        );
        assert_eq!(a, b);
        assert!(a.starts_with(r#"OAuth realm="ADM","#));
        assert!(a.contains("oauth_signature="));
        assert!(!a.replace("oauth_consumer_key", "").contains("cs"));
        assert_eq!(
            a,
            r#"OAuth realm="ADM",oauth_consumer_key="k",oauth_nonce="n",oauth_signature_method="HMAC-SHA1",oauth_timestamp="1",oauth_token="t",oauth_version="1.0",oauth_signature="n%2FjZpdcU9tlwgOufSN12WnS3e8A%3D""#
        );
    }
}
