#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

OUTPUT="${1:-$PWD/dist/Coldkey.dmg}"
mkdir -p "$PWD/.build" "$(dirname "$OUTPUT")"
STAGING="$(mktemp -d "$PWD/.build/dmg.XXXXXX")"
VERIFY_MOUNT=""
cleanup() {
    if [[ -n "$VERIFY_MOUNT" ]]; then
        hdiutil detach "$VERIFY_MOUNT" || return
    fi
    rm -rf -- "$STAGING"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Packaging tools stay in the ignored build directory, outside the app bundle.
TOOLS="$PWD/.build/dmg-tools"
if [[ ! -x "$TOOLS/bin/python" ]]; then
    python3 -m venv "$TOOLS"
fi
if ! cmp -s scripts/requirements-dmg.txt "$TOOLS/requirements.txt"; then
    "$TOOLS/bin/python" -m pip install --disable-pip-version-check -r scripts/requirements-dmg.txt
    cp scripts/requirements-dmg.txt "$TOOLS/requirements.txt"
fi

CONTENTS="$STAGING/contents"
APP="$CONTENTS/Coldkey.app"
COLDKEY_UNIVERSAL=1 ./scripts/build-app.sh "$APP"
for ARCH in arm64 x86_64; do
    lipo "$APP/Contents/MacOS/Coldkey" -verify_arch "$ARCH"
done
codesign --verify --strict --all-architectures "$APP"

"$TOOLS/bin/python" -m dmgbuild -s scripts/dmg-settings.py -D "app=$APP" \
    Coldkey "$STAGING/Coldkey.dmg"
hdiutil verify "$STAGING/Coldkey.dmg"
mkdir "$STAGING/verify"
hdiutil attach -readonly -nobrowse -mountpoint "$STAGING/verify" "$STAGING/Coldkey.dmg" >/dev/null
VERIFY_MOUNT="$STAGING/verify"
codesign --verify --strict --all-architectures "$VERIFY_MOUNT/Coldkey.app"
hdiutil detach "$VERIFY_MOUNT"
VERIFY_MOUNT=""
mv -f -- "$STAGING/Coldkey.dmg" "$OUTPUT"
(
    cd "$(dirname "$OUTPUT")"
    shasum -a 256 "$(basename "$OUTPUT")" > "$(basename "$OUTPUT").sha256"
)
printf 'DMG: %s\nSHA-256: %s.sha256\n' "$OUTPUT" "$OUTPUT"
