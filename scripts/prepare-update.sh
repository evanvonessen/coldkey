#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${1:?Usage: scripts/prepare-update.sh version}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { printf 'Use a version such as 0.3.0.\n' >&2; exit 2; }
DMG="$PWD/dist/ColdKey.dmg"
TOOLS="$PWD/.build/artifacts/sparkle/Sparkle/bin"
ACCOUNT="com.evanvonessen.coldkey"
STAGING="$PWD/.build/update-v$VERSION"
[[ -x "$TOOLS/generate_appcast" ]] || { printf 'Build ColdKey first to download the pinned Sparkle tools.\n' >&2; exit 1; }
# Only an approved installer may enter the update feed. Private signing material stays in Keychain.
codesign --verify --strict "$DMG"
xcrun stapler validate "$DMG"
spctl --assess --type open --context context:primary-signature "$DMG"
[[ "$("$TOOLS/generate_keys" --account "$ACCOUNT" -p)" == "$(cat scripts/update-public-key.txt)" ]] || {
    printf 'The update signing key does not match ColdKey.\n' >&2; exit 1;
}
mkdir -p "$STAGING" updates
cp "$DMG" "$STAGING/ColdKey-$VERSION.dmg"
if [[ -f updates/appcast.xml ]]; then cp updates/appcast.xml "$STAGING/appcast.xml"; fi
(
    cd "$STAGING"
    shasum -a 256 "ColdKey-$VERSION.dmg" > "ColdKey-$VERSION.dmg.sha256"
)
"$TOOLS/generate_appcast" --account "$ACCOUNT" --maximum-deltas 0 \
    --download-url-prefix "https://github.com/evanvonessen/coldkey/releases/download/v$VERSION/" \
    --link "https://github.com/evanvonessen/coldkey" -o "$STAGING/appcast.xml" "$STAGING"
python3 - "$STAGING/appcast.xml" "$VERSION" <<'PY'
import sys
import xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
version = root.findtext('./channel/item/{http://www.andymatuschak.org/xml-namespaces/sparkle}shortVersionString')
if version != sys.argv[2]:
    raise SystemExit('The packaged app version does not match the requested release version.')
PY
"$TOOLS/sign_update" --account "$ACCOUNT" --verify "$STAGING/appcast.xml"
cp "$STAGING/appcast.xml" updates/appcast.xml.tmp
mv updates/appcast.xml.tmp updates/appcast.xml
printf 'Prepared signed feed: updates/appcast.xml\nRelease asset: %s/ColdKey-%s.dmg\n' "$STAGING" "$VERSION"
