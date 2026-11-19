#!/usr/bin/env bash
# Build the macOS Installer package and install Omnissa Beta Token Utility
# into /Applications.
#
# Usage (from a clone):
#   tools/install.sh
#
# Usage (one-liner, once this file is on the default branch):
#   curl -fsSL https://raw.githubusercontent.com/jtait_euc/omnissa-beta-tokens/main/tools/install.sh | bash
#
# Prefer Homebrew when a GitHub release exists:
#   brew tap jtait_euc/omnissa-beta-tokens https://github.com/jtait_euc/omnissa-beta-tokens
#   brew install --cask omnissa-beta-token-utility
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/jtait_euc/omnissa-beta-tokens.git}"
APP_NAME="Omnissa Beta Token Utility.app"
APP_DEST="/Applications/${APP_NAME}"

if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
else
  # Piped from curl — clone a shallow work tree, then install.
  WORK="$(mktemp -d "${TMPDIR:-/tmp}/omnissa-beta-tokens.XXXXXX")"
  trap 'rm -rf "$WORK"' EXIT
  echo "== Cloning ${REPO_URL}"
  git clone --depth 1 "$REPO_URL" "$WORK/src"
  ROOT="$WORK/src"
fi

cd "$ROOT"
VERSION="$(sed -n 's/^version = "\([^"]*\)"/\1/p' rust/Cargo.toml | head -n1)"
[[ -n "$VERSION" ]] || { echo "error: could not read version from rust/Cargo.toml" >&2; exit 1; }
PKG="$ROOT/dist/release/Omnissa-Beta-Token-Utility-${VERSION}-macos.pkg"

# Default to Judah Tait Developer ID when identities are present locally.
export SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application: Judah Tait (U4986YKSZ8)}"
export INSTALLER_IDENTITY="${INSTALLER_IDENTITY:-Developer ID Installer: Judah Tait (U4986YKSZ8)}"

echo "== Building installer (v${VERSION})"
if [[ ! -f "$PKG" ]]; then
  command -v cargo >/dev/null 2>&1 || {
    echo "error: Rust (cargo) is required to build from source. Install from https://rustup.rs" >&2
    exit 1
  }
  command -v swift >/dev/null 2>&1 || {
    echo "error: Swift toolchain required (Xcode or Command Line Tools)." >&2
    exit 1
  }
  tools/make_pkg.sh
fi
[[ -f "$PKG" ]] || { echo "error: missing package: $PKG" >&2; exit 1; }

echo "== Installing to /Applications (sudo)"
sudo installer -pkg "$PKG" -target /

if [[ -d "$APP_DEST" ]]; then
  echo "installed: $APP_DEST"
  codesign --verify --verbose=2 "$APP_DEST" 2>&1 | tail -5 || true
  open -R "$APP_DEST"
else
  echo "warning: installer finished but app not found at $APP_DEST" >&2
  exit 1
fi
