#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

NOTARIZE=0
RESUME=0
case "${1:-}" in
    --notarize) NOTARIZE=1; shift ;;
    --resume) NOTARIZE=1; RESUME=1; shift ;;
    --help)
        printf 'Usage: %s [--notarize] [output.dmg]\n       %s --resume\n' "$0" "$0"
        printf 'Notarization requires a Developer ID Application identity and COLDKEY_NOTARY_PROFILE.\n'
        printf 'Pending submissions return exit 75; --resume checks the existing submission once.\n'
        exit 0 ;;
    --*) printf 'Unknown option: %s\n' "$1" >&2; exit 2 ;;
esac
[[ $# -le 1 ]] || { printf 'Expected at most one output path.\n' >&2; exit 2; }
[[ "$RESUME" == "0" || $# == 0 ]] || { printf '%s\n' '--resume uses its saved output path.' >&2; exit 2; }
mkdir -p "$PWD/.build"
STATE="$PWD/.build/ColdKey-notarization-state.json"
LOCK="$STATE.lock"
LOCK_HELD=0
VERIFY_MOUNT=""
KEEP_STAGING=0
STAGING=""
cleanup() {
    if [[ -n "$VERIFY_MOUNT" ]]; then
        hdiutil detach "$VERIFY_MOUNT" || true
    fi
    if [[ "$LOCK_HELD" == "1" ]]; then rm -rf -- "$LOCK"; fi
    if [[ -z "$STAGING" ]]; then
        return
    elif [[ "$KEEP_STAGING" == "1" ]]; then
        printf 'Release files and notarization results preserved at: %s\n' "$STAGING" >&2
    else
        rm -rf -- "$STAGING"
    fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

source_fingerprint() {
    python3 - <<'PY'
import hashlib
from pathlib import Path

paths = list(Path("Sources").rglob("*.swift")) + [Path(name) for name in (
    "Package.swift", "Package.resolved", "Assets/hotkey-original.png", "scripts/build-app.sh",
    "scripts/ColdKey.entitlements", "scripts/build-dmg.sh",
    "scripts/dmg-settings.py", "scripts/requirements-dmg.txt", "scripts/update-public-key.txt",
)]
digest = hashlib.sha256()
for path in sorted(paths):
    digest.update(str(path).encode() + b"\0" + path.read_bytes() + b"\0")
print(digest.hexdigest())
PY
}

if [[ "$NOTARIZE" == "1" ]]; then
    if ! mkdir "$LOCK" 2>/dev/null; then
        printf 'Another release run holds %s. Inspect it before retrying.\n' "$LOCK" >&2
        exit 1
    fi
    LOCK_HELD=1
    printf '%s\n' "$$" > "$LOCK/pid"
    if [[ "$RESUME" == "1" ]]; then
        [[ -f "$STATE" ]] || { printf 'No saved notarization state at %s.\n' "$STATE" >&2; exit 2; }
        STAGING="$(plutil -extract staging raw -o - "$STATE")"
        KEEP_STAGING=1
        OUTPUT="$(plutil -extract output raw -o - "$STATE")"
        export COLDKEY_NOTARY_PROFILE="$(plutil -extract keychainProfile raw -o - "$STATE")"
        export COLDKEY_SIGNING_IDENTITY="$(plutil -extract signingIdentity raw -o - "$STATE")"
        [[ -d "$STAGING" && -f "$STAGING/app-notarization.json" ]] || {
            printf 'Saved release files or submission receipt are missing.\n' >&2; exit 1;
        }
        if [[ "$(source_fingerprint)" != "$(plutil -extract sourceFingerprint raw -o - "$STATE")" ]]; then
            printf 'Release inputs changed since submission. Preserve this release and review before publishing.\n' >&2
            exit 1
        fi
        if [[ "$(shasum -a 256 "$STAGING/ColdKey.zip" | awk '{print $1}')" != "$(plutil -extract appArchiveSha256 raw -o - "$STATE")" ]]; then
            printf 'The submitted app archive changed. Refusing to resume.\n' >&2; exit 1
        fi
    elif [[ -f "$STATE" ]]; then
        printf 'A release is already saved at %s. Use --resume; do not submit it again.\n' "$STATE" >&2
        exit 2
    fi
fi

if [[ "$RESUME" == "0" ]]; then
    OUTPUT="$(python3 -c 'import pathlib,sys; print(pathlib.Path(sys.argv[1]).resolve())' "${1:-$PWD/dist/ColdKey.dmg}")"
    STAGING="$(mktemp -d "$PWD/.build/dmg.XXXXXX")"
fi
mkdir -p "$(dirname "$OUTPUT")"

if [[ "$NOTARIZE" == "1" ]]; then
    SIGNING_IDENTITIES="$(security find-identity -v -p codesigning | sed -n 's/^.*"\(Developer ID Application:.*\)"$/\1/p')"
    if [[ -z "${COLDKEY_SIGNING_IDENTITY:-}" && -n "$SIGNING_IDENTITIES" && "$SIGNING_IDENTITIES" != *$'\n'* ]]; then
        export COLDKEY_SIGNING_IDENTITY="$SIGNING_IDENTITIES"
    fi
    FOUND_IDENTITY=0
    while IFS= read -r identity; do
        if [[ -n "$identity" && "$identity" == "${COLDKEY_SIGNING_IDENTITY:-}" ]]; then FOUND_IDENTITY=1; fi
    done <<< "$SIGNING_IDENTITIES"
    if [[ "$FOUND_IDENTITY" != "1" ]]; then
        printf 'A valid Developer ID Application certificate with its private key is required.\n' >&2
        printf 'Create/import it in Xcode Settings > Accounts > Manage Certificates.\n' >&2
        printf 'If several are installed, select its full name with COLDKEY_SIGNING_IDENTITY.\n' >&2
        exit 1
    fi
    : "${COLDKEY_NOTARY_PROFILE:?Store notarization credentials in Keychain, then set COLDKEY_NOTARY_PROFILE to the profile name.}"
    if [[ "$RESUME" == "0" ]]; then
        xcrun notarytool history --keychain-profile "$COLDKEY_NOTARY_PROFILE" --output-format json > "$STAGING/notary-preflight.json"
        KEEP_STAGING=1
    fi
fi

submit_archive() {
    local archive="$1" result="$2"
    if [[ -f "$result" ]]; then return; fi
    if [[ -f "$result.submission-attempted" ]]; then
        printf 'A previous upload has an unknown result. Reconcile Apple history before retrying: %s\n' "$result" >&2
        exit 1
    fi
    # Save the attempt before uploading. Never silently repeat an uncertain upload.
    touch "$result.submission-attempted"
    printf 'Submitting %s to Apple for notarization…\n' "$(basename "$archive")"
    xcrun notarytool submit "$archive" --keychain-profile "$COLDKEY_NOTARY_PROFILE" \
        --no-wait --output-format json > "$result.tmp" || {
        if ! plutil -extract id raw -o - "$result.tmp" >/dev/null 2>&1; then
            printf 'Upload failed or its outcome is unknown. Inspect %s.tmp and Apple history.\n' "$result" >&2
            exit 1
        fi
    }
    plutil -extract id raw -o - "$result.tmp" >/dev/null
    mv "$result.tmp" "$result"
    rm "$result.submission-attempted"
}

check_submission() {
    local archive="$1" result="$2" status submission
    submission="$(plutil -extract id raw -o - "$result")"
    xcrun notarytool info "$submission" --keychain-profile "$COLDKEY_NOTARY_PROFILE" \
        --output-format json > "$result.tmp"
    status="$(plutil -extract status raw -o - "$result.tmp")"
    mv "$result.tmp" "$result"
    if [[ "$status" == "In Progress" ]]; then
        printf 'Apple is still processing %s (%s). Run --resume later.\n' "$(basename "$archive")" "$submission"
        exit 75
    fi
    if [[ "$status" != "Accepted" ]]; then
        xcrun notarytool log "$submission" --keychain-profile "$COLDKEY_NOTARY_PROFILE" "$result.log.json" || true
        printf 'Apple returned %s. Inspect %s before distributing this build.\n' "$status" "$result" >&2
        return 1
    fi
    printf 'Apple accepted submission %s.\n' "$submission"
}

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
APP="$CONTENTS/ColdKey.app"
if [[ "$RESUME" == "0" ]]; then
    COLDKEY_UNIVERSAL=1 ./scripts/build-app.sh "$APP"
fi
for ARCH in arm64 x86_64; do
    lipo "$APP/Contents/MacOS/Coldkey" -verify_arch "$ARCH"
done
codesign --verify --deep --strict --all-architectures "$APP"

if [[ "$NOTARIZE" == "1" ]]; then
    if [[ "$RESUME" == "0" ]]; then
        ditto -c -k --keepParent "$APP" "$STAGING/ColdKey.zip"
        python3 - "$STATE" "$STAGING" "$OUTPUT" "$COLDKEY_NOTARY_PROFILE" "$COLDKEY_SIGNING_IDENTITY" "$(source_fingerprint)" <<'PY'
import hashlib, json, pathlib, sys
state, staging, output, profile, identity, fingerprint = sys.argv[1:]
data = dict(staging=staging, output=output, keychainProfile=profile,
            signingIdentity=identity, sourceFingerprint=fingerprint,
            appArchiveSha256=hashlib.sha256(pathlib.Path(staging, "ColdKey.zip").read_bytes()).hexdigest())
temporary = pathlib.Path(state + ".tmp")
temporary.write_text(json.dumps(data, indent=2) + "\n")
temporary.replace(state)
PY
        submit_archive "$STAGING/ColdKey.zip" "$STAGING/app-notarization.json"
    fi
    check_submission "$STAGING/ColdKey.zip" "$STAGING/app-notarization.json"
    xcrun stapler staple "$APP"
    xcrun stapler validate "$APP"
    codesign --verify --deep --strict --all-architectures "$APP"
    if command -v syspolicy_check >/dev/null; then
        syspolicy_check distribution "$APP" --verbose > "$STAGING/distribution-check.txt" 2>&1 || {
            cat "$STAGING/distribution-check.txt" >&2; exit 1;
        }
    fi
fi

if [[ ! -f "$STAGING/dmg-notarization.json" && ! -f "$STAGING/dmg-notarization.json.submission-attempted" ]]; then
    "$TOOLS/bin/python" -m dmgbuild -s scripts/dmg-settings.py -D "app=$APP" \
        ColdKey "$STAGING/ColdKey.dmg"
    if [[ "$NOTARIZE" == "1" ]]; then
        codesign --force --sign "$COLDKEY_SIGNING_IDENTITY" --timestamp "$STAGING/ColdKey.dmg"
        shasum -a 256 "$STAGING/ColdKey.dmg" | awk '{print $1}' > "$STAGING/submitted-dmg.sha256"
    fi
fi
if [[ "$NOTARIZE" == "1" ]]; then
    if [[ ! -f "$STAGING/dmg-stapled" && "$(shasum -a 256 "$STAGING/ColdKey.dmg" | awk '{print $1}')" != "$(cat "$STAGING/submitted-dmg.sha256")" ]]; then
        printf 'The submitted DMG changed. Refusing to resume.\n' >&2; exit 1
    fi
    submit_archive "$STAGING/ColdKey.dmg" "$STAGING/dmg-notarization.json"
    check_submission "$STAGING/ColdKey.dmg" "$STAGING/dmg-notarization.json"
    xcrun stapler staple "$STAGING/ColdKey.dmg"
    touch "$STAGING/dmg-stapled"
    xcrun stapler validate "$STAGING/ColdKey.dmg"
    codesign --verify --strict "$STAGING/ColdKey.dmg"
    spctl --assess --type open --context context:primary-signature --verbose=2 "$STAGING/ColdKey.dmg"
fi
hdiutil verify "$STAGING/ColdKey.dmg"
mkdir -p "$STAGING/verify"
hdiutil attach -readonly -nobrowse -mountpoint "$STAGING/verify" "$STAGING/ColdKey.dmg" >/dev/null
VERIFY_MOUNT="$STAGING/verify"
codesign --verify --deep --strict --all-architectures "$VERIFY_MOUNT/ColdKey.app"
if [[ "$NOTARIZE" == "1" ]]; then
    xcrun stapler validate "$VERIFY_MOUNT/ColdKey.app"
    spctl --assess --type execute --verbose=2 "$VERIFY_MOUNT/ColdKey.app"
fi
hdiutil detach "$VERIFY_MOUNT"
VERIFY_MOUNT=""
# Retain the approved staging image until all publication files are written.
cp -f -- "$STAGING/ColdKey.dmg" "$OUTPUT.tmp"
mv -f -- "$OUTPUT.tmp" "$OUTPUT"
(
    cd "$(dirname "$OUTPUT")"
    shasum -a 256 "$(basename "$OUTPUT")" > "$(basename "$OUTPUT").sha256"
)
printf 'DMG: %s\nSHA-256: %s.sha256\n' "$OUTPUT" "$OUTPUT"
if [[ "$NOTARIZE" == "1" ]]; then
    cp "$STAGING/app-notarization.json" "$OUTPUT.app-notarization.json"
    cp "$STAGING/dmg-notarization.json" "$OUTPUT.notarization.json"
    printf 'Developer ID signed; Apple accepted and stapled both app and DMG.\n'
    rm "$STATE"
fi
KEEP_STAGING=0
