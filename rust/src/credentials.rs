use std::fmt;

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
}
