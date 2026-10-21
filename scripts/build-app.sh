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
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks" "$ICONSET"
cp "$BIN_DIR/Coldkey" "$APP/Contents/MacOS/Coldkey"
FRAMEWORK="$APP/Contents/Frameworks/Sparkle.framework"
SPARKLE="$PWD/.build/artifacts/sparkle/Sparkle"
rm -rf -- "$FRAMEWORK"
ditto "$SPARKLE/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework" "$FRAMEWORK"
# ColdKey isn't sandboxed, so these optional XPC services and development headers are unnecessary.
rm -rf -- "$FRAMEWORK/Versions/B/XPCServices" "$FRAMEWORK/Versions/B/Headers" \
    "$FRAMEWORK/Versions/B/PrivateHeaders" "$FRAMEWORK/Versions/B/Modules"
rm -f -- "$FRAMEWORK/Headers" "$FRAMEWORK/PrivateHeaders" "$FRAMEWORK/Modules"
cp "$SPARKLE/LICENSE" "$APP/Contents/Resources/Sparkle-LICENSE.txt"
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
<key>CFBundleShortVersionString</key><string>0.4.1</string>
<key>CFBundleVersion</key><string>6</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>SUFeedURL</key><string>https://raw.githubusercontent.com/evanvonessen/coldkey/main/updates/appcast.xml</string>
<key>SUEnableAutomaticChecks</key><true/>
<key>SUScheduledCheckInterval</key><integer>86400</integer>
<key>SUAutomaticallyUpdate</key><false/>
<key>SUAllowsAutomaticUpdates</key><false/>
<key>SUEnableSystemProfiling</key><false/>
<key>SUShowReleaseNotes</key><false/>
<key>SUVerifyUpdateBeforeExtraction</key><true/>
<key>SURequireSignedFeed</key><true/>
<key>NSAppleEventsUsageDescription</key><string>ColdKey controls Finder to open your selected folder or close only a matching folder window when you press its shortcut.</string>
</dict></plist>
PLIST
plutil -insert SUPublicEDKey -string "$(cat scripts/update-public-key.txt)" "$APP/Contents/Info.plist"
SIGNING_IDENTITY="${COLDKEY_SIGNING_IDENTITY:--}"
SIGN_ARGS=(--force --sign "$SIGNING_IDENTITY")
if [[ "$SIGNING_IDENTITY" != "-" ]]; then
    SIGN_ARGS+=(--options runtime --timestamp)
fi
codesign "${SIGN_ARGS[@]}" "$FRAMEWORK/Versions/B/Autoupdate"
codesign "${SIGN_ARGS[@]}" "$FRAMEWORK/Versions/B/Updater.app"
codesign "${SIGN_ARGS[@]}" "$FRAMEWORK"
codesign "${SIGN_ARGS[@]}" --entitlements "$PWD/scripts/ColdKey.entitlements" "$APP"
codesign --verify --deep --strict --all-architectures "$APP"
printf '%s\n' "$APP"
