#!/usr/bin/env python3
"""Build the branded Omnissa guide (single HTML file) from docs/guide.md.
Adapted from the Omnissa tech-validation-doc build script (not an official template).
Usage: python3 tools/build_guide.py [input.md] [output.html] [--script path.py]
The marker <!-- UTILITY_DOWNLOAD --> in the Markdown is replaced with a download
block that embeds the single-file utility (offline, no hosting needed).
Requires: pip install markdown"""
import base64, hashlib, html as htmllib, re, sys, markdown
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

CSS = """
:root{--navy:#001E60;--indigo:#4A12F0;--text:#28334A;--slate:#4C6190;--tint:#C8C4E2;--bg:#F6F5FB;--teal:#04736C;--magenta:#D600FF}
*{box-sizing:border-box}
body{margin:0;background:#fff;color:var(--text);font-family:'Outfit','Outfit Light',system-ui,-apple-system,Segoe UI,sans-serif;font-weight:300;font-size:16px;line-height:1.6}
header{background:linear-gradient(100deg,var(--navy),var(--indigo),var(--magenta));color:#fff;padding:48px 16px 40px}
.wrap{max-width:900px;margin:0 auto;padding:0 16px}
header .wrap{padding:0}
.eyebrow{font-weight:500;letter-spacing:.12em;text-transform:uppercase;font-size:13px;opacity:.9}
h1{font-weight:500;font-size:34px;line-height:1.2;margin:10px 0 16px;color:#fff}
.meta{font-size:14px;opacity:.95}.meta span{margin-right:20px;display:inline-block}
.draft{background:var(--bg);border-left:4px solid var(--indigo);padding:12px 16px;margin:28px 0 8px;font-size:14px}
.claim{background:var(--bg);padding:14px 16px;border-radius:6px;font-size:15px;margin:8px 0}
h2{font-weight:500;color:var(--navy);font-size:24px;margin:40px 0 8px;padding-bottom:6px;border-bottom:2px solid var(--tint)}
h3{font-weight:500;color:var(--indigo);font-size:18px;margin:26px 0 4px}
strong{font-weight:500;color:var(--navy)}a{color:var(--indigo)}
code{font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;font-size:.88em;background:var(--bg);color:var(--navy);padding:1px 5px;border-radius:4px;word-break:break-word}
table{border-collapse:collapse;width:100%;margin:14px 0;font-size:15px;display:block;overflow-x:auto}
th{background:var(--navy);color:#fff;font-weight:500;text-align:left;padding:8px 12px}
td{padding:8px 12px;border-bottom:1px solid var(--tint);vertical-align:top}
tr:nth-child(even) td{background:var(--bg)}li{margin:4px 0}
footer{border-top:2px solid var(--tint);margin-top:48px;padding:20px 0 40px;font-size:13px;color:var(--slate)}
.btn{display:inline-block;background:var(--indigo);color:#fff!important;font-weight:500;text-decoration:none;padding:10px 18px;border-radius:999px;border:0;cursor:pointer;font-family:inherit;font-size:15px}
.btn2{background:#fff;color:var(--indigo);border:1px solid var(--indigo);border-radius:999px;padding:6px 14px;font-family:inherit;font-size:14px;cursor:pointer;margin:8px 0}
.download{background:var(--bg);border-left:4px solid var(--indigo);padding:16px;margin:16px 0;border-radius:6px}
details summary{cursor:pointer;color:var(--indigo);font-weight:500;margin-top:8px}
pre{background:#fff;border:1px solid var(--tint);border-radius:6px;padding:12px;overflow:auto;max-height:480px;font-size:12.5px;line-height:1.45}
pre code{background:none;padding:0}
@media print{header,th,tr:nth-child(even) td{-webkit-print-color-adjust:exact;print-color-adjust:exact}h2{break-after:avoid}table,li{break-inside:avoid}}
"""

