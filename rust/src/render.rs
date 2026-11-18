//! Output formatting: table, JSON, CSV, and UEM paste guidance.

use serde_json::{json, Value};

use crate::credentials::BetaToken;

/// Platforms where Software Update:Settings > Beta cannot deliver a program.
const UEM_BETA_UNSUPPORTED_OS: &[&str] = &["tvos", "visionos"];

/// Mode field checklist matching Python / Swift UEM guidance (not declaration JSON).
const UEM_MODE_CHECKLIST: &[(&str, &str)] = &[
    (
        "Automatic",
        "Program enrollment=AlwaysOn, Require program=on, Offer programs=off",
    ),
    (
        "Offer",
        "Program enrollment=Allowed, Require program=off, Offer programs=on",
    ),
    (
        "Offer-no-sign-in",
        "Program enrollment=AlwaysOn, Require program=off, Offer programs=on",
    ),
    (
        "Block",
        "Program enrollment=AlwaysOff (no program; block and unenroll)",
    ),
];

/// Match Python: sort, then OS membership on lowered os/os_display, then title substring.
pub fn filter_tokens(
    tokens: &[BetaToken],
    os_name: Option<&str>,
    match_text: Option<&str>,
) -> Vec<BetaToken> {
    let mut out = tokens.to_vec();
    out.sort_by(|a, b| {
        (
            a.os_display().to_ascii_lowercase(),
            a.title.to_ascii_lowercase(),
        )
            .cmp(&(
                b.os_display().to_ascii_lowercase(),
                b.title.to_ascii_lowercase(),
            ))
    });
    if let Some(os) = os_name {
        let wanted = os.to_ascii_lowercase();
        out.retain(|t| {
            t.os.to_ascii_lowercase() == wanted || t.os_display().to_ascii_lowercase() == wanted
        });
    }
    if let Some(m) = match_text {
        let m = m.to_ascii_lowercase();
        out.retain(|t| t.title.to_ascii_lowercase().contains(&m));
    }
    out
}

/// Distinct display names among tokens that UEM Beta cannot deliver.
pub fn unsupported_uem_beta_oses(tokens: &[BetaToken]) -> Vec<String> {
    let mut found = Vec::new();
    let mut seen = std::collections::HashSet::new();
    for t in tokens {
        let key = t.os_display().to_ascii_lowercase();
        if UEM_BETA_UNSUPPORTED_OS.contains(&key.as_str()) && seen.insert(key) {
            found.push(t.os_display().to_string());
        }
    }
    found
}

/// Title + token + Mode field checklist for UEM paste (not declaration JSON).
pub fn uem_paste_block(token: &BetaToken) -> String {
    let width = UEM_MODE_CHECKLIST
        .iter()
        .map(|(name, _)| name.len())
        .max()
        .unwrap_or(0);
    let mut lines = vec![
        "=== UEM Software Update: Settings > Beta ===".to_string(),
        format!("Title: {}", token.title),
        format!("Token: {}", token.token),
        String::new(),
        "Mode field checklist (pick one combination in UEM; not JSON):".to_string(),
    ];
    for (name, summary) in UEM_MODE_CHECKLIST {
        lines.push(format!("  {name:<width$}  {summary}"));
    }
    lines.join("\n")
}

pub fn to_table(tokens: &[BetaToken], reveal: bool) -> String {
    let mut rows: Vec<(String, String, String)> =
        vec![("Title".into(), "OS".into(), "Token".into())];
    for t in tokens {
        rows.push((
            t.title.clone(),
            t.os_display().to_string(),
            if reveal {
                t.token.clone()
            } else {
                t.masked_token()
            },
        ));
    }
    let widths = [
        rows.iter().map(|r| r.0.len()).max().unwrap_or(0),
        rows.iter().map(|r| r.1.len()).max().unwrap_or(0),
        rows.iter().map(|r| r.2.len()).max().unwrap_or(0),
    ];
    let mut lines = Vec::new();
    for (i, r) in rows.iter().enumerate() {
        lines.push(format!(
            "{:<w0$}  {:<w1$}  {:<w2$}",
            r.0,
            r.1,
            r.2,
            w0 = widths[0],
            w1 = widths[1],
            w2 = widths[2]
        ));
        if i == 0 {
            lines.push(format!(
                "{:-<w0$}  {:-<w1$}  {:-<w2$}",
                "",
                "",
                "",
                w0 = widths[0],
                w1 = widths[1],
                w2 = widths[2]
            ));
        }
    }
    lines.join("\n")
}

pub fn to_json(tokens: &[BetaToken]) -> String {
    let arr: Vec<Value> = tokens
        .iter()
        .map(|t| {
            json!({
                "title": t.title,
                "os": t.os_display(),
                "token": t.token,
            })
        })
        .collect();
    serde_json::to_string_pretty(&arr).unwrap_or_else(|_| "[]".into())
}

pub fn to_csv(tokens: &[BetaToken]) -> String {
    let mut out = String::from("title,os,token\n");
    for t in tokens {
        out.push_str(&format!(
            "{},{},{}\n",
            csv_escape(&t.title),
            csv_escape(t.os_display()),
            csv_escape(&t.token)
        ));
    }
    out
}

fn csv_escape(s: &str) -> String {
    if s.contains(',') || s.contains('"') || s.contains('\n') {
        format!("\"{}\"", s.replace('"', "\"\""))
    } else {
        s.to_string()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn toks() -> Vec<BetaToken> {
        vec![
            BetaToken {
                title: "macOS Test Beta".into(),
                os: "OSX".into(),
                token: "M".repeat(40),
            },
            BetaToken {
                title: "iOS Test Beta".into(),
                os: "iOS".into(),
                token: "I".repeat(40),
            },
            BetaToken {
                title: "tvOS Seed".into(),
                os: "tvOS".into(),
                token: "T".repeat(40),
            },
        ]
    }

    #[test]
    fn filter_by_os_and_title() {
        let t = toks();
        assert_eq!(filter_tokens(&t, Some("macos"), None).len(), 1);
        assert_eq!(filter_tokens(&t, None, Some("ios")).len(), 1);
    }

    #[test]
    fn table_masks_by_default() {
        let t = toks();
        let table = to_table(&t, false);
        assert!(!table.contains(&"M".repeat(40)));
        assert!(table.contains("MMMMMM...MMMM"));
    }

    #[test]
    fn uem_block_lists_four_modes() {
        let t = &toks()[0];
        let block = uem_paste_block(t);
        assert!(block.contains("Title: macOS Test Beta"));
        assert!(block.contains(&format!("Token: {}", "M".repeat(40))));
        assert!(block.contains("Automatic"));
        assert!(block.contains("Offer-no-sign-in"));
        assert!(block.contains("Block"));
        assert!(block.contains("not JSON"));
        assert!(!block.contains("com.apple.configuration"));
    }

    #[test]
    fn unsupported_oses_detected() {
        let names = unsupported_uem_beta_oses(&toks());
        assert_eq!(names, vec!["tvOS".to_string()]);
    }
}
