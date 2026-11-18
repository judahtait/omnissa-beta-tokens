#!/usr/bin/env python3
"""Generate docs/branding/logo-concepts.html: planning sketches for the app icon.

Usage: python3 tools/logo_board.py
These are concept sketches (inline SVG), not final artwork. Final icons should be
drawn to Omnissa's brand guidelines and, for the macOS 26 Liquid Glass icon, composed
in Icon Composer (Xcode 26).
"""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "branding" / "logo-concepts.html"

HEX = "512,182 798,347 798,677 512,842 226,677 226,347"
KEY = (
    '<circle cx="372" cy="512" r="128"/>'
    '<path d="M500 512 H790 M700 512 V600 M780 512 V580"/>'
)


def glyph(cid: str, paint: str, uid: str) -> str:
    """Glyph for a concept, painted with `paint` (a colour or url(#gradient))."""
    stroke = f'fill="none" stroke="{paint}" stroke-width="64" stroke-linecap="round" stroke-linejoin="round"'
    if cid == "key":
        return f'<g transform="translate(-21 0)" {stroke}>{KEY}</g>'
    if cid == "beta":
        return (
            f'<circle cx="512" cy="512" r="262" fill="none" stroke="{paint}" stroke-width="60"/>'
            f'<text x="512" y="528" text-anchor="middle" dominant-baseline="central" '
            f'font-family="Outfit, Helvetica, sans-serif" font-weight="500" font-size="360" fill="{paint}">&#946;</text>'
        )
    if cid == "download":
        return (
            f'<g fill="none" stroke="{paint}" stroke-width="56" stroke-linecap="round" stroke-linejoin="round">'
            '<path d="M346 232 H596 L728 364 V764 Q728 800 692 800 H346 Q310 800 310 764 V268 Q310 232 346 232 Z"/>'
            '<path d="M596 232 V364 H728"/>'
            '<path d="M519 440 V640 M440 568 L519 648 L598 568"/></g>'
        )
    if cid == "hexkey":
        return (
            f'<mask id="m{uid}"><rect width="1024" height="1024" fill="black"/>'
            f'<polygon points="{HEX}" fill="white" stroke="white" stroke-width="44" stroke-linejoin="round"/>'
            '<g transform="translate(512 512) scale(.5) translate(-533 -512)" fill="none" stroke="black" '
            f'stroke-width="76" stroke-linecap="round" stroke-linejoin="round">{KEY}</g></mask>'
            f'<rect width="1024" height="1024" fill="{paint}" mask="url(#m{uid})"/>'
        )
    raise ValueError(cid)


def icon(cid: str, style: str, size: int, uid: str) -> str:
    """One icon. style 'ws1' = white glossy tile (Workspace ONE apps); 'hub' = graphite tile (HubControl)."""
    tile = '<rect x="40" y="40" width="944" height="944" rx="212"/>'
    if style == "ws1":
        defs = (
            f'<linearGradient id="g{uid}" x1="0" y1="0" x2="0.4" y2="1">'
            '<stop offset="0" stop-color="#8F72FF"/><stop offset="1" stop-color="#4A12F0"/></linearGradient>'
        )
        base = f'<rect x="40" y="40" width="944" height="944" rx="212" fill="#FFFFFF" stroke="#E4E4EA" stroke-width="6"/>'
        paint = f"url(#g{uid})"
        edge = ""
    else:
        defs = (
            f'<linearGradient id="t{uid}" x1="0" y1="0" x2="1" y2="1">'
            '<stop offset="0" stop-color="#3A3A40"/><stop offset="0.5" stop-color="#1C1C20"/>'
            '<stop offset="1" stop-color="#0B0B0D"/></linearGradient>'
            f'<linearGradient id="e{uid}" x1="0" y1="0" x2="1" y2="0">'
            '<stop offset="0" stop-color="#4A12F0"/><stop offset="1" stop-color="#D600FF"/></linearGradient>'
        )
        base = f'<rect x="40" y="40" width="944" height="944" rx="212" fill="url(#t{uid})"/>'
        paint = "#FFFFFF"
        edge = f'<rect x="58" y="58" width="908" height="908" rx="196" fill="none" stroke="url(#e{uid})" stroke-width="7"/>'
    gloss = (
        f'<clipPath id="c{uid}">{tile}</clipPath>'
        f'<linearGradient id="s{uid}" x1="0" y1="0" x2="0" y2="1">'
        '<stop offset="0" stop-color="#FFFFFF" stop-opacity="0.34"/><stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/></linearGradient>'
    )
    gloss_shape = f'<g clip-path="url(#c{uid})"><rect x="40" y="40" width="944" height="470" fill="url(#s{uid})"/></g>'
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="{size}" height="{size}" role="img">'
        f"<defs>{defs}{gloss}</defs>{base}{edge}{glyph(cid, paint, uid)}{gloss_shape}</svg>"
    )


CONCEPTS = [
    ("key", "A. Key",
     "The server token is a key. Plain, instantly readable at 16 px, and close to the Tunnel/keyhole family without copying it.",
     "Best small-size legibility."),
    ("beta", "B. Beta token",
     "A coin-style token ring with the Greek beta, set in Outfit Medium. Says 'beta' and 'token' in one mark.",
     "Most literal; relies on the font being outlined for the final icon."),
    ("download", "C. Certificate to token",
     "A certificate page with a download arrow: the .pem goes up, the .p7m token comes down. Tells the workflow story.",
     "Busiest at small sizes."),
    ("hexkey", "D. Hub hexagon with key",
     "A hexagon (a nod to HubControl's Hub mark) with the key knocked out. Reads as part of the Omnissa Hub tool family.",
     "Strongest family tie-in with HubControl."),
]