def esc(t):
    t = re.sub(r'`([^`]+)`', lambda m: '<code>' + m.group(1).replace('&','&amp;').replace('<','&lt;').replace('>','&gt;') + '</code>', t)
    return re.sub(r'\*\*([^*]+)\*\*', r'<strong>\1</strong>', t)

def field(meta, name):
    m = re.search(r'\*\*%s:\*\* (.*)' % name, meta)
    return m.group(1) if m else ''

def has_timeline_table(md):
    """True if a '## ...Timeline...' heading is followed by a Markdown table before the next '## ' heading."""
    for sec in re.split(r'(?m)^## ', md)[1:]:
        head, _, rest = sec.partition('\n')
        if re.search(r'timeline', head, re.I) and re.search(r'(?m)^\|.*\|\s*\n\|[\s:|-]+\|', rest):
            return True
    return False

def utility_block(script: Path) -> str:
    raw = script.read_bytes()
    sha = hashlib.sha256(raw).hexdigest()
    b64 = base64.b64encode(raw).decode()
    ver = re.search(r'__version__ = "([^"]+)"', raw.decode()).group(1)
    src = htmllib.escape(raw.decode())
    lines = raw.count(b"\n")
    return f'''<div class="download">
<a class="btn" download="omnissa-beta-tokens.py" href="data:text/x-python;base64,{b64}">Download omnissa-beta-tokens.py</a>
<p>Version {ver} &middot; {lines} lines &middot; Python 3.9+ and system <code>openssl</code>, no other dependencies.<br>
SHA-256: <code>{sha}</code></p>
<p>Verify after download: <code>shasum -a 256 omnissa-beta-tokens.py</code></p>
<details><summary>View or copy the full source</summary>
<button class="btn2" type="button" onclick="var b=this;navigator.clipboard.writeText(document.getElementById('util-src').innerText).then(function(){{b.textContent='Copied'}})">Copy script</button>
<pre id="util-src"><code>{src}</code></pre></details>
</div>'''


def main():
    argv = sys.argv[1:]
    script = ROOT / 'dist' / 'omnissa-beta-tokens.py'
    if '--script' in argv:
        i = argv.index('--script'); script = Path(argv[i + 1]); del argv[i:i + 2]
    args = [a for a in argv if not a.startswith('--')]
    src = args[0] if args else str(ROOT / 'docs' / 'guide.md')
    out = args[1] if len(args) > 1 else str(ROOT / 'dist' / 'omnissa-beta-guide.html')
    s = open(src, encoding='utf-8').read()
    meta, body_md = s.split('\n---\n', 1)
    title = re.search(r'^# (.*)$', meta, re.M).group(1)
    body = markdown.markdown(body_md, extensions=['tables', 'sane_lists'])
    status, date, author, claim = (field(meta, k) for k in ('Status', 'Date', 'Author', 'Ticket claim'))
    if not script.is_file():
        sys.exit(f'ERROR: {script} not found. Run python3 tools/bundle.py first.')
    body = body.replace('<!-- UTILITY_DOWNLOAD -->', utility_block(script))
    draft_html = '<div class="draft"><strong>Draft only.</strong> %s</div>' % status.replace("Draft only. ", "") if status.startswith("Draft only") else ''
    claim_html = '<div class="claim"><strong>Ticket claim:</strong> %s</div>' % esc(claim) if claim else ''
    html = f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{title}</title>
<link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;500&display=swap" rel="stylesheet">
<style>{CSS}</style></head><body>
<header><div class="wrap"><div class="eyebrow">Omnissa &middot; Workspace ONE UEM &middot; Guide</div>
<h1>{title}</h1>
<div class="meta"><span>{date}</span><span>{author}</span></div></div></header>
<main class="wrap">
{draft_html}
{claim_html}
{body}
<footer>Omnissa &middot; Draft for review. Do not share tokens, server tokens (.p7m) or private keys.</footer>
</main></body></html>'''
    Path(out).parent.mkdir(parents=True, exist_ok=True)
    open(out, 'w', encoding='utf-8').write(html)
    print('wrote', out)

if __name__ == '__main__':
    main()
