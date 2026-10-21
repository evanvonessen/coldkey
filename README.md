# ColdKey

[**Download ColdKey.dmg**](dist/ColdKey.dmg?raw=true)

Supports Apple Silicon and Intel Macs running macOS 13 or later. No developer tools are needed to install it.

The download above is **0.4.1 (6)**, with a minimal Settings window, a changeable **⌘F12** function-row toggle, daily update checks, and bare **F1–F20** shortcuts.

A tiny, native macOS menu bar app inspired by HotKey. Requires macOS 13 or later.

- Click the **⌘** menu bar icon → **Add Shortcut…**.
- Choose an application and record **F1–F20 alone** (for example, **F1**), or Command, Option, and/or Control plus one key.
- Enable **Hide app when it is already in front** to toggle between showing and hiding it.
- Or enable **Hide even when not frontmost** to hide a visible app even while another app is in front. Press again to show it. This separate option is off by default and works on its own or with the original option.
- Launch apps from the menu, or edit/remove bindings under **Manage Shortcuts**.
- **⌘F12** toggles between the top-row icon controls and standard F1–F12 keys. In **Settings…**, choose **Allow Function Row Shortcut…** and enable ColdKey in macOS **Privacy & Security → Accessibility**. Change the key under **Manage Shortcuts → Toggle Function Row → Edit…**, or choose **Function Row** when adding it. The chosen chord is reserved for this action across apps in both modes while ColdKey runs, including while the editor is open. Rebinding, removing it, or quitting releases the old chord. Clicking **Toggle Function Row** in the menu also switches modes. Only one function-row toggle is needed. If an existing ColdKey shortcut already uses ⌘F12, it is preserved and you can add the toggle with another key.
- Open **Settings…** from the ⌘ menu for **Start at login**. It is off for a new installation and changes only when you click it. Run the signed app from `/Applications` or `~/Applications` before enabling it; development copies in `.build` cannot be enabled. A dash means macOS requires approval: choose **Open Login Items…** to approve it in System Settings, or clear the checkbox to cancel. The checkbox reads macOS’s saved status when Settings opens or ColdKey becomes active, including changes made in System Settings. The checkbox continues to reflect macOS’s saved status if a change fails.
- **Check for updates** in Settings enables one background check per day and is on by default. Uncheck it to stop scheduled checks. **Check for Updates…** in the menu still works whenever you want. Available updates appear quietly as **Update Available…** in the menu; checking never downloads or installs a new app. Open the update and approve it to download and install. Settings contains only the existing controls and the centered **Evan Von Essen** credit at the bottom.
- Choose **Folder** in the editor to bind a directory. **Close folder window when it is already in front** closes the matching window only when Finder is active and that exact window is in front; otherwise it brings the window forward. **Close even when not frontmost** also closes a matching window behind another app or Finder window. With both off, the shortcut opens or raises the folder. With both on, the second option takes precedence. If several windows match, only the frontmost matching window is affected. These actions close windows, never delete folders or hide Finder.

Shortcuts are saved locally and restored on launch. They use exclusive native hotkey registration to take precedence over ordinary foreground-app shortcuts. Holding a shortcut triggers it once until you release the key. Application and folder shortcuts pause while the editor is open so you can record them. The function-row toggle remains reserved; clicking its recorder lets you capture the reserved chord without toggling. Conflicts are shown and prevent saving an unavailable shortcut; saved shortcuts that cannot register at launch are marked unavailable. macOS-reserved shortcuts, secure input, and shortcuts owned by another global tool can prevent registration or delivery. ColdKey cannot override those protections; choose another combination or release the shortcut in the other tool.

