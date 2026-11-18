use std::fmt;
use std::time::{SystemTime, UNIX_EPOCH};

use thiserror::Error;

#[derive(Debug, Error)]
pub enum ToolError {
    #[error("{0}")]
    Message(String),
}

impl ToolError {
    pub fn msg(s: impl Into<String>) -> Self {
        Self::Message(s.into())
    }
}

pub fn mask_secret(value: &str, keep: usize) -> String {
    if value.len() <= keep {
        return "[REDACTED]".to_string();
    }
    format!("[REDACTED]...{}", &value[value.len() - keep..])
}

#[derive(Clone)]
pub struct Credentials {
    pub consumer_key: String,
    pub consumer_secret: String,
    pub access_token: String,
    pub access_secret: String,
    pub access_token_expiry: String,
}

impl fmt::Debug for Credentials {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "Credentials(consumer_key={}, access_token={}, expiry={:?}, secrets=[REDACTED])",
            mask_secret(&self.consumer_key, 4),
            mask_secret(&self.access_token, 4),
            self.access_token_expiry
        )
    }
}

/// Parse Apple's `access_token_expiry` (ISO-8601, often with trailing `Z`).
/// Returns Unix seconds UTC, or `None` if missing/unparseable.
pub fn parse_access_token_expiry(value: &str) -> Option<i64> {
    let text = value.trim();
    if text.is_empty() {
        return None;
    }
    let normalized = if let Some(rest) = text.strip_suffix('Z') {
        format!("{rest}+00:00")
    } else if text.contains('+') || text.rfind('-').map(|i| i > 10).unwrap_or(false) {
        text.to_string()
    } else {
        format!("{text}+00:00")
    };

    let (datetime, offset) = split_offset(&normalized)?;
    let (date, time) = datetime
        .split_once('T')
        .or_else(|| datetime.split_once(' '))?;
    let mut date_parts = date.split('-');
    let year: i64 = date_parts.next()?.parse().ok()?;
    let month: i64 = date_parts.next()?.parse().ok()?;
    let day: i64 = date_parts.next()?.parse().ok()?;
    let time_main = time.split('.').next().unwrap_or(time);
    let mut time_parts = time_main.split(':');
    let hour: i64 = time_parts.next()?.parse().ok()?;
    let minute: i64 = time_parts.next()?.parse().ok()?;
    let second: i64 = time_parts.next()?.parse().ok()?;
    if !(1..=12).contains(&month) || !(1..=31).contains(&day) {
        return None;
    }
    let days = days_from_civil(year, month, day)?;
    Some(days * 86_400 + hour * 3600 + minute * 60 + second - offset)
}

fn split_offset(s: &str) -> Option<(&str, i64)> {
    if let Some(i) = s.rfind('+') {
        if i > 10 {
            return Some((&s[..i], parse_offset(&s[i..])?));
        }
    }
    if let Some(i) = s.rfind('-') {
        if i > 10 {
            return Some((&s[..i], parse_offset(&s[i..])?));
        }
    }
    None
}

fn parse_offset(raw: &str) -> Option<i64> {
    let sign: i64 = if raw.starts_with('-') { -1 } else { 1 };
    let body = raw.trim_start_matches(['+', '-']);
    let (h, m): (i64, i64) = if body.len() == 4 && body.chars().all(|c| c.is_ascii_digit()) {
        (body[..2].parse().ok()?, body[2..].parse().ok()?)
    } else if let Some((h, m)) = body.split_once(':') {
        (h.parse().ok()?, m.parse().ok()?)
    } else {
        return None;
    };
    Some(sign * (h * 3600 + m * 60))
}

/// Civil date to days since Unix epoch (proleptic Gregorian). Howard Hinnant algorithm.
fn days_from_civil(y: i64, m: i64, d: i64) -> Option<i64> {
    let y = if m <= 2 { y - 1 } else { y };
    let era = if y >= 0 { y } else { y - 399 } / 400;
    let yoe = y - era * 400;
    let mp = if m > 2 { m - 3 } else { m + 9 };
    let doy = (153 * mp + 2) / 5 + d - 1;
    if !(0..=365).contains(&doy) {
        return None;
    }
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    Some(era * 146_097 + doe - 719_468)
}

/// True when `access_token_expiry` is present and strictly before `now` (UTC).
pub fn access_token_expired(creds: &Credentials, now: Option<SystemTime>) -> bool {
    let Some(expiry) = parse_access_token_expiry(&creds.access_token_expiry) else {
        return false;
    };
    let now = now.unwrap_or_else(SystemTime::now);
    let now_secs = match now.duration_since(UNIX_EPOCH) {
        Ok(d) => d.as_secs() as i64,
        Err(e) => -(e.duration().as_secs() as i64),
    };
    expiry < now_secs
}

#[derive(Clone)]
pub struct BetaToken {
    pub title: String,
    pub os: String,
    pub token: String,
}

impl BetaToken {
    pub fn os_display(&self) -> &str {
        match self.os.as_str() {
            "OSX" => "macOS",
            other => other,
        }
    }

    pub fn masked_token(&self) -> String {
        let t = &self.token;
        if t.len() > 12 {
            format!("{}...{}", &t[..6], &t[t.len() - 4..])
        } else {
            "[REDACTED]".to_string()
        }
    }
}

impl fmt::Debug for BetaToken {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "BetaToken(title={:?}, os={:?}, token=[REDACTED])",
            self.title, self.os
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::Duration;

    #[test]
    fn secrets_never_in_debug() {
        let c = Credentials {
            consumer_key: "CK_FAKE".into(),
            consumer_secret: "CS_FAKE".into(),
            access_token: "AT_FAKE".into(),
            access_secret: "AS_FAKE".into(),
            access_token_expiry: "2099-01-01T00:00:00Z".into(),
        };
        let s = format!("{c:?}");
        assert!(!s.contains("CS_FAKE"));
        assert!(!s.contains("AS_FAKE"));
        assert!(s.contains("[REDACTED]"));
    }

    #[test]
    fn expiry_past_and_future() {
        let past = Credentials {
            consumer_key: "ck".into(),
            consumer_secret: "cs".into(),
            access_token: "at".into(),
            access_secret: "as".into(),
            access_token_expiry: "2020-01-01T00:00:00Z".into(),
        };
        let future = Credentials {
            access_token_expiry: "2099-01-01T00:00:00Z".into(),
            ..past.clone()
        };
        let empty = Credentials {
            access_token_expiry: String::new(),
            ..past.clone()
        };
        let now = UNIX_EPOCH + Duration::from_secs(1_700_000_000);
        assert!(access_token_expired(&past, Some(now)));
        assert!(!access_token_expired(&future, Some(now)));
        assert!(!access_token_expired(&empty, Some(now)));
        assert_eq!(
            parse_access_token_expiry("2099-01-01T00:00:00Z"),
            Some(4_070_908_800)
        );
    }
}
