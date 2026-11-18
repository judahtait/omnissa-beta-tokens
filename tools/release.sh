#!/usr/bin/env bash
# Build customer artifacts into dist/release/ with SHA-256 checksums.
#
#   tools/release.sh                       # Rust CLI + Rust GUI app + guide + checksums
#   SKIP_APP_BUILD=1 tools/release.sh      # reuse the existing dist/*.app
#   SIGN_IDENTITY="Developer ID Application: ..." tools/release.sh   # passed to make_app.sh
#
# Outputs (dist/release/):
#   Omnissa-Beta-Token-Utility-<ver>-macos.zip   Rust egui .app
#   omnissa-beta-tokens-<ver>-macos-arm64        Rust CLI (required)
#   omnissa-beta-guide-<ver>.html                branded guide (best-effort)
#   SHA256SUMS
#
# Guide is built with Rust (`cargo run --release --bin build-guide`).
#
# Builds are ad-hoc signed unless SIGN_IDENTITY is set; notarization is a separate step (README).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
VERSION="$(sed -n 's/^version = "\([^"]*\)"/\1/p' rust/Cargo.toml | head -n1)"
[[ -n "$VERSION" ]] || { echo "error: could not read version from rust/Cargo.toml" >&2; exit 1; }
REL="$ROOT/dist/release"
APP="$ROOT/dist/Omnissa Beta Token Utility.app"
RUST_CLI="$ROOT/rust/target/release/omnissa-beta-tokens"
mkdir -p "$REL"
rm -f "$REL"/*

step() { printf '\n== %s\n' "$*"; }

step "Rust CLI"
if ! command -v cargo >/dev/null 2>&1; then
  echo "error: cargo not found; install Rust toolchain to build the CLI" >&2
  exit 1
fi
cargo build --release --manifest-path "$ROOT/rust/Cargo.toml" --bin omnissa-beta-tokens
if [[ ! -x "$RUST_CLI" ]]; then
  echo "error: expected release binary missing: $RUST_CLI" >&2
  exit 1
fi
cp "$RUST_CLI" "$REL/omnissa-beta-tokens-$VERSION-macos-arm64"
chmod +x "$REL/omnissa-beta-tokens-$VERSION-macos-arm64"
echo "built omnissa-beta-tokens-$VERSION-macos-arm64"

step "Guide"
GUIDE_OUT="$REL/omnissa-beta-guide-$VERSION.html"
cargo run --release --manifest-path "$ROOT/rust/Cargo.toml" --bin build-guide
if [[ ! -f "$ROOT/dist/omnissa-beta-guide.html" ]]; then
  echo "error: build-guide did not write dist/omnissa-beta-guide.html" >&2
  exit 1
fi
cp "$ROOT/dist/omnissa-beta-guide.html" "$GUIDE_OUT"
echo "built omnissa-beta-guide-$VERSION.html"

step "Rust GUI app"
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
