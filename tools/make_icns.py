#!/usr/bin/env python3
"""Pack an .iconset folder into an .icns file (PNG chunks), without iconutil.

Usage: python3 tools/make_icns.py assets/AppIcon.iconset assets/AppIcon.icns
Same result as `iconutil -c icns`; useful where iconutil cannot run.
"""

from __future__ import annotations

import struct
import sys
from pathlib import Path

# iconset file name -> ICNS chunk type (PNG payload)
CHUNKS = [
    ("icon_16x16.png", b"icp4"),
    ("icon_16x16@2x.png", b"ic11"),
    ("icon_32x32.png", b"icp5"),
    ("icon_32x32@2x.png", b"ic12"),
    ("icon_128x128.png", b"ic07"),
    ("icon_128x128@2x.png", b"ic13"),
    ("icon_256x256.png", b"ic08"),
    ("icon_256x256@2x.png", b"ic14"),
    ("icon_512x512.png", b"ic09"),
    ("icon_512x512@2x.png", b"ic10"),
]
PNG_MAGIC = b"\x89PNG\r\n\x1a\n"


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    src, out = Path(sys.argv[1]), Path(sys.argv[2])
    body = b""
    for name, kind in CHUNKS:
        f = src / name
        if not f.is_file():
            print(f"[ERROR] missing {f}", file=sys.stderr)
            return 1
        data = f.read_bytes()
        if not data.startswith(PNG_MAGIC):
            print(f"[ERROR] {f} is not a PNG", file=sys.stderr)
            return 1
        body += kind + struct.pack(">I", len(data) + 8) + data
    out.write_bytes(b"icns" + struct.pack(">I", len(body) + 8) + body)
    print(f"wrote {out} ({out.stat().st_size} bytes, {len(CHUNKS)} sizes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
