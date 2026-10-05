# Coldkey

A tiny, native macOS menu bar app inspired by HotKey. Requires macOS 13 or later.

- Click the **⌘** menu bar icon → **Add Shortcut…**.
- Choose an application and record Command, Option, and/or Control plus one key.
- Enable **Hide app when it is already in front** to toggle between showing and hiding it.
- Launch apps from the menu, or edit/remove bindings under **Manage Shortcuts**.

Shortcuts are saved locally and restored on launch. Existing shortcuts pause while the editor is open so you can record them. Conflicts reported by macOS are shown instead of silently accepting a broken shortcut. System-reserved shortcuts may be intercepted by macOS; choose another combination if necessary.

## Build and run

Requires the Swift tools included with Xcode or its Command Line Tools.

```sh
./scripts/build-app.sh
open .build/Coldkey.app
```

Copy `.build/Coldkey.app` to Applications if desired. The build is locally ad-hoc signed; distribution signing and notarization are not configured. Open `Package.swift` in Xcode for development.

```sh
swift test
```

## Small by design

AppKit controls, Carbon system hotkey registration, and NSWorkspace app activation. No third-party dependencies, web views, polling, network calls, Accessibility permission, or background service. No Dock icon or window at launch. Bindings live in UserDefaults under `com.evanvonessen.coldkey` when running the app bundle.
