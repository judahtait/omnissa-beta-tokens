"""Output formatting: table, JSON, and CSV."""

from __future__ import annotations

import csv
import io
import json

from .abm import BetaToken


def filter_tokens(tokens: list[BetaToken], os_name: str | None, match: str | None) -> list[BetaToken]:
    out = sorted(tokens, key=lambda t: (t.os_display.lower(), t.title.lower()))
    if os_name:
        wanted = os_name.lower()
        out = [t for t in out if wanted in (t.os.lower(), t.os_display.lower())]
    if match:
        out = [t for t in out if match.lower() in t.title.lower()]
    return out


def _mask_token(token: str) -> str:
    return f"{token[:6]}...{token[-4:]}" if len(token) > 12 else "[REDACTED]"


def to_table(tokens: list[BetaToken], reveal: bool = False) -> str:
    rows = [("Title", "OS", "Token")] + [
        (t.title, t.os_display, t.token if reveal else _mask_token(t.token))
        for t in tokens
    ]
    widths = [max(len(r[i]) for r in rows) for i in range(3)]
    fmt = "  ".join(f"{{:<{w}}}" for w in widths)
    lines = [fmt.format(*rows[0]), fmt.format(*("-" * w for w in widths))]
    lines += [fmt.format(*r) for r in rows[1:]]
    return "\n".join(lines)


def to_json(tokens: list[BetaToken]) -> str:
    return json.dumps(
        [{"title": t.title, "os": t.os_display, "token": t.token} for t in tokens],
        indent=2,
    )


def to_csv(tokens: list[BetaToken]) -> str:
    buf = io.StringIO()
    w = csv.writer(buf, lineterminator="\n")
    w.writerow(["title", "os", "token"])
    for t in tokens:
        w.writerow([t.title, t.os_display, t.token])
    return buf.getvalue()
