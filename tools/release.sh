#!/usr/bin/env bash
# Build everything customers get into dist/release/ with SHA-256 checksums.
#
#   tools/release.sh                       # full build (needs Swift tools for the app)
#   SKIP_APP_BUILD=1 tools/release.sh      # reuse the existing dist/*.app
#   SKIP_PY_TESTS=1 tools/release.sh       # skip Python unit tests
#   SIGN_IDENTITY="Developer ID Application: ..." tools/release.sh   # passed to make_app.sh
#
# Outputs (dist/release/):
#   Omnissa-Beta-Token-Utility-<ver>-macos.zip   the SwiftUI app
#   omnissa-beta-tokens-<ver>-macos-arm64        primary CLI (Rust release binary; required)
#   omnissa-beta-tokens-<ver>.py                 legacy single-file Python script
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
RUST_BIN="$ROOT/rust/target/release/omnissa-beta-tokens"
mkdir -p "$REL"
rm -f "$REL"/*

step() { printf '\n== %s\n' "$*"; }

if [[ -z "${SKIP_PY_TESTS:-}" ]]; then
  step "Tests (Python)"
  PYTHONPATH=src python3 -m unittest discover -s tests 2>&1 | tail -3
else
  step "Tests (Python) [skipped]"
fi

step "Rust CLI (primary)"
if ! command -v cargo >/dev/null 2>&1; then
  echo "error: cargo not found; install Rust toolchain to build the primary CLI" >&2
  exit 1
fi
(cd "$ROOT/rust" && cargo build --release)
if [[ ! -f "$RUST_BIN" ]]; then
  echo "error: expected release binary missing: $RUST_BIN" >&2
  exit 1
fi
cp "$RUST_BIN" "$REL/omnissa-beta-tokens-$VERSION-macos-arm64"
chmod +x "$REL/omnissa-beta-tokens-$VERSION-macos-arm64"
echo "built omnissa-beta-tokens-$VERSION-macos-arm64"

step "Single-file script (legacy)"
python3 tools/bundle.py
cp dist/omnissa-beta-tokens.py "$REL/omnissa-beta-tokens-$VERSION.py"

step "Guide"
python3 tools/build_guide.py
cp dist/omnissa-beta-guide.html "$REL/omnissa-beta-guide-$VERSION.html"

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
