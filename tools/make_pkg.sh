#!/usr/bin/env bash
# Build an Installer package that drops the SwiftUI app into /Applications.
#
#   tools/make_pkg.sh
#   SKIP_APP_BUILD=1 tools/make_pkg.sh
#   INSTALLER_IDENTITY="Developer ID Installer: ..." tools/make_pkg.sh
#
# Output: dist/release/Omnissa-Beta-Token-Utility-<ver>-macos.pkg
#
# Unsigned / ad-hoc pkgs are fine for local testing (Installer may warn; use
# right-click → Open, or: sudo installer -pkg … -target /).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
VERSION="$(sed -n 's/^version = "\([^"]*\)"/\1/p' rust/Cargo.toml | head -n1)"
[[ -n "$VERSION" ]] || { echo "error: could not read version from rust/Cargo.toml" >&2; exit 1; }

APP="$ROOT/dist/Omnissa Beta Token Utility.app"
REL="$ROOT/dist/release"
PKG_ID="com.omnissa.betatokenutility"
PKG_OUT="$REL/Omnissa-Beta-Token-Utility-$VERSION-macos.pkg"
STAGE="$ROOT/dist/pkgroot"
IDENTITY="${INSTALLER_IDENTITY:--}"

if [[ -z "${SKIP_APP_BUILD:-}" ]]; then
  tools/make_app.sh
fi
[[ -d "$APP" ]] || { echo "error: missing app: $APP (run tools/make_app.sh)" >&2; exit 1; }

# Ensure current AppIcon lands in the payload (make_app can reuse a stale copy).
export COPYFILE_DISABLE=1
if [[ -f "$ROOT/assets/AppIcon.icns" ]]; then
  cp "$ROOT/assets/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi
# Source .app may already contain real `._*` files from earlier copies — strip them.
find "$APP" -name '._*' -delete
xattr -cr "$APP" 2>/dev/null || true
codesign --force --sign - "$APP" >/dev/null

rm -rf "$STAGE"
mkdir -p "$STAGE" "$REL"
# Prefer rsync so we never reintroduce AppleDouble sidecars.
rsync -a --delete --exclude '._*' --exclude '.DS_Store' \
  "$APP/" "$STAGE/Omnissa Beta Token Utility.app/"
find "$STAGE" -name '._*' -delete
xattr -cr "$STAGE" 2>/dev/null || true
# Re-sign after stripping attrs so codesign still verifies at install time.
codesign --force --sign - "$STAGE/Omnissa Beta Token Utility.app" >/dev/null
# Final check — fail the build if AppleDouble slipped through.
if find "$STAGE" -name '._*' | grep -q .; then
  echo "error: AppleDouble files still present in pkg stage:" >&2
  find "$STAGE" -name '._*' >&2
  exit 1
fi

PKGBUILD_ARGS=(
  --root "$STAGE"
  --install-location "/Applications"
  --identifier "$PKG_ID"
  --version "$VERSION"
  --ownership recommended
)
if [[ "$IDENTITY" != "-" ]]; then
  PKGBUILD_ARGS+=(--sign "$IDENTITY")
fi

pkgbuild "${PKGBUILD_ARGS[@]}" "$PKG_OUT"
rm -rf "$STAGE"

echo "built: $PKG_OUT"
pkgutil --payload-files "$PKG_OUT" | head -20
ls -lh "$PKG_OUT"
