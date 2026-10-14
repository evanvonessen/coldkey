# Packaged Coldkey validation

Validated on October 13, 2026. The app source and original icon are unchanged from `9314dc59fd93a7d9e24f83fe971e788ac97534b3`; this update adds packaging and installation instructions.

- PASS: `swift test` — 51 tests, zero failures or skips, including native Carbon registration and AppKit control checks.
- PASS: existing `scripts/build-app.sh` native release build and strict signature verification.
- PASS: `scripts/build-dmg.sh` universal release build, both `arm64` and `x86_64` architecture checks, and strict signature verification for both architectures.
- PASS: both executable slices declare a macOS 13.0 minimum.
- PASS: compressed, read-only UDZO image verification, read-only mounting, Applications symlink, and SHA-256 checksum verification.
- PASS: copied the app from the DMG to `/Applications/Coldkey.app`; the copy matches the mounted app and retains a valid signature. The installed app launched on Apple Silicon, stayed running through the startup check, and uses menu-bar accessory activation policy.
- PASS: the original icon source matches the full-size PNG linked from the supplied [MacUpdate listing](https://hotkey.macupdate.com/) byte for byte. The packaged ICNS was extracted and visually checked.
- PASS: shell syntax and `git diff --check`.
- BLOCKED: live menu interaction through Computer Use; the tool reported "Computer Use was not approved to use Coldkey." No live shortcut-recording, folder-control, or login/reboot check is claimed for this package.
- NOT RUN: runtime testing on an Intel Mac or macOS 13. The Intel binary was compiled and inspected on Apple Silicon.

The package is ad-hoc signed, with no Developer ID certificate or notarization. This test Mac reports Gatekeeper security disabled, so successful local launch does not prove Gatekeeper acceptance on another Mac. Installation instructions explain the possible Open Anyway step.

Installer SHA-256: `9014e837e6d9fda4fa54b4c591d7f66376c6ba132ef5313926910366b116704e`.