def main() -> None:
    cards = []
    for n, (cid, title, why, note) in enumerate(CONCEPTS):
        a = icon(cid, "ws1", 220, f"{cid}a")
        b = icon(cid, "hub", 220, f"{cid}b")
        small = "".join(
            f'<span class="sm">{icon(cid, "hub", s, f"{cid}b{s}")}<em>{s}px</em></span>' for s in (128, 64, 32)
        )
        small_w = "".join(
            f'<span class="sm">{icon(cid, "ws1", s, f"{cid}a{s}")}<em>{s}px</em></span>' for s in (128, 64, 32)
        )
        cards.append(
            f'<section class="card"><h2>{title}</h2><p>{why}</p><p class="note">{note}</p>'
            f'<div class="row"><figure>{a}<figcaption>White glossy tile (Workspace ONE apps)</figcaption></figure>'
            f'<figure>{b}<figcaption>Graphite tile (HubControl)</figcaption></figure></div>'
            f'<div class="row small">{small_w}{small}</div></section>'
        )

    html = f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Omnissa Beta Token Utility - icon concepts</title>
<style>
@font-face{{font-family:Outfit;font-weight:300;src:local("Outfit Light"),local("Outfit-Light"),url(../../assets/fonts/Outfit-Light.ttf)}}
@font-face{{font-family:Outfit;font-weight:500;src:local("Outfit Medium"),local("Outfit-Medium"),url(../../assets/fonts/Outfit-Medium.ttf)}}
:root{{--accent:#4A12F0;--heading:#1C1C20;--text:#1D1D1F;--muted:#6E6E73;--rule:#D1D1D6;--surface:#F5F5F7;--card:#fff}}
@media(prefers-color-scheme:dark){{:root{{--accent:#7050FF;--heading:#F2F2F7;--text:#E5E5E7;--muted:#A1A1A6;--rule:#3A3A3C;--surface:#141416;--card:#1E1E21}}}}
*{{box-sizing:border-box}}
body{{margin:0;background:var(--surface);color:var(--text);font-family:Outfit,system-ui,sans-serif;font-weight:300;line-height:1.55}}
header{{background:linear-gradient(90deg,#3A3A40,#1C1C20,#0B0B0D);color:#fff;padding:36px 16px 30px;border-bottom:3px solid transparent;border-image:linear-gradient(90deg,#4A12F0,#D600FF) 1}}
.wrap{{max-width:1040px;margin:0 auto;padding:0 16px}} header .wrap{{padding:0}}
h1{{font-weight:500;font-size:30px;margin:6px 0 6px}} .eyebrow{{font-weight:500;letter-spacing:.14em;font-size:12px;text-transform:uppercase;opacity:.9}}
main{{padding:24px 0 48px}} .grid{{display:grid;grid-template-columns:repeat(auto-fit,minmax(440px,1fr));gap:18px}}
.card{{background:var(--card);border:1px solid var(--rule);border-radius:18px;padding:20px}}
h2{{font-weight:500;color:var(--heading);margin:0 0 4px;font-size:20px}} p{{margin:4px 0}} .note{{color:var(--muted);font-size:14px}}
.row{{display:flex;gap:18px;flex-wrap:wrap;margin-top:14px;align-items:flex-end}} figure{{margin:0}} figcaption{{font-size:12px;color:var(--muted);margin-top:6px;max-width:220px}}
.small .sm{{display:inline-flex;flex-direction:column;align-items:center;gap:4px;margin-right:6px}} .sm em{{font-style:normal;font-size:11px;color:var(--muted)}}
.plan{{background:var(--card);border:1px solid var(--rule);border-radius:18px;padding:20px;margin-top:18px}}
.plan h2{{margin-bottom:8px}} .plan li{{margin:4px 0}} code{{font-size:.9em}}
</style></head><body>
<header><div class="wrap"><div class="eyebrow">Omnissa &middot; Workspace ONE UEM</div><h1>Beta Token Utility - icon concepts</h1>
<div>Planning sketches. Each concept is shown in the two Omnissa house tile styles.</div></div></header>
<main class="wrap">
<div class="grid">{''.join(cards)}</div>
<section class="plan"><h2>Plan to finish the icon</h2><ol>
<li><b>Pick a concept</b> (my recommendation: <b>D</b> for family fit, or <b>A</b> if small-size clarity matters most) and a tile style.</li>
<li><b>Check against the Omnissa brand guidelines</b> and the official logo rules. Do not use Apple's logo or Apple marks, and do not reuse an existing Omnissa product mark, without brand approval. Status: guidelines not read; no official logo available.</li>
<li><b>Draw the final artwork</b> at 1024 px as vector, with text outlined (concept B). Graphite tile is generated the way HubControl's <code>make-app-icons.swift</code> does it.</li>
<li><b>Liquid Glass version</b>: compose layers (tile, glyph, specular) in Icon Composer (Xcode 26) for macOS 26. Keep a flat <code>.icns</code> for earlier systems. Needs full Xcode, which this Mac does not have.</li>
<li><b>Export</b> the 16 to 1024 px iconset to <code>assets/AppIcon.icns</code>. <code>tools/make_app.sh</code> already bundles it and sets <code>CFBundleIconFile</code> when the file exists.</li>
<li><b>Reuse</b> the mark in the guide header and the app header band.</li></ol></section>
</main></body></html>"""
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(html, encoding="utf-8")
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
