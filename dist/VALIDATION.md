# Packaged ColdKey validation

Validated on October 21, 2026. Release **0.4.1 (6)** removes explanatory paragraphs and the update tooltip from Settings. The existing buttons, checkbox labels, behavior, window dimensions, and centered gray **Evan Von Essen** credit are preserved. Bundle identifier: `com.evanvonessen.coldkey`.

- PASS: `swift test` — 105 tests total, 104 passed, one skipped, zero failures. Existing Settings tests verify the original controls, callbacks, checkbox state, layout, and the credit as the only text field. One native bare-F1 reservation test skipped because the chord was already reserved (`-9878`); it did not release another app's shortcut.
- PASS: `python3 Tests/Packaging/test_notarization.py` — five release checkpoint tests.
- PASS: signed app startup and accessory activation policy. The exact approved archive was used for the packaged app.
- PASS: universal executable (`arm64` and `x86_64`), both declaring macOS 13.0 as minimum.
- PASS: strict deep signature verification across architectures, app and DMG ticket validation, read-only image verification and mounting, and Gatekeeper assessment as **Notarized Developer ID**.
- PASS: Apple accepted app submission `fd9d43bd-2a53-4a2d-b7e7-2c954609f8a0`; [app receipt](ColdKey.dmg.app-notarization.json).
- PASS: Apple accepted DMG submission `6ffdbdaa-9c67-44af-b6cb-cf52e09120f4`; [DMG receipt](ColdKey.dmg.notarization.json). Both approval tickets are stapled and validated. Each archive was submitted once.
- PASS: signed update feed prepared and verified with the existing ColdKey Ed25519 key; versioned release asset matches the final DMG. Private signing credentials remain in Keychain.
- PASS: checksum verification, shell syntax, and `git diff --check`.
- NOT RUN for this Settings-only release: physical shortcut delivery, native mode switching, update installation, an actual Accessibility grant/revocation, Intel hardware, macOS 13 runtime, login/reboot, quarantined first installation, or a 24-hour update wait. The mode controller, shortcut filter, updater, and packaging scripts are unchanged. Native mode/registration checks and five signed-update scenarios were recorded for [0.4.0](https://github.com/evanvonessen/coldkey/blob/v0.4.0/dist/VALIDATION.md).

The compressed installer is **1,691,991 bytes**. Sparkle 2.10.0 remains the sole runtime dependency. Its license and bundled notices are in `Contents/Resources/Sparkle-LICENSE.txt`. The installer background comes from dmgbuild 1.6.7, with its MIT license in `.licenses/dmgbuild.txt`. Python packaging tools are build-time only.

Installer SHA-256: `57814182ae199704ba4733b48422ff388274230f78e85156a300bea28ea9697f`.
