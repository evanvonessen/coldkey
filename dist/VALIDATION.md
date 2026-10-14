# Packaged Coldkey validation

Validated on October 13, 2026. The app source and original icon are unchanged from `9314dc59fd93a7d9e24f83fe971e788ac97534b3`; this update adds a website-downloadable DMG with a saved drag-to-Applications Finder window.

- PASS (earlier in this session; app source unchanged): `swift test` — 51 tests, zero failures or skips, including native Carbon registration and AppKit control checks.
- PASS (earlier in this session): existing `scripts/build-app.sh` native release build and strict signature verification.
- PASS: `scripts/build-dmg.sh` universal release build, both `arm64` and `x86_64` architecture checks, and strict signature verification for both architectures.
- PASS: both executable slices declare a macOS 13.0 minimum.
- PASS: compressed, read-only UDZO image verification, read-only mounting, Applications symlink, and SHA-256 checksum verification.
- PASS: opened the final DMG through Finder; it automatically opened a window showing the app icon on the left, the installation arrow, and Applications on the right. No visible Read Me or source files appear in the installer. Screenshot and saved Finder metadata checked.
- PASS: live drag from the app icon onto Applications reached Finder's normal replace-existing-app prompt. Cancelled that prompt to preserve the installed copy.
- PASS: strict signature verification of the app inside the final mounted DMG, and of an identical app copied out to a temporary folder. The build script now performs this check inside every completed image before publishing it.
- PASS (earlier in this session): copied the previous package's unchanged app source build to `/Applications/Coldkey.app`. The installed app launched on Apple Silicon, stayed running through the startup check, and uses menu-bar accessory activation policy.
- PASS: the original icon source matches the full-size PNG linked from the supplied [MacUpdate listing](https://hotkey.macupdate.com/) byte for byte. The packaged ICNS was extracted and visually checked.
- PASS: shell syntax and `git diff --check`.
- BLOCKED: live app menu interaction through Computer Use; the tool reported "Computer Use was not approved to use Coldkey." Finder installer interaction is verified; no live shortcut-recording, folder-control, or login/reboot check is claimed for the app.
- NOT RUN: runtime testing on an Intel Mac or macOS 13. The Intel binary was compiled and inspected on Apple Silicon.

The package is ad-hoc signed, with no Developer ID certificate or notarization. This test Mac reports Gatekeeper security disabled, so successful local launch does not prove Gatekeeper acceptance on another Mac. Installation instructions explain the possible Open Anyway step.

The standard arrow background comes from dmgbuild 1.6.7, with its MIT license included in the DMG's hidden `.licenses/dmgbuild.txt`. Pinned packaging dependencies are build-time tools only.

Installer SHA-256: `bd164883a7869ab9cce6eaffcd2ac51297248eb19925fb056ab9adeab09a5cdf`.
