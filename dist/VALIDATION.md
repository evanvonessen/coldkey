# Packaged ColdKey validation

Validated on October 21, 2026. Release **0.4.2 (7)** moves the manual update action from the menu into Settings as a **Check for Updates** button. The daily-check checkbox stays separate. Existing buttons, labels, behavior, and the centered gray **Evan Von Essen** credit remain, with no explanatory paragraphs. Bundle identifier: `com.evanvonessen.coldkey`.

- PASS: `swift test` — 105 tests total, 104 passed, one skipped, zero failures. Settings tests verify that clicking the new button dispatches a manual check with daily checks off, does not change that preference, and reflects updater availability. Controls, callbacks, layout, and the credit as the only text field remain covered. The native bare-F1 reservation test skipped because the chord was already reserved (`-9878`).
- PASS: `python3 Tests/Packaging/test_notarization.py` — five release checkpoint tests.
- PASS: signed app startup, native updater initialization, and accessory activation policy on a disposable copy. Installed copies and release staging were preserved.
- PASS: universal executable (`arm64` and `x86_64`), both declaring macOS 13.0 as minimum.
- PASS: strict deep signature verification across architectures, app and DMG ticket validation, read-only image verification and mounting, and Gatekeeper assessment as **Notarized Developer ID**.
- PASS: Apple accepted app submission `5e3c8bc5-6c6a-41fd-aa1c-707088d6cfbe`; [app receipt](ColdKey.dmg.app-notarization.json).
- PASS: Apple accepted DMG submission `2cc955db-69e9-4b20-9108-ff5b8afdc737`; [DMG receipt](ColdKey.dmg.notarization.json). Both approval tickets are stapled and validated. Each archive was submitted once.
- PASS: signed update feed prepared and verified with the existing ColdKey Ed25519 key; the versioned release asset matches the final DMG. Private signing credentials remain in Keychain.
- PASS: checksum verification, shell syntax, and `git diff --check`.
- NOT RUN for this release: a full update installation through the Settings button, physical shortcut delivery, native mode switching, actual Accessibility grant/revocation, Intel hardware, macOS 13 runtime, login/reboot, quarantined first installation, or a 24-hour update wait. Native mode/registration checks and five signed-update scenarios were recorded for [0.4.0](https://github.com/evanvonessen/coldkey/blob/v0.4.0/dist/VALIDATION.md). Sparkle, its signed update verification, and installation configuration are unchanged.

The compressed installer is **1,694,012 bytes**. Sparkle 2.10.0 remains the sole runtime dependency. Button availability follows Sparkle's KVO-compliant property without polling. Licenses remain included in the app and DMG; Python packaging tools are build-time only.

Installer SHA-256: `dd2d8c4f87dab41a640785ca2d92b46bfd28619bed424bff05a00d960bb9d2bd`.
