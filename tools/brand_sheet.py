#!/usr/bin/env python3
"""Generate docs/branding/brand-template.html: the brand tokens and components on one page.

Usage: python3 tools/brand_sheet.py
Palette: HubControl's Brand (hubcontrol-rs, crates/hc-menubar/src/brand.rs). Gradient: the Omnissa
toolkit theme (navy, indigo, magenta). Font: Outfit Light and Medium (SIL OFL 1.1), embedded.
"""

from __future__ import annotations

import base64
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "branding" / "brand-template.html"

# (name, light, dark, usage)
PALETTE = [
    ("accent", "#4A12F0", "#7050FF", "Buttons, links, selection, step numbers"),
    ("heading", "#1C1C20", "#F2F2F7", "Titles"),
    ("text", "#1D1D1F", "#E5E5E7", "Body copy"),
    ("muted", "#6E6E73", "#A1A1A6", "Secondary text, captions"),
    ("rule", "#D1D1D6", "#3A3A3C", "Separators, borders"),
    ("surface", "#F5F5F7", "#141416", "Window / page background"),
    ("card", "#FFFFFF", "#1E1E21", "Cards, list background"),
    ("ok", "#248A3D", "#30D158", "Healthy / success"),
    ("magenta", "#D600FF", "#D600FF", "Negative or exception data only, and the end of the gradient"),
]


def font_css() -> str:
    out = ""
    for weight, name in ((300, "Outfit-Light"), (500, "Outfit-Medium")):
        f = ROOT / "assets" / "fonts" / f"{name}.ttf"
        b64 = base64.b64encode(f.read_bytes()).decode()
        out += f"@font-face{{font-family:'Outfit';font-weight:{weight};src:url(data:font/ttf;base64,{b64}) format('truetype')}}\n"
    return out


def swatches() -> str:
    rows = ""
    for name, light, dark, use in PALETTE:
        rows += (
            f'<div class="sw"><div class="chips"><span style="background:{light}"></span><span style="background:{dark}"></span></div>'
            f"<div><b>{name}</b><br><code>{light}</code> light &middot; <code>{dark}</code> dark<br><small>{use}</small></div></div>"
        )
    return rows


