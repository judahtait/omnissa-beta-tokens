#!/usr/bin/env bash
# Build "Omnissa Beta Token Utility.app" from the SwiftUI package.
#
#   tools/make_app.sh                      # swift build -c release, ad-hoc signed
#   SIGN_IDENTITY="Developer ID Application: ..." tools/make_app.sh
#   BIN=/path/to/binary OUT=/path/to/App.app tools/make_app.sh   # skip the build
#
# Notarization is NOT automated here. After signing with a Developer ID, run
# `xcrun notarytool submit` and `xcrun stapler staple` (see README).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(sed -n 's/^__version__ = "\(.*\)"/\1/p' "$ROOT/src/omnissa_beta_tokens/__init__.py")"
OUT="${OUT:-$ROOT/dist/Omnissa Beta Token Utility.app}"
IDENTITY="${SIGN_IDENTITY:--}"

if [[ -z "${BIN:-}" ]]; then
  (cd "$ROOT/swift" && swift build -c release --product OmnissaBetaTokens)
  BIN="$(cd "$ROOT/swift" && swift build -c release --show-bin-path)/OmnissaBetaTokens"
fi
[[ -x "$BIN" ]] || { echo "[ERROR] binary not found: $BIN" >&2; exit 1; }

rm -rf "$OUT"
mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources"
cp "$BIN" "$OUT/Contents/MacOS/OmnissaBetaTokens"

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
  <key>CFBundleExecutable</key><string>OmnissaBetaTokens</string>
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
echo "built: $OUT (signing identity: ${IDENTITY/#-/ad-hoc})"
