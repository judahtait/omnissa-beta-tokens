//! Output formatting: table, JSON, and CSV.

use serde_json::{json, Value};

use crate::credentials::BetaToken;

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
}
