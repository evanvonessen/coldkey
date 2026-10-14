# Coldkey

A tiny, native macOS menu bar app inspired by HotKey. Requires macOS 13 or later.

- Click the **⌘** menu bar icon → **Add Shortcut…**.
- Choose an application and record Command, Option, and/or Control plus one key.
- Enable **Hide app when it is already in front** to toggle between showing and hiding it.
- Or enable **Hide even when not frontmost** to hide a visible app even while another app is in front. Press again to show it. This separate option is off by default and works on its own or with the original option.
- Launch apps from the menu, or edit/remove bindings under **Manage Shortcuts**.
- Open **Settings…** from the ⌘ menu for **Start at login**. It is off for a new installation and changes only when you click it. Run the signed app from `/Applications` or `~/Applications` before enabling it; development copies in `.build` cannot be enabled. A dash means macOS requires approval: choose **Open Login Items…** to approve it in System Settings, or clear the checkbox to cancel. The checkbox reads macOS’s saved status when Settings opens or Coldkey becomes active, including changes made in System Settings. Registration errors are shown without claiming the change succeeded.
- Choose **Folder** in the editor to bind a directory. **Close folder window when it is already in front** closes the matching window only when Finder is active and that exact window is in front; otherwise it brings the window forward. **Close even when not frontmost** also closes a matching window behind another app or Finder window. With both off, the shortcut opens or raises the folder. With both on, the second option takes precedence. If several windows match, only the frontmost matching window is affected. These actions close windows, never delete folders or hide Finder.

Shortcuts are saved locally and restored on launch. They use exclusive native hotkey registration to take precedence over ordinary foreground-app shortcuts. Holding a shortcut triggers it once until you release the key. Existing shortcuts pause while the editor is open so you can record them. Conflicts are shown and prevent saving an unavailable shortcut; saved shortcuts that cannot register at launch are marked unavailable. macOS-reserved shortcuts, secure input, and shortcuts owned by another global tool can prevent registration or delivery. Coldkey cannot override those protections; choose another combination or release the shortcut in the other tool.

Both hide options apply to the whole app, including all its windows. Hidden apps are shown and activated; apps that are not running are launched. Existing shortcuts keep their previous hide setting when updating.

Folder selections use saved bookmarks to follow moves and renames across restarts. If a folder is missing or inaccessible, choose it again. New folder shortcuts have both close options off. Existing folder shortcuts retain their behavior: the old close option migrates to **Close even when not frontmost**; old open-only shortcuts keep both off. The first folder action explains and requests macOS permission to control Finder; you can cancel or manage it in **System Settings → Privacy & Security → Automation**. No Accessibility permission is needed. Finder exposes a window's current folder, so a folder in an inactive tab is not treated as a matching window.

## Install the packaged app

[Download Coldkey.dmg](https://github.com/evanvonessen/coldkey/raw/refs/heads/main/dist/Coldkey.dmg). The package supports Apple Silicon and Intel Macs running macOS 13 or later; no developer tools are needed to install it.

Quit any running Coldkey and double-click the DMG. It opens a compact installer window with the original Coldkey icon on the left, an arrow, and Applications on the right. Drag **Coldkey** onto **Applications**, then eject the disk and open Coldkey from Applications. Look for **⌘** in the menu bar. Updating keeps your saved shortcuts.

To offer it on your website, upload `dist/Coldkey.dmg` and link directly to that file. Visitors download and open the DMG; they do not need GitHub access, source files, or developer tools. This repository is private, so its GitHub download link requires repository access.

This build is ad-hoc signed and is not notarized. If macOS blocks it, try opening the installed app once, then choose **System Settings → Privacy & Security → Open Anyway** and confirm opening it.

The installer and its [SHA-256 checksum](dist/Coldkey.dmg.sha256) are saved in `dist/`. To verify a download, place both files in the same folder and run `shasum -a 256 -c Coldkey.dmg.sha256` there. See the [validation record](dist/VALIDATION.md) for checks and remaining test limits.

## Build and run

Requires the Swift tools included with Xcode or its Command Line Tools.

For updates, pull the latest changes, then double-click **Build and Run.command** in the project folder. It builds, safely quits the previous Coldkey, and launches the new local app with your saved shortcuts. It does not pull changes or overwrite a copy in Applications. If something fails, the Terminal window stays open with the error.

```sh
./scripts/build-app.sh
open .build/Coldkey.app
```

Copy `.build/Coldkey.app` to Applications if desired. The build is locally ad-hoc signed; distribution signing and notarization are not configured. Open `Package.swift` in Xcode for development.

The build packages the original HotKey by codenuts app icon at standard and Retina sizes. The menu bar keeps its monochrome ⌘ symbol. Icon sources and provenance are in [Assets](Assets/README.md).

```sh
swift test
```

## Build the DMG

```sh
./scripts/build-dmg.sh
```

This builds the current source for Apple Silicon and Intel, checks the app signature, and creates and verifies a compressed, read-only `dist/Coldkey.dmg` with a saved Finder icon layout, installation arrow, and Applications shortcut. Only the two drag-and-drop icons appear in the installer window. It also writes `dist/Coldkey.dmg.sha256`. Commit both distribution files when publishing an updated installer.

DMG creation also requires Python 3.9 or later. The first run installs pinned `dmgbuild` packaging tools into the ignored `.build/dmg-tools` environment; later runs reuse them. These are build tools only: the installed app contains no Python or third-party runtime dependencies. The script leaves the running app and installed copies alone.

## Small by design

AppKit controls, Carbon system hotkey registration, and NSWorkspace app activation. No third-party dependencies, web views, polling, network calls, Accessibility permission, or background service. No Dock icon or window at launch. Bindings live in UserDefaults under `com.evanvonessen.coldkey` when running the app bundle.
