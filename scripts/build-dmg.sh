#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

OUTPUT="${1:-$PWD/dist/Coldkey.dmg}"
mkdir -p "$PWD/.build" "$(dirname "$OUTPUT")"
STAGING="$(mktemp -d "$PWD/.build/dmg.XXXXXX")"
cleanup() { rm -rf -- "$STAGING"; }
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

CONTENTS="$STAGING/contents"
APP="$CONTENTS/Coldkey.app"
COLDKEY_UNIVERSAL=1 ./scripts/build-app.sh "$APP"
for ARCH in arm64 x86_64; do
    lipo "$APP/Contents/MacOS/Coldkey" -verify_arch "$ARCH"
done
codesign --verify --strict --all-architectures "$APP"
ln -s /Applications "$CONTENTS/Applications"
cat > "$CONTENTS/Read Me.txt" <<'README'
Coldkey — macOS 13 or later (Apple Silicon and Intel)

Install
1. Quit any running copy of Coldkey from its menu bar.
2. Drag Coldkey.app onto Applications.
3. Eject this disk and open Coldkey from Applications.
4. Look for the ⌘ icon in your menu bar. Coldkey has no Dock icon.

Your existing shortcuts are kept when replacing an older copy.
Use Settings… in the ⌘ menu to enable Start at login if desired.

This build is ad-hoc signed and is not notarized. If macOS blocks it,
try opening Coldkey once, then use System Settings → Privacy & Security
→ Open Anyway and confirm opening it.

The app uses the original HotKey by codenuts logo requested for Coldkey.
Source: https://hotkey.macupdate.com/
Coldkey source and build instructions: https://github.com/evanvonessen/coldkey
README

hdiutil create -volname Coldkey -srcfolder "$CONTENTS" -fs HFS+ \
    -format UDZO "$STAGING/Coldkey.dmg"
hdiutil verify "$STAGING/Coldkey.dmg"
mv -f -- "$STAGING/Coldkey.dmg" "$OUTPUT"
(
    cd "$(dirname "$OUTPUT")"
    shasum -a 256 "$(basename "$OUTPUT")" > "$(basename "$OUTPUT").sha256"
)
printf 'DMG: %s\nSHA-256: %s.sha256\n' "$OUTPUT" "$OUTPUT"