CSS = """
:root{--accent:#4A12F0;--heading:#1C1C20;--text:#1D1D1F;--muted:#6E6E73;--rule:#D1D1D6;--surface:#F5F5F7;--card:#FFFFFF;--ok:#248A3D;--thbg:#001E60}
:root[data-theme=dark]{--accent:#7050FF;--heading:#F2F2F7;--text:#E5E5E7;--muted:#A1A1A6;--rule:#3A3A3C;--surface:#141416;--card:#1E1E21;--ok:#30D158;--thbg:#1B2A66}
@media(prefers-color-scheme:dark){:root:not([data-theme=light]){--accent:#7050FF;--heading:#F2F2F7;--text:#E5E5E7;--muted:#A1A1A6;--rule:#3A3A3C;--surface:#141416;--card:#1E1E21;--ok:#30D158;--thbg:#1B2A66}}
*{box-sizing:border-box}
body{margin:0;background:var(--surface);color:var(--text);font-family:'Outfit',system-ui,sans-serif;font-weight:300;line-height:1.55;position:relative;overflow-x:hidden}
body:before,body:after{content:"";position:fixed;z-index:0;border-radius:50%;filter:blur(110px);pointer-events:none}
body:before{width:460px;height:460px;background:#4A12F0;opacity:.22;left:-140px;top:120px}
body:after{width:420px;height:420px;background:#D600FF;opacity:.14;right:-120px;bottom:40px}
header,main{position:relative;z-index:1}
header{background:linear-gradient(100deg,#001E60,#4A12F0,#D600FF);color:#fff;padding:30px 16px 26px;position:relative}
header:after{content:"";position:absolute;inset:0;background:linear-gradient(180deg,rgba(255,255,255,.18),rgba(255,255,255,0) 55%)}
.wrap{max-width:1000px;margin:0 auto;padding:0 16px;position:relative;z-index:1}
.hd{display:flex;gap:16px;align-items:center}.hd img{width:72px;height:72px}
.eyebrow{font-weight:500;letter-spacing:.14em;font-size:12px;text-transform:uppercase;opacity:.92}
h1{font-weight:500;font-size:30px;margin:2px 0}
h2{font-weight:500;color:var(--heading);font-size:22px;margin:34px 0 10px;padding-bottom:6px;border-bottom:2px solid var(--rule)}
h3{font-weight:500;color:var(--accent);font-size:16px;margin:18px 0 6px}
main{padding:8px 0 56px}
.glass{background:color-mix(in srgb,var(--card) 62%,transparent);-webkit-backdrop-filter:blur(18px) saturate(1.3);backdrop-filter:blur(18px) saturate(1.3);border:1px solid color-mix(in srgb,#fff 45%,var(--rule));border-radius:16px;padding:16px;box-shadow:0 8px 28px rgba(0,0,0,.10)}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:14px}
.sw{display:flex;gap:12px;align-items:center}.chips{display:flex;border-radius:12px;overflow:hidden;border:1px solid var(--rule);flex:none}
.chips span{width:44px;height:56px;display:block}
small,.muted{color:var(--muted)}code{font-family:ui-monospace,Menlo,monospace;font-size:.85em}
.bar{height:44px;border-radius:12px;margin:6px 0;display:flex;align-items:center;padding:0 14px;color:#fff;font-weight:500;font-size:14px}
.btn{display:inline-block;font-family:inherit;font-weight:500;font-size:14px;border-radius:999px;padding:8px 18px;border:1px solid var(--accent);cursor:default;margin:4px 6px 4px 0}
.btn.p{background:linear-gradient(180deg,rgba(255,255,255,.28),rgba(255,255,255,0) 55%),var(--accent);color:#fff}
.btn.s{background:color-mix(in srgb,var(--card) 75%,transparent);color:var(--accent)}
.btn.d{background:var(--rule);border-color:var(--rule);color:var(--muted)}
.num{display:inline-flex;width:24px;height:24px;border-radius:50%;background:var(--accent);color:#fff;align-items:center;justify-content:center;font-weight:500;font-size:13px;margin-right:8px}
table{border-collapse:collapse;width:100%;font-size:15px}
th{background:var(--thbg);color:#fff;font-weight:500;text-align:left;padding:8px 12px}
td{padding:8px 12px;border-bottom:1px solid var(--rule)}tr:nth-child(even) td{background:color-mix(in srgb,var(--card) 70%,transparent)}
.callout{border-left:4px solid var(--accent);background:color-mix(in srgb,var(--card) 70%,transparent);padding:12px 16px;border-radius:6px}
.err{color:#D600FF;font-weight:500}.okc{color:var(--ok);font-weight:500}
.type .l{font-weight:300}.type .m{font-weight:500}
.icons{display:flex;gap:14px;flex-wrap:wrap;align-items:flex-end}.icons figure{margin:0}.icons img{display:block;border-radius:0}
figcaption{font-size:12px;color:var(--muted);margin-top:4px}
.dd{display:grid;grid-template-columns:1fr 1fr;gap:14px}@media(max-width:640px){.dd{grid-template-columns:1fr}}
.do li::marker{color:var(--ok)}.dont li::marker{color:#D600FF}
button.t{font-family:inherit;font-weight:500;border-radius:999px;border:1px solid #fff;background:rgba(255,255,255,.18);color:#fff;padding:6px 14px;cursor:pointer;position:relative;z-index:2}
"""


def main() -> None:
    icon = "icons/v1-layered-omnissa-1024.png"
    html = f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Omnissa Beta Token Utility - brand template</title>
<style>{font_css()}{CSS}</style></head><body>
<header><div class="wrap"><div class="hd"><img src="{icon}" alt="">
<div><div class="eyebrow">Omnissa &middot; Workspace ONE UEM</div><h1>Brand template</h1>
<div>Tokens and components shared by the app, the guide and the icon.</div></div>
<button class="t" style="margin-left:auto" onclick="var r=document.documentElement;r.dataset.theme=r.dataset.theme==='dark'?'light':'dark'">Toggle light / dark</button></div></div></header>
<main class="wrap">

<h2>1. Gradient</h2>
<div class="bar" style="background:linear-gradient(100deg,#001E60,#4A12F0,#D600FF)">Omnissa gradient: navy #001E60, indigo #4A12F0, magenta #D600FF (header band, icon tile)</div>
<div class="bar" style="background:linear-gradient(100deg,#4A12F0,#D600FF)">Lighter: indigo #4A12F0 to magenta #D600FF (icon tile, light variant)</div>
<p class="muted">One gradient only. The earlier graphite header is retired.</p>

<h2>2. Palette (light and dark)</h2>
<div class="grid">{swatches()}</div>

