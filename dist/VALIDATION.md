# Packaged ColdKey validation

Validated on October 21, 2026. Release **0.4.3 (8)** shrinks Settings to fit its controls. The normal content size is **300 × 240 points**, verified with Accessibility both allowed and not allowed. The **Evan Von Essen** credit stays small, gray, horizontally centered, and 18 points above the bottom. Buttons, labels, and behavior are unchanged. Bundle identifier: `com.evanvonessen.coldkey`.

- PASS: `swift test` — 105 tests total, 104 passed, one skipped, zero failures. Layout tests verify the smaller window, unclipped controls, footer alignment and color, and existing actions. The native bare-F1 reservation test skipped because the chord was already reserved (`-9878`).
- PASS: a native AppKit measurement of both Accessibility states reports 300 × 240 points. Window size derives from the controls' fitting size rather than the previous 470 × 450 content rectangle.
- PASS: `python3 Tests/Packaging/test_notarization.py` — five release checkpoint tests.
- PASS: signed app startup and accessory activation policy on a disposable copy. Installed copies and release staging were preserved.
- PASS: universal executable (`arm64` and `x86_64`), both declaring macOS 13.0 as minimum.
- PASS: strict deep signature verification across architectures, app and DMG ticket validation, read-only image verification and mounting, and Gatekeeper assessment as **Notarized Developer ID**.
- PASS: Apple accepted app submission `288a7a7c-87fc-4ef6-ac83-ca09a4bfa8f1`; [app receipt](ColdKey.dmg.app-notarization.json).
- PASS: Apple accepted DMG submission `86b8a34b-814c-4817-bceb-7f41c9dd9d4c`; [DMG receipt](ColdKey.dmg.notarization.json). Both approval tickets are stapled and validated. Each archive was submitted once.
- PASS: signed update feed prepared and verified with the existing ColdKey Ed25519 key; the versioned release asset matches the final DMG. Private signing credentials remain in Keychain.
- PASS: checksum verification, shell syntax, and `git diff --check`.
- NOT RUN for this layout-only release: a full update installation, physical shortcut delivery, native mode switching, actual Accessibility grant/revocation, Intel hardware, macOS 13 runtime, login/reboot, quarantined first installation, or a 24-hour update wait. Native mode/registration checks and five signed-update scenarios were recorded for [0.4.0](https://github.com/evanvonessen/coldkey/blob/v0.4.0/dist/VALIDATION.md). Shortcut handling, updater behavior, and release scripts are unchanged.

The compressed installer is **1,694,164 bytes**. Sparkle 2.10.0 remains the sole runtime dependency. Licenses remain included in the app and DMG; Python packaging tools are build-time only.

Installer SHA-256: `5f34d85bf88a0e66e4908981893dfde6173aa8625a7518addac8f6d3328f6b5d`.
