//! Client for the Apple Business / Apple School Manager ADE web service.

use std::io::Read;

use serde_json::Value;

use crate::credentials::{BetaToken, Credentials, ToolError};
use crate::oauth::build_oauth_header;

pub const SESSION_URL: &str = "https://mdmenrollment.apple.com/session";
pub const TOKENS_URL: &str = "https://mdmenrollment.apple.com/os-beta-enrollment/tokens";

pub type Transport = Box<dyn Fn(&str, Vec<(String, String)>) -> Result<(u16, Vec<u8>), ToolError>>;

fn live_get_no_redirect(
    url: &str,
    headers: Vec<(String, String)>,
) -> Result<(u16, Vec<u8>), ToolError> {
    // Refuse redirects so Authorization is never replayed to another host.
    let agent = ureq::AgentBuilder::new().redirects(0).build();
    let mut req = agent.get(url);
    for (k, v) in &headers {
        req = req.set(k, v);
    }
    match req.call() {
        Ok(resp) => {
            let status = resp.status();
            let mut body = Vec::new();
            resp.into_reader()
                .read_to_end(&mut body)
                .map_err(|e| ToolError::msg(format!("Network error contacting Apple: {e}")))?;
            Ok((status, body))
        }
        Err(ureq::Error::Status(code, resp)) => {
            let mut body = Vec::new();
            let _ = resp.into_reader().read_to_end(&mut body);
            Ok((code, body))
        }
        Err(ureq::Error::Transport(t)) => Err(ToolError::msg(format!(
            "Network error contacting Apple: {t}"
        ))),
    }
}

pub fn default_transport() -> Transport {
    Box::new(live_get_no_redirect)
}

pub fn get_session_token(creds: &Credentials, transport: &Transport) -> Result<String, ToolError> {
    let header = build_oauth_header(
        "GET",
        SESSION_URL,
        &creds.consumer_key,
        &creds.consumer_secret,
        &creds.access_token,
        &creds.access_secret,
        None,
        None,
    );
    let (status, body) = transport(
        SESSION_URL,
        vec![
            ("Authorization".into(), header),
            ("Accept".into(), "application/json".into()),
        ],
    )?;
    if status != 200 {
        return Err(ToolError::msg(format!(
            "Session request failed (HTTP {status}). The server token may be expired or revoked; generate a new one in Apple Business."
        )));
    }
    let v: Value = serde_json::from_slice(&body)
        .map_err(|_| ToolError::msg("auth_session_token missing in session response."))?;
    v.get("auth_session_token")
        .and_then(|x| x.as_str())
        .filter(|s| !s.is_empty())
        .map(str::to_string)
        .ok_or_else(|| ToolError::msg("auth_session_token missing in session response."))
}

pub fn get_beta_tokens(
    session_token: &str,
    transport: &Transport,
) -> Result<Vec<BetaToken>, ToolError> {
    let (status, body) = transport(
        TOKENS_URL,
        vec![
            ("X-ADM-Auth-Session".into(), session_token.into()),
            ("X-Server-Protocol-Version".into(), "1".into()),
            ("Accept".into(), "application/json".into()),
        ],
    )?;
    if status == 403
        && body
            .windows(b"APPLE_SEED_FOR_IT_TURNED_OFF".len())
            .any(|w| w == b"APPLE_SEED_FOR_IT_TURNED_OFF")
    {
        return Err(ToolError::msg(
            "Beta access is turned off for this organization (APPLE_SEED_FOR_IT_TURNED_OFF). Enroll the organization in AppleSeed for IT at https://beta.apple.com/for-it and retry.",
        ));
    }
    if status != 200 {
        return Err(ToolError::msg(format!(
            "Beta token request failed (HTTP {status})."
        )));
    }
    let v: Value = serde_json::from_slice(&body)
        .map_err(|e| ToolError::msg(format!("Unexpected beta token response: {e}")))?;
    let items = v
        .get("betaEnrollmentTokens")
        .and_then(|x| x.as_array())
        .ok_or_else(|| {
            ToolError::msg("Unexpected beta token response: missing betaEnrollmentTokens")
        })?;
    let mut out = Vec::new();
    for i in items {
        let title = i
            .get("title")
            .and_then(|x| x.as_str())
            .unwrap_or("")
            .to_string();
        let os = i
            .get("os")
            .and_then(|x| x.as_str())
            .unwrap_or("")
            .to_string();
        let token = i
            .get("token")
            .and_then(|x| x.as_str())
            .unwrap_or("")
            .to_string();
        if !title.is_empty() && !os.is_empty() && !token.is_empty() {
            out.push(BetaToken { title, os, token });
        }
    }
    Ok(out)
}

pub fn fetch_beta_tokens(
    creds: &Credentials,
    transport: &Transport,
) -> Result<Vec<BetaToken>, ToolError> {
    let session = get_session_token(creds, transport)?;
    get_beta_tokens(&session, transport)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn fake_creds() -> Credentials {
        Credentials {
            consumer_key: "CK_FAKE".into(),
            consumer_secret: "CS_FAKE".into(),
            access_token: "AT_FAKE".into(),
            access_secret: "AS_FAKE".into(),
            access_token_expiry: String::new(),
        }
    }

    #[test]
    fn fetch_with_fake_transport() {
        let transport: Transport = Box::new(|url, _| {
            if url.contains("/session") {
                Ok((200, br#"{"auth_session_token":"SESS"}"#.to_vec()))
            } else {
                Ok((
                    200,
                    br#"{"betaEnrollmentTokens":[{"title":"macOS Test","os":"OSX","token":"TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT"}]}"#.to_vec(),
                ))
            }
        });
        let toks = fetch_beta_tokens(&fake_creds(), &transport).unwrap();
        assert_eq!(toks.len(), 1);
        assert_eq!(toks[0].os_display(), "macOS");
    }

    #[test]
    fn seed_turned_off() {
        let transport: Transport = Box::new(|url, _| {
            if url.contains("/session") {
                Ok((200, br#"{"auth_session_token":"SESS"}"#.to_vec()))
            } else {
                Ok((403, b"APPLE_SEED_FOR_IT_TURNED_OFF".to_vec()))
            }
        });
        let err = fetch_beta_tokens(&fake_creds(), &transport)
            .unwrap_err()
            .to_string();
        assert!(err.contains("APPLE_SEED_FOR_IT_TURNED_OFF"));
    }

    #[test]
    fn session_failure() {
        let transport: Transport = Box::new(|_, _| Ok((401, b"{}".to_vec())));
        let err = get_session_token(&fake_creds(), &transport)
            .unwrap_err()
            .to_string();
        assert!(err.contains("Session request failed"));
    }
}
