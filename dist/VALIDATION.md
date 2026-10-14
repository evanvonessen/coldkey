# Packaged ColdKey validation

Validated on October 13, 2026. Release **0.1.0 (2)** is displayed and packaged as **ColdKey**. Its bundle identifier remains `com.evanvonessen.coldkey` to preserve existing shortcuts and settings. The original HotKey icon and shortcut behavior are retained.

- PASS: `swift test` — 51 tests, zero failures or skips, including native Carbon registration and AppKit control checks.
- PASS: universal release build containing `arm64` and `x86_64`; both executable slices declare a macOS 13.0 minimum.
- PASS: strict signature verification of the final mounted app and a copy extracted from the DMG for both architectures, using `Developer ID Application: Evan Von Essen (3N83BX5M9G)`, Hardened Runtime, a secure timestamp, and the Apple Events entitlement needed for Finder controls.
- PASS: the final notarized app launched as **ColdKey**, stayed running through its startup check, and uses menu-bar accessory activation policy. Only that isolated test instance was quit; installed and running copies were preserved.
- PASS: packaged `ColdKey.app` display name and unchanged bundle identifier. The original icon source is unchanged, and the final ICNS matches the previously verified Developer ID build.
- PASS: final Finder metadata selects icon view, with ColdKey on the left and Applications on the right. The installation arrow, Applications symlink, and hidden background license are present. The drag-and-drop window and Finder replacement prompt were also verified interactively earlier in this session.
- PASS: Developer ID signature verification of the final DMG, read-only image verification and mounting, mounted app signature verification, and SHA-256 checksum verification.
- PASS: shell syntax, entitlement plist validation, and `git diff --check`.
- PASS: the release workflow rejects missing or unsuitable signing identities before updating the installer and reads notarization credentials from Keychain.
- PASS: five packaging workflow tests using local tool doubles cover pending checks without duplicate uploads, both acceptance checkpoints, retry after a verification failure, rejection diagnostics, changed source inputs, distribution-check failure, and uncertain upload outcomes. These tests do not replace Apple's server checks.
- PASS: the live resume workflow reused the existing app submission, submitted the DMG once after app acceptance, and published the final installer only after both approvals and all required checks passed.
- PASS: Apple accepted app submission `d478b150-b966-400c-b640-42469949d972`; [app acceptance receipt](ColdKey.dmg.app-notarization.json).
- PASS: Apple accepted DMG submission `2c53b38e-9527-47d9-b219-2c8209d859bf`; [DMG acceptance receipt](ColdKey.dmg.notarization.json).
- PASS: approval tickets are stapled and validated on the final DMG, its mounted app, and the extracted app copy.
- PASS: `syspolicy_check distribution` on the final app passed Developer ID, certificate/profile matching, the explicit notarized signature requirement, XProtect, and Gatekeeper scans. Both top-level and deep policy matched `notarized`.
- NOT RUN: runtime testing on an Intel Mac or macOS 13, a quarantined download/install on a Mac with Gatekeeper enforcement enabled, actual login/reboot testing, and live Finder-control permission testing for the signed app.

This Mac reports Gatekeeper assessments disabled, so local `spctl` acceptance alone is not an enforcement test. Apple **Accepted** results, validated approval tickets, and the explicit notarized distribution checks above establish the final release's signing and notarization status.

The standard arrow background comes from dmgbuild 1.6.7, with its MIT license included in the DMG's hidden `.licenses/dmgbuild.txt`. Pinned packaging dependencies are build-time tools only; no Python or third-party runtime dependencies are added to the app.

Installer SHA-256: `5fd20d08d358390f6f872c858fb4adf34d51581d3ef2df150d166098872ac82e`.
