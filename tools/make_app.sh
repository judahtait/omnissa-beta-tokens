#!/usr/bin/env bash
# Build "Omnissa Beta Token Utility.app" from the Rust egui GUI binary.
#
#   tools/make_app.sh                      # cargo build --release --bin omnissa-beta-tokens-app
#   SIGN_IDENTITY="Developer ID Application: ..." tools/make_app.sh
#   BIN=/path/to/binary OUT=/path/to/App.app tools/make_app.sh   # skip the build
#
# Bundle executable stays OmnissaBetaTokens for continuity with prior .app installs;
# CFBundleExecutable matches that name. Source binary is omnissa-beta-tokens-app.
#
# Notarization is NOT automated here. After signing with a Developer ID, run
# `xcrun notarytool submit` and `xcrun stapler staple` (see README).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(sed -n 's/^version = "\([^"]*\)"/\1/p' "$ROOT/rust/Cargo.toml" | head -n1)"
[[ -n "$VERSION" ]] || { echo "[ERROR] could not read version from rust/Cargo.toml" >&2; exit 1; }
OUT="${OUT:-$ROOT/dist/Omnissa Beta Token Utility.app}"
IDENTITY="${SIGN_IDENTITY:--}"
# Name inside Contents/MacOS (and Info.plist CFBundleExecutable).
BUNDLE_EXEC="OmnissaBetaTokens"

if [[ -z "${BIN:-}" ]]; then
  if ! command -v cargo >/dev/null 2>&1; then
    echo "[ERROR] cargo not found; install Rust toolchain to build the app" >&2
    exit 1
  fi
  cargo build --release --manifest-path "$ROOT/rust/Cargo.toml" --bin omnissa-beta-tokens-app
  BIN="$ROOT/rust/target/release/omnissa-beta-tokens-app"
fi
[[ -x "$BIN" ]] || { echo "[ERROR] binary not found: $BIN" >&2; exit 1; }

rm -rf "$OUT"
mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources"
cp "$BIN" "$OUT/Contents/MacOS/$BUNDLE_EXEC"

# Outfit Light/Medium (SIL OFL 1.1) with their licence; the app registers them at launch.
mkdir -p "$OUT/Contents/Resources/Fonts"
cp "$ROOT"/assets/fonts/*.ttf "$ROOT"/assets/fonts/OFL.txt "$OUT/Contents/Resources/Fonts/"
# App icon, if one has been generated (see docs/branding/).
if [[ -f "$ROOT/assets/AppIcon.icns" ]]; then
  cp "$ROOT/assets/AppIcon.icns" "$OUT/Contents/Resources/AppIcon.icns"
  ICON_KEY='<key>CFBundleIconFile</key><string>AppIcon</string>'
else
  ICON_KEY=''
fi

cat > "$OUT/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Omnissa Beta Token Utility</string>
  <key>CFBundleDisplayName</key><string>Omnissa Beta Token Utility</string>
  <key>CFBundleIdentifier</key><string>com.omnissa.betatokenutility</string>
  <key>CFBundleExecutable</key><string>${BUNDLE_EXEC}</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  ${ICON_KEY}
</dict>
</plist>
PLIST

if [[ "$IDENTITY" == "-" ]]; then
  codesign --force --sign - "$OUT"
else
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$OUT"
fi
codesign --verify --verbose=2 "$OUT"
echo "built: $OUT (signing identity: ${IDENTITY/#-/ad-hoc}; version $VERSION; exec $BUNDLE_EXEC)"
