#!/usr/bin/env python3
"""Generate docs/branding/logo-d-beta.html: comparison page for the hexagon + key + beta icon variants.

Usage: python3 tools/logo_board_d.py   (needs the PNGs from: make_icon sheet docs/branding/icons)
"""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "branding" / "logo-d-beta.html"

VARIANTS = [
    ("v1-layered", "1. Layered glass",
     "Glass hexagon, the beta, and the key laid over its lower bowl. Closest to concept D with the beta layered in."),
    ("v2-key-bow", "2. Key with the beta in its bow",
     "The beta sits inside the key's bow, all inside the hexagon. Clearest single idea: a key for the beta token."),
    ("v3-badge", "3. Beta with key badge",
     "Large beta in a hexagon outline with a small key badge on the corner. Beta first, key second."),
]
TILES = [("white", "White tile, Omnissa-gradient mark"), ("omnissa", "Omnissa gradient tile (navy, indigo, magenta) - chosen"), ("light", "Lighter gradient tile (indigo, magenta)")]


def card(vid: str, title: str, why: str) -> str:
    rows = ""
    for tid, tname in TILES:
        big = f"icons/{vid}-{tid}-1024.png"
        small = f"icons/{vid}-{tid}-64.png"
        rows += (
            f'<figure><img src="{big}" width="240" height="240" alt="{title}, {tname}">'
            f'<figcaption>{tname}</figcaption>'
            f'<div class="sm"><img src="{small}" width="64" height="64" alt=""><img src="{small}" width="32" height="32" alt="">'
            f'<img src="{small}" width="16" height="16" alt=""><em>64 / 32 / 16 px</em></div></figure>'
        )
    return f'<section class="card"><h2>{title}</h2><p>{why}</p><div class="row">{rows}</div></section>'


def main() -> None:
    cards = "".join(card(*v) for v in VARIANTS)
    html = f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Omnissa Beta Token Utility - icon, hexagon with key and beta</title>
<style>
@font-face{{font-family:Outfit;font-weight:300;src:local("Outfit Light"),url(../../assets/fonts/Outfit-Light.ttf)}}
@font-face{{font-family:Outfit;font-weight:500;src:local("Outfit Medium"),url(../../assets/fonts/Outfit-Medium.ttf)}}
:root{{--heading:#1C1C20;--text:#1D1D1F;--muted:#6E6E73;--rule:#D1D1D6;--surface:#F5F5F7;--card:#fff}}
@media(prefers-color-scheme:dark){{:root{{--heading:#F2F2F7;--text:#E5E5E7;--muted:#A1A1A6;--rule:#3A3A3C;--surface:#141416;--card:#1E1E21}}}}
*{{box-sizing:border-box}} body{{margin:0;background:var(--surface);color:var(--text);font-family:Outfit,system-ui,sans-serif;font-weight:300;line-height:1.55}}
header{{background:linear-gradient(100deg,#001E60,#4A12F0,#D600FF);color:#fff;padding:34px 16px 28px}}
.wrap{{max-width:1040px;margin:0 auto;padding:0 16px}} header .wrap{{padding:0}}
h1{{font-weight:500;font-size:30px;margin:4px 0}} .eyebrow{{font-weight:500;letter-spacing:.14em;font-size:12px;text-transform:uppercase}}
main{{padding:24px 0 48px}} .card{{background:var(--card);border:1px solid var(--rule);border-radius:18px;padding:20px;margin-bottom:18px}}
h2{{font-weight:500;color:var(--heading);margin:0 0 4px;font-size:20px}} p{{margin:4px 0}}
.row{{display:flex;gap:28px;flex-wrap:wrap;margin-top:12px}} figure{{margin:0}} figcaption{{font-size:13px;color:var(--muted);margin:6px 0}}
.sm{{display:flex;gap:10px;align-items:flex-end}} .sm em{{font-style:normal;font-size:12px;color:var(--muted)}}
.note{{color:var(--muted);font-size:14px}} code{{font-size:.9em}}
</style></head><body>
<header><div class="wrap"><div class="eyebrow">Omnissa &middot; Workspace ONE UEM</div><h1>Beta Token Utility icon</h1>
<div>Concept D (hexagon with a key) with the Greek beta layered in. Rendered with CoreGraphics by <code>tools/make_icon.swift</code>.</div></div></header>
<main class="wrap">{cards}
<section class="card"><h2>Notes</h2>
<p><b>Chosen:</b> variant 1 (layered glass: hexagon, beta, key) on the Omnissa gradient tile. The other variants and tile styles are kept for reference.</p>
<p class="note">The beta is a drawn monoline path, not a font glyph (Outfit has no Greek characters). Not yet checked against the Omnissa brand guidelines, and no official logo was available. The app ships variant 1 on the Omnissa gradient tile (<code>assets/AppIcon.icns</code>).</p>
<p class="note">Switch the icon: <code>make_icon iconset &lt;variant&gt; &lt;tile&gt; assets/AppIcon.iconset</code>, then <code>python3 tools/make_icns.py assets/AppIcon.iconset assets/AppIcon.icns</code>, then <code>tools/make_app.sh</code>. For a macOS 26 Liquid Glass icon, compose the layers in Icon Composer (Xcode 26).</p></section>
</main></body></html>"""
    OUT.write_text(html, encoding="utf-8")
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
