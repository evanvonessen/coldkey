# Packaged ColdKey validation

Validated on October 21, 2026. Release **0.3.0 (4)** adds daily update checks requiring approval to download/install, a persistent **Check for updates** Settings checkbox, a manual menu command, a quiet menu reminder, and the small centered gray **Evan Von Essen** Settings credit. Bare F1–F20 and existing shortcuts remain supported. The bundle identifier remains `com.evanvonessen.coldkey`.

- PASS: `swift test` — 62 tests, zero failures or skips. Existing shortcut behavior, Settings checkbox toggling/reopening, unavailable-update messaging, control layout, credit alignment/font/color, and Objective-C updater delegate callbacks are covered.
- PASS: `python3 Tests/Packaging/test_notarization.py` — five release checkpoint tests, including preservation of the old installer until both Apple approvals succeed and detection of changed release inputs. Dependency pins and the public update signing key now participate in the release fingerprint.
- PASS: five native Sparkle integration scenarios against disposable copies of the final signed app: decline without any archive download or replacement; approve and install the newer signed app from the exact final DMG; reject a tampered signed feed without downloading; reject an invalid archive signature without replacement; and report an already-current app without downloading. The driver additionally verifies daily scheduling, manual checking with scheduled checks disabled, persisted preferences, and disabled automatic downloads/installation.
- PASS: universal release build containing `arm64` and `x86_64`; both app executable slices declare macOS 13.0 as their minimum.
- PASS: pinned Sparkle 2.10.0 framework embedded with preserved symlinks. Optional sandbox XPC services and development headers are omitted. Autoupdate, Updater.app, the framework, and ColdKey are signed with the same Developer ID; strict deep signature verification succeeds.
- PASS: actual AppKit Settings preview visually inspected; the update checkbox is visible and the credit is smaller, gray, centered horizontally, and at the bottom. Automated layout checks also cover these controls.
- PASS: final notarized app startup and accessory activation policy; only isolated test processes/copies are used and installed copies are preserved.
- PASS: final app/DMG Developer ID signatures, read-only image verification and mounting, notarization ticket validation, and Gatekeeper assessment as **Notarized Developer ID** with assessments enabled.
- PASS: Apple accepted app submission `89ee163b-ad42-402a-acdc-12c2668ee836`; [app acceptance receipt](ColdKey.dmg.app-notarization.json).
- PASS: Apple accepted DMG submission `81499fbe-dc81-4a46-bdf5-9490557609e8`; [DMG acceptance receipt](ColdKey.dmg.notarization.json).
- PASS: the release workflow submitted each archive once and resumed those submissions until approval. App and DMG tickets are stapled and validated before publication.
- PASS: the signed appcast and installer archive verify with ColdKey's Ed25519 key. The public key is pinned in the app; the private signing key remains in Keychain. GitHub feed/release URLs need no credentials in the app.
- PASS: packaged configuration enables daily checks (86400 seconds), disables automatic downloads/installation, system profiling, and release-note web views, and requires signed feeds and archive verification before extraction.
- PASS: checksum verification, shell syntax, entitlement plist validation, and `git diff --check`.
- NOT RUN: an actual 24-hour wait, runtime testing on Intel hardware or macOS 13, login/reboot testing, a quarantined first installation, and physical function-key suppression in another foreground app. Daily scheduling is checked through Sparkle's configured interval; update replacement and refusal are tested live on disposable copies.

The final compressed installer is 1,631,499 bytes (about 1.6 MB). Update checks use Sparkle's scheduler rather than custom polling; the installer helper runs when an update is approved, not as a permanent background service. Existing 0.2.0 installations need one manual installation of this release to acquire the updater.

Sparkle's license and bundled notices are included as `Contents/Resources/Sparkle-LICENSE.txt`. The standard installer arrow background comes from dmgbuild 1.6.7, with its MIT license in the DMG's hidden `.licenses/dmgbuild.txt`. Python packaging tools are build-time only.

Installer SHA-256: `2307ce27c65a96e53d149957f10765e25adc1a3f969efd7232c68bd26c757f88`.
