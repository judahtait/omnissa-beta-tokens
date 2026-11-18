#!/usr/bin/env bash
# Build everything customers get into dist/release/ with SHA-256 checksums.
#
#   tools/release.sh                       # full build (needs Swift tools for the app)
#   SKIP_APP_BUILD=1 tools/release.sh      # reuse the existing dist/*.app
#   PYI_PYTHON=/path/to/python tools/release.sh   # python that has PyInstaller installed
#   SIGN_IDENTITY="Developer ID Application: ..." tools/release.sh   # passed to make_app.sh
#
# Outputs (dist/release/):
#   Omnissa-Beta-Token-Utility-<ver>-macos.zip   the SwiftUI app
#   omnissa-beta-tokens-<ver>-arm64              single-file arm64 binary (if PyInstaller is available)
#   omnissa-beta-tokens-<ver>.py                 single-file script
#   omnissa-beta-guide-<ver>.html                branded guide (embeds the script)
#   SHA256SUMS
#
# Builds are ad-hoc signed unless SIGN_IDENTITY is set; notarization is a separate step (README).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
VERSION="$(sed -n 's/^__version__ = "\(.*\)"/\1/p' src/omnissa_beta_tokens/__init__.py)"
REL="$ROOT/dist/release"
APP="$ROOT/dist/Omnissa Beta Token Utility.app"
mkdir -p "$REL"
rm -f "$REL"/*

step() { printf '\n== %s\n' "$*"; }

step "Tests (Python)"
PYTHONPATH=src python3 -m unittest discover -s tests 2>&1 | tail -3

step "Single-file script"
python3 tools/bundle.py
cp dist/omnissa-beta-tokens.py "$REL/omnissa-beta-tokens-$VERSION.py"

step "Guide"
python3 tools/build_guide.py
cp dist/omnissa-beta-guide.html "$REL/omnissa-beta-guide-$VERSION.html"

step "arm64 binary (PyInstaller)"
PYI="${PYI_PYTHON:-python3}"
if "$PYI" -m PyInstaller --version >/dev/null 2>&1; then
  WORK="$(mktemp -d "${TMPDIR:-/tmp}/obt-pyi.XXXXXX")"
  "$PYI" -m PyInstaller --onefile --clean --noconfirm --name omnissa-beta-tokens \
    --distpath "$ROOT/dist/bin" --workpath "$WORK/build" --specpath "$WORK/spec" \
    dist/omnissa-beta-tokens.py >/dev/null 2>&1
  cp dist/bin/omnissa-beta-tokens "$REL/omnissa-beta-tokens-$VERSION-arm64"
  echo "built dist/bin/omnissa-beta-tokens"
else
  echo "[skip] PyInstaller not found for '$PYI' (set PYI_PYTHON to a python with PyInstaller installed)"
fi

step "SwiftUI app"
if [[ -z "${SKIP_APP_BUILD:-}" ]]; then
  tools/make_app.sh
fi
if [[ -d "$APP" ]]; then
  ditto -c -k --keepParent "$APP" "$REL/Omnissa-Beta-Token-Utility-$VERSION-macos.zip"
  echo "zipped $(basename "$APP")"
else
  echo "[skip] $APP not found; run tools/make_app.sh first"
fi

step "Checksums"
(cd "$REL" && shasum -a 256 -- * | grep -v SHA256SUMS > SHA256SUMS && cat SHA256SUMS)

step "Release $VERSION"
ls -lh "$REL"