<h2>3. Typography</h2>
<div class="glass type"><div class="eyebrow" style="color:var(--accent)">Outfit Medium 500 &middot; eyebrow, tracking .14em</div>
<div class="m" style="font-size:30px;color:var(--heading)">Beta Token Utility</div>
<div class="m" style="font-size:20px;color:var(--heading)">Create certificate</div>
<div class="l" style="font-size:16px">Outfit Light 300 for body copy. Get Apple beta enrollment tokens for your declarative Software Update profile.</div>
<div class="l muted" style="font-size:13px">Caption and secondary text, Outfit Light 300, muted.</div>
<p class="muted">Two weights only (Light 300, Medium 500). Outfit has no Greek characters, so the beta in the icon is drawn as artwork. Monospace is used for tokens and code. SIL Open Font License 1.1.</p></div>

<h2>4. Components</h2>
<div class="grid">
<div class="glass"><h3>Buttons</h3><span class="btn p">Fetch beta tokens</span><span class="btn s">Show in Finder</span><span class="btn d">Disabled</span></div>
<div class="glass"><h3>Step card (Liquid Glass surface)</h3><p><span class="num">1</span><b style="font-weight:500;color:var(--heading)">Create certificate</b></p><p class="muted">Frosted card with a white tint over the material, a specular edge and a soft shadow.</p></div>
<div class="glass"><h3>Status</h3><p class="okc">Certificate ready</p><p class="muted">Token copied to clipboard.</p><p class="err">Beta access is turned off for this organization.</p><small>Magenta is reserved for negative or exception data.</small></div>
</div>
<h3>Guide components</h3>
<div class="callout"><b style="font-weight:500">Callout.</b> Used for notes and assumptions, for example "Assumption, not validated on a test device".</div>
<p></p>
<table><tr><th>Mode</th><th>Program enrollment</th><th>Require program</th></tr>
<tr><td>Automatic</td><td>AlwaysOn</td><td>On</td></tr><tr><td>Offer to user</td><td>Allowed</td><td>Off</td></tr><tr><td>Block and unenroll</td><td>AlwaysOff</td><td>Off</td></tr></table>
<p>Code and tokens use <code>monospace</code> on a tinted background.</p>

<h2>5. App icon</h2>
<div class="icons">
<figure><img src="{icon}" width="180" height="180" alt=""><figcaption>App icon: layered glass hexagon, beta and key on the Omnissa gradient tile</figcaption></figure>
<figure><img src="icons/v1-layered-white-1024.png" width="120" height="120" alt=""><figcaption>Alternate: white tile, gradient mark</figcaption></figure>
<figure><img src="icons/v1-layered-omnissa-64.png" width="64" height="64" alt=""><figcaption>64 px</figcaption></figure>
<figure><img src="icons/v1-layered-omnissa-64.png" width="32" height="32" alt=""><figcaption>32 px</figcaption></figure>
</div>
<p class="muted">Variants and tile styles: <code>logo-d-beta.html</code>.</p>

<h2>6. Rules</h2>
<div class="dd"><div class="glass"><h3>Do</h3><ul class="do"><li>Use the Omnissa gradient for the header band and the icon tile.</li><li>Use Outfit Light for body, Medium for titles and buttons.</li><li>Use dynamic light and dark pairs from the palette.</li><li>Keep a frosted glass surface over a soft indigo and magenta backdrop.</li></ul></div>
<div class="glass"><h3>Do not</h3><ul class="dont"><li>Use magenta as a default accent. It is for negative data and the gradient end.</li><li>Fix a light background and rely on default text color, which turns white in dark mode.</li><li>Use Apple's logo, or copy an existing Omnissa product mark, without brand approval.</li><li>Put tokens, tenant names or session data in screenshots.</li></ul></div></div>

<h2>7. Sources and status</h2>
<div class="callout"><b style="font-weight:500">Sources.</b> Palette and font: HubControl <code>brand.rs</code> and <code>docs/REUSE.md</code>. Gradient: Omnissa PowerPoint toolkit theme. <br>
<b style="font-weight:500">Not verified.</b> The formal Omnissa brand guidelines were not read, no official logo was available, and the Liquid Glass look uses a material fallback unless built with Swift 6.2 or newer on macOS 26. This page is a working template, not an approved brand asset.</div>
</main></body></html>"""
    OUT.write_text(html, encoding="utf-8")
    print(f"wrote {OUT} ({OUT.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
