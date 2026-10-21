# Packaged ColdKey validation

Validated on October 21, 2026. Release **0.2.0 (3)** adds bare **F1–F20** shortcuts for applications and folders alongside the existing Command, Option, and Control shortcuts. The first README download points to this installer. The bundle identifier remains `com.evanvonessen.coldkey` to preserve saved shortcuts and settings.

- PASS: `swift test` — 59 tests, zero failures or skips. Coverage includes recording all F1–F20 with and without the function event flag, readable labels, saving for applications and folders, persistence alongside modified shortcuts, conflicts, repeat suppression, and native bare F1/F20 exclusive registration and release.
- PASS: `python3 Tests/Packaging/test_notarization.py` — five packaging workflow tests. These use local tool doubles and are separate from the live Apple approvals below.
- PASS: universal release build containing `arm64` and `x86_64`; both packaged executable slices declare macOS 13.0 as their minimum.
- PASS: strict signature verification of the mounted and extracted final app for both architectures, using `Developer ID Application: Evan Von Essen (3N83BX5M9G)`, Hardened Runtime, a secure timestamp, and the Apple Events entitlement needed for Finder controls.
- PASS: final app version 0.2.0 (3), unchanged bundle identifier, original icon packaging, and menu-bar accessory configuration.
- PASS: the final notarized app extracted from the DMG stayed running during its startup check and used accessory activation policy. Only the isolated test instance was quit; installed and running copies were preserved.
- PASS: saved Finder icon positions place ColdKey on the left and Applications on the right. The Applications symlink and hidden background license are present.
- PASS: Developer ID signature verification of the final DMG, read-only image verification and mounting, mounted app verification, and SHA-256 checksum verification.
- PASS: shell syntax, entitlement plist validation, and `git diff --check`.
- PASS: notarization credentials validated and saved in Keychain. No private key contents or credential values are included in the release files.
- PASS: the live release workflow submitted the app and DMG once each, resumed the same submissions, and replaced the installer only after both approvals and all required checks passed.
- PASS: Apple accepted app submission `db0e8c2d-14f4-4ca2-8ddf-df253cf0abdb`; [app acceptance receipt](ColdKey.dmg.app-notarization.json).
- PASS: Apple accepted DMG submission `a0033a27-de71-443b-b853-3d64983633d3`; [DMG acceptance receipt](ColdKey.dmg.notarization.json).
- PASS: approval tickets are stapled and validated on the final DMG, its mounted app, and the extracted app copy.
- PASS: Gatekeeper assessments are enabled on this Mac. The final DMG and mounted/extracted app passed `spctl` assessment as **Notarized Developer ID**. `syspolicy_check distribution` on the final app passed the Developer ID certificate, explicit notarized signature, XProtect, and Gatekeeper checks; both top-level and deep policy matched `notarized`.
- NOT RUN: physical function-key delivery and suppression in another foreground app, runtime testing on Intel hardware or macOS 13, installation from a quarantined download, login/reboot testing, and live Finder-control permission testing. Native registration and AppKit recording/save paths were tested separately without keyboard injection.

Bare function keys retain exclusive native hotkey registration. macOS-reserved shortcuts, secure input, and another tool's exclusive global registration can still prevent delivery or registration; the app reports unavailable reservations. Apple keyboards may need standard function keys enabled in Keyboard settings to send F1 without Fn instead of a brightness/media control.

The standard arrow background comes from dmgbuild 1.6.7, with its MIT license included in the DMG's hidden `.licenses/dmgbuild.txt`. Pinned packaging dependencies are build-time tools only; no Python or third-party runtime dependencies are added to the app.

Installer SHA-256: `75665c979c5bcc3cbadccaee36f4120af61be6c4bbeb42e962e06c9f95c32c93`.
