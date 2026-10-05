#!/bin/bash
set -u

fail() {
    printf '\nColdkey could not finish: %s\n' "$1" >&2
    if [[ -t 0 ]]; then
        read -r -p "Press Return to close this window…" || true
    fi
    exit 1
}

cd -- "$(dirname -- "${BASH_SOURCE[0]}")" || fail "Cannot find the project folder. Keep this file inside the Coldkey checkout."
PROJECT_DIR="$PWD"
APP="$PROJECT_DIR/.build/Coldkey.app"
STAGING=""
cleanup() { if [[ -n "$STAGING" ]]; then rm -rf -- "$STAGING"; fi; }
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

xcode-select -p >/dev/null 2>&1 || fail "Install Xcode or Apple's Command Line Tools, then try again."
mkdir -p "$PROJECT_DIR/.build" || fail "Cannot write to the project folder. Check its permissions."
STAGING="$(mktemp -d "$PROJECT_DIR/.build/run.XXXXXX")" || fail "Cannot create a temporary build folder. Check free disk space and permissions."

printf 'Building Coldkey…\n'
./scripts/build-app.sh "$STAGING/Coldkey.app" || fail "Build failed. Read the error above, fix it, and double-click this file again. The previous app has not been stopped."
[[ -x "$STAGING/Coldkey.app/Contents/MacOS/Coldkey" ]] || fail "The build did not produce a runnable app. Try building again."

printf '\nClosing the previous Coldkey, if running…\n'
swift - <<'SWIFT'
import AppKit

let apps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.evanvonessen.coldkey")
for app in apps where !app.isTerminated {
    if !app.terminate() && !app.isTerminated {
        fputs("Coldkey declined the quit request. Quit it from its menu bar and try again.\n", stderr)
        exit(1)
    }
}
let deadline = Date(timeIntervalSinceNow: 10)
while apps.contains(where: { !$0.isTerminated }) {
    guard Date() < deadline else {
        fputs("Coldkey is still running. Quit it from its menu bar and try again.\n", stderr)
        exit(1)
    }
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
}
SWIFT
[[ $? -eq 0 ]] || fail "Could not close the previous Coldkey safely. Quit Coldkey manually, then try again. No app was force-quit."

if [[ -e "$APP" ]]; then
    mv -- "$APP" "$STAGING/Previous.app" || fail "Cannot replace the previous build. Check folder permissions and try again."
fi
if ! mv -- "$STAGING/Coldkey.app" "$APP"; then
    if [[ -e "$STAGING/Previous.app" ]] && ! mv -- "$STAGING/Previous.app" "$APP"; then
        BACKUP="$STAGING/Previous.app"
        STAGING=""
        fail "Could not restore the previous build. It is preserved at: $BACKUP"
    fi
    fail "Cannot move the new app into place. The previous build was restored; check folder permissions and try again."
fi

open -n "$APP" || fail "The build succeeded but macOS could not open it. Open $APP in Finder to see the reason."
printf '\nColdkey is running. Look for ⌘ in the menu bar.\nYour saved shortcuts are kept.\n'
