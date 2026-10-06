#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
APP="${1:-$PWD/.build/Coldkey.app}"
ICONSET="$PWD/.build/Coldkey.iconset"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$ICONSET"
cp "$BIN_DIR/Coldkey" "$APP/Contents/MacOS/Coldkey"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" Assets/hotkey-original.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    sips -z "$((size * 2))" "$((size * 2))" Assets/hotkey-original.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil --convert icns --output "$APP/Contents/Resources/Coldkey.icns" "$ICONSET"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Coldkey</string>
<key>CFBundleIdentifier</key><string>com.evanvonessen.coldkey</string>
<key>CFBundleName</key><string>Coldkey</string>
<key>CFBundleIconFile</key><string>Coldkey.icns</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSAppleEventsUsageDescription</key><string>Coldkey controls Finder to open your selected folder or close only a matching folder window when you press its shortcut.</string>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
printf '%s\n' "$APP"
