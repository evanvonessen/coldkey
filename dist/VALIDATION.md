# Packaged ColdKey validation

Validated on October 13, 2026. The app is now displayed and packaged as **ColdKey**. Its bundle identifier remains `com.evanvonessen.coldkey` to preserve existing shortcuts and settings. The original HotKey icon and shortcut behavior are retained.

- PASS: `swift test` — 51 tests, zero failures or skips, including native Carbon registration and AppKit control checks.
- PASS: universal release build containing `arm64` and `x86_64`; both executable slices declare a macOS 13.0 minimum.
- PASS: strict signature verification of the staged notarization app for both architectures, using `Developer ID Application: Evan Von Essen (3N83BX5M9G)`, Hardened Runtime, a secure timestamp, and the Apple Events entitlement needed for Finder controls.
- PASS: the Developer ID signed app launched as **ColdKey**, stayed running through its startup check, and uses menu-bar accessory activation policy. Only that temporary test instance was quit.
- PASS: packaged `ColdKey.app` display name, unchanged bundle identifier, saved icon layout, original icon, installation arrow, and Applications symlink.
- PASS: the current renamed, ad-hoc signed DMG was rebuilt with the updated packaging script; image verification, mounted app signature verification, and SHA-256 checksum verification passed. This is the intermediate installer currently in `dist/`.
- PASS: shell syntax, entitlement plist validation, and `git diff --check`.
- PASS: the release workflow rejects missing or unsuitable signing identities before updating the installer and reads notarization credentials from Keychain.
- PASS: five packaging workflow tests using local tool doubles cover pending checks without duplicate uploads, both acceptance checkpoints, retry after a verification failure, rejection diagnostics, changed source inputs, distribution-check failure, and uncertain upload outcomes. These tests do not replace Apple's server checks.
- PASS: the live `--resume` command reuses the existing app submission, returns exit 75 while it is pending, and preserves the signed archive and previous installer.
- IN PROGRESS: Apple app notarization submission `d478b150-b966-400c-b640-42469949d972`.
- PENDING: final DMG signing, Apple DMG acceptance, attached approval tickets, final image/checksum checks, and publication of the notarized release.
- LIMITED: the local `syspolicy_check notary-submission` command returned exit 70 with an empty issue list. Apple’s server result and post-notarization distribution checks will determine the release outcome.
- NOT RUN: runtime testing on an Intel Mac or macOS 13, actual login/reboot testing, and live Finder-control permission testing for the signed app.

This Mac reports Gatekeeper assessments disabled. A successful local launch or `spctl` override alone does not prove website-download acceptance. The release requires Apple **Accepted** results and validated approval tickets for both the app and DMG before publishing the final installer.

The standard arrow background comes from dmgbuild 1.6.7, with its MIT license included in the DMG's hidden `.licenses/dmgbuild.txt`. Pinned packaging dependencies are build-time tools only; no Python or third-party runtime dependencies are added to the app.
