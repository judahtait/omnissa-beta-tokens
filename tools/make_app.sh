#!/usr/bin/env bash
# Build "Omnissa Beta Token Utility.app" from the SwiftUI package.
#
# Callers: tools/release.sh, docs/RELEASING.md, operators.
# Version from rust/Cargo.toml; binary from swift build → Contents/MacOS/OmnissaBetaTokens.
#
#   tools/make_app.sh
#   SIGN_IDENTITY="Developer ID Application: ..." tools/make_app.sh
#   BIN=/path/to/binary OUT=/path/to/App.app tools/make_app.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(sed -n 's/^version = "\([^"]*\)"/\1/p' "$ROOT/rust/Cargo.toml" | head -n1)"
[[ -n "$VERSION" ]] || { echo "[ERROR] could not read version from rust/Cargo.toml" >&2; exit 1; }
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

mkdir -p "$OUT/Contents/Resources/Fonts"
cp "$ROOT"/assets/fonts/*.ttf "$ROOT"/assets/fonts/OFL.txt "$OUT/Contents/Resources/Fonts/"
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
  <key>NSAppleEventsUsageDescription</key>
  <string>Omnissa Beta Token Utility places Apple Business beside this window so you can upload the certificate.</string>
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
echo "built: $OUT (signing identity: ${IDENTITY/#-/ad-hoc}; version $VERSION; SwiftUI shell)"