Function-key shortcuts work for both applications and folders, with or without the existing Command, Option, and Control modifiers. If pressing F1 changes brightness instead, enable **System Settings → Keyboard → Keyboard Shortcuts → Function Keys → Use F1, F2, etc. keys as standard function keys** to use the function row without holding Fn. You can still hold Fn for the hardware controls. See [Apple's function-key instructions](https://support.apple.com/102439). The Function Row action changes and saves this macOS setting only when you invoke it. Its default ⌘F12 recognizes both F12 and Volume Up events, so it can switch back from icon mode without holding Fn. The toggle supports F1, F2, F7–F20 and modified letters or other keys; F3–F6 are excluded for this action because their icon controls vary across Mac keyboards. Other app and folder shortcuts still support F1–F20.

Both hide options apply to the whole app, including all its windows. Hidden apps are shown and activated; apps that are not running are launched. Existing shortcuts keep their previous hide setting when updating.

Folder selections use saved bookmarks to follow moves and renames across restarts. If a folder is missing or inaccessible, choose it again. New folder shortcuts have both close options off. Existing folder shortcuts retain their behavior: the old close option migrates to **Close even when not frontmost**; old open-only shortcuts keep both off. The first folder action explains and requests macOS permission to control Finder; you can cancel or manage it in **System Settings → Privacy & Security → Automation**. App and folder shortcuts do not require Accessibility permission; the Function Row shortcut does. Finder exposes a window's current folder, so a folder in an inactive tab is not treated as a matching window.

## Install the packaged app

Quit any running ColdKey and double-click the DMG. It opens a compact installer window with the original ColdKey icon on the left, an arrow, and Applications on the right. Drag **ColdKey** onto **Applications**, then eject the disk and open ColdKey from Applications. Look for **⌘** in the menu bar. Updating keeps your saved shortcuts.

Upload `dist/ColdKey.dmg` to your website and link directly to that file. Visitors download and open the DMG; they do not need source files or developer tools. The repository, update feed, and release downloads are public and require no credentials in the installed app.

**Signed and notarized by Apple.** Both the app and DMG include validated Apple approval tickets. This release should not require **Open Anyway**; macOS may still display its normal first-open confirmation for an app downloaded from the internet.

The installer and its [SHA-256 checksum](dist/ColdKey.dmg.sha256) are saved in `dist/`. To verify a download, place both files in the same folder and run `shasum -a 256 -c ColdKey.dmg.sha256` there. See the [validation record](dist/VALIDATION.md) for checks and remaining test limits.

## Build and run

Requires the Swift tools included with Xcode or its Command Line Tools.

For updates, pull the latest changes, then double-click **Build and Run.command** in the project folder. It builds, safely quits the previous ColdKey, and launches the new local app with your saved shortcuts. It does not pull changes or overwrite a copy in Applications. If something fails, the Terminal window stays open with the error.

```sh
./scripts/build-app.sh
open .build/ColdKey.app
```

Copy `.build/ColdKey.app` to Applications if desired. Local builds use ad-hoc signing. The [existing bundle identifier](scripts/build-app.sh) stays the same so shortcuts and settings survive the ColdKey name change. Open `Package.swift` in Xcode for development.

The build packages the original HotKey by codenuts app icon at standard and Retina sizes. The menu bar keeps its monochrome ⌘ symbol. Icon sources and provenance are in [Assets](Assets/README.md).

```sh
swift test
python3 Tests/Packaging/test_notarization.py
```

To check the live native function-row setting in both directions, run `Tests/FunctionRow/validate_mode.sh`. It temporarily changes the row mode twice and restores the exact original runtime setting and saved preference. It also checks native ⌘F12 exclusive registration in each mode. Event parsing, media aliases, repeats, and rebind reservations are covered by the Swift tests. Physical shortcut delivery across foreground apps requires enabling Accessibility for the signed ColdKey app.

## Build the DMG

```sh
./scripts/build-dmg.sh
```

This builds an ad-hoc signed development installer from the current source for Apple Silicon and Intel. It checks the app signature and creates and verifies a compressed, read-only `dist/ColdKey.dmg` with a saved Finder icon layout, installation arrow, and Applications shortcut. Only the two drag-and-drop icons appear in the installer window. It also writes `dist/ColdKey.dmg.sha256`. For website releases, use the signing and notarization workflow below and commit the installer, checksum, and acceptance receipts.

DMG creation also requires Python 3.9 or later. The first run installs pinned `dmgbuild` packaging tools into the ignored `.build/dmg-tools` environment; later runs reuse them. These are build tools only: the installed app contains no Python runtime. The script leaves the running app and installed copies alone.

## Sign and notarize a website release

Install a **Developer ID Application** certificate with its private key in this Mac's Keychain. Apple Development and Apple Distribution certificates are not suitable for website releases. Xcode's **Settings → Apple Accounts → your team → Manage Certificates → + → Developer ID Application** can create the certificate for an authorized account.

Store the notarization login in Keychain once:

```sh
xcrun notarytool store-credentials ColdKey
```

Use your Apple Developer account, its team ID, and an app-specific password generated at [Apple Account](https://account.apple.com/). Enter the password only at the secure Terminal prompt; do not put it in source files, environment variables, or Git.

Alternatively, save a downloaded Team API key in the same Keychain profile:

```sh
xcrun notarytool store-credentials ColdKey \
  --key /path/to/AuthKey_KEY_ID.p8 --key-id KEY_ID --issuer ISSUER_ID
```

Keep the private `.p8` file outside the repository. The release script uses the saved profile for either authentication method.

```sh
COLDKEY_NOTARY_PROFILE=ColdKey ./scripts/build-dmg.sh --notarize
```

The script chooses the only installed Developer ID Application identity. If you have more than one, also set `COLDKEY_SIGNING_IDENTITY` to the full certificate name. It signs the universal app with Hardened Runtime, a secure timestamp, and the Finder automation entitlement, then submits it to Apple. A pending submission returns exit **75** and saves its files, submission receipt, and release state in the ignored `.build` directory. Check that same submission later with:

```sh
./scripts/build-dmg.sh --resume
```

Each resume checks Apple once. When the app is **Accepted**, it attaches and validates the app's approval ticket, checks distribution readiness, builds and signs the DMG, and submits that DMG once. When the DMG is also **Accepted**, it attaches and validates the DMG ticket and verifies the final image and mounted app before updating `dist/ColdKey.dmg` and its checksum. The two acceptance receipts are saved alongside the DMG. The resume command uses the saved Keychain profile and certificate name; credentials stay in Keychain.

Pending or unsuccessful submissions leave the previous installer in place. Starting a second notarized build is blocked while a release is saved. Resume also refuses changed release inputs or archives; an upload with an uncertain outcome requires reconciling Apple's submission history before trying again. Preserve `.build/ColdKey-notarization-state.json` and its staging folder until the release finishes. The packaging tests exercise these checkpoints with local tool doubles and make no Apple submissions.

A notarized release should not require **Open Anyway**; macOS may still display its normal first-open confirmation for an app downloaded from the internet.

## Publish an app update

ColdKey uses pinned [Sparkle 2.10.0](https://sparkle-project.org/) for update verification and installation. It checks the signed [appcast](updates/appcast.xml) over HTTPS once per day while running. Both the feed and update archive are signed with ColdKey's Ed25519 key; the private key is stored in Keychain under account `com.evanvonessen.coldkey`. Only its public key is in [scripts/update-public-key.txt](scripts/update-public-key.txt). Preserve this Keychain key for future releases; do not generate a replacement casually.

After increasing the app version and build number in `scripts/build-app.sh`, build and notarize the DMG using the workflow above, then prepare the signed feed and versioned release asset:

```sh
./scripts/prepare-update.sh 0.4.1
```

Commit the source, installer, checksum, approval receipts, and signed `updates/appcast.xml`. Publish a GitHub release tagged `v0.4.1` at that commit with `.build/update-v0.4.1/ColdKey-0.4.1.dmg` and its checksum as assets. Keep versioned assets unchanged once published. Publish the assets before advancing `main` to the new feed so the download already exists. Use the new version number in these paths for later releases. Re-run the preparation script after any change to the installer or appcast; editing the signed XML invalidates its signature.

Version 0.2.0 and earlier need one manual installation of 0.3.0 or later to gain the updater. Future updates preserve your settings and shortcuts. Downloads and installation always require approval; automatic installation and system profiling are disabled. The checkbox controls only scheduled checks and its value persists across launches.

For native update integration tests on disposable app copies, use an extracted, signed app:

```sh
python3 Tests/Updater/validate_update.py /path/to/extracted/ColdKey.app
```

This requires the local Developer ID certificate and ColdKey update signing key in Keychain. The tests use a loopback server, isolated preferences, and disposable copies under `.build/update-validation`; they never replace an installed app. They cover declining without downloading, manual checking with scheduled checks off, approval and installation, preference persistence, and rejection of tampered feeds and invalid archive signatures.

## Small by design

AppKit controls, Carbon system hotkey registration, NSWorkspace app activation, and public IOKit function-key settings. The function-row shortcut uses one event-driven keyboard filter in the existing process, with no polling; unrelated events pass through. Sparkle is the only runtime dependency; optional sandbox XPC services and development headers are omitted from the packaged framework. Update checks use Sparkle's daily scheduler, with no custom polling or always-running updater service. Release-note web views and system profiling are disabled. Accessibility is requested only for reserving the function-row shortcut in both modes. No Dock icon or window at launch. Bindings live in UserDefaults under the app's bundle identifier when running the app bundle. Sparkle's license and bundled notices are included in the app's Resources folder.
