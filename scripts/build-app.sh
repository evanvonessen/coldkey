#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
BUILD_ARGS=(-c release)
if [[ "${COLDKEY_UNIVERSAL:-0}" == "1" ]]; then
    BUILD_ARGS+=(--arch arm64 --arch x86_64)
fi
swift build "${BUILD_ARGS[@]}"
BIN_DIR="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"
APP="${1:-$PWD/.build/ColdKey.app}"
ICONSET="$PWD/.build/ColdKey.iconset"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$ICONSET"
cp "$BIN_DIR/Coldkey" "$APP/Contents/MacOS/Coldkey"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" Assets/hotkey-original.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    sips -z "$((size * 2))" "$((size * 2))" Assets/hotkey-original.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil --convert icns --output "$APP/Contents/Resources/ColdKey.icns" "$ICONSET"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Coldkey</string>
<key>CFBundleIdentifier</key><string>com.evanvonessen.coldkey</string>
<key>CFBundleName</key><string>ColdKey</string>
<key>CFBundleDisplayName</key><string>ColdKey</string>
<key>CFBundleIconFile</key><string>ColdKey.icns</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>2</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSAppleEventsUsageDescription</key><string>ColdKey controls Finder to open your selected folder or close only a matching folder window when you press its shortcut.</string>
</dict></plist>
PLIST
SIGNING_IDENTITY="${COLDKEY_SIGNING_IDENTITY:--}"
SIGN_ARGS=(--force --sign "$SIGNING_IDENTITY" --options runtime --entitlements "$PWD/scripts/ColdKey.entitlements")
if [[ "$SIGNING_IDENTITY" != "-" ]]; then
    SIGN_ARGS+=(--timestamp)
fi
codesign "${SIGN_ARGS[@]}" "$APP"
printf '%s\n' "$APP"
