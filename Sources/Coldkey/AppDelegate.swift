import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let store: BindingStore
    private let hotKeys: HotKeyManager
    private let folders = FolderLauncher()
    private var folderActionInProgress = false
    private var editor: ShortcutEditor?
    private var settings: LoginSettingsWindow?
    private lazy var updates = UpdateController()
    private var failures: [String] = []
    init(store: BindingStore = BindingStore(), hotKeys: HotKeyManager = HotKeyManager()) {
        self.store = store; self.hotKeys = hotKeys
        super.init()
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "command", accessibilityDescription: "ColdKey")
        statusItem.button?.toolTip = "ColdKey"
        hotKeys.onPress = { [weak self] id in self?.launch(id) }
        restoreShortcuts()
        updates.onChange = { [weak self] in
            self?.rebuildMenu()
            self?.settings?.refresh()
        }
        updates.start()
    }
    private func restoreShortcuts() {
        failures = hotKeys.register(store.bindings)
        rebuildMenu()
    }
    private func rebuildMenu() {
        let menu = NSMenu()
        if store.bindings.isEmpty {
            let empty = menu.addItem(withTitle: "No shortcuts yet", action: nil, keyEquivalent: "")
            empty.isEnabled = false
        }
        for binding in store.bindings {
            let unavailable = hotKeys.registeredIDs.contains(binding.id) ? "" : " — shortcut unavailable"
            let item = menu.addItem(withTitle: "\(binding.name)    \(binding.shortcut)\(unavailable)", action: #selector(launchFromMenu(_:)), keyEquivalent: "")
            item.target = self; item.representedObject = binding.id
            let icon = NSWorkspace.shared.icon(forFile: binding.appPath); icon.size = NSSize(width: 16, height: 16); item.image = icon
        }
        menu.addItem(.separator())
        let add = menu.addItem(withTitle: "Add Shortcut…", action: #selector(addShortcut), keyEquivalent: "")
        add.target = self
        if !store.bindings.isEmpty {
            let editMenu = NSMenu()
            for binding in store.bindings {
                let item = editMenu.addItem(withTitle: binding.name, action: nil, keyEquivalent: "")
                let actions = NSMenu()
                for (title, action) in [("Edit…", #selector(editShortcut(_:))), ("Remove", #selector(removeShortcut(_:)))] {
                    let child = actions.addItem(withTitle: title, action: action, keyEquivalent: "")
                    child.target = self; child.representedObject = binding.id
                }
                item.submenu = actions
            }
            let edit = menu.addItem(withTitle: "Manage Shortcuts", action: nil, keyEquivalent: ""); edit.submenu = editMenu
        }
        if !failures.isEmpty {
            let warning = menu.addItem(withTitle: "Shortcut unavailable…", action: #selector(showFailures), keyEquivalent: "")
            warning.target = self
        }
        menu.addItem(.separator())
        let preferences = menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        preferences.target = self
        let update = menu.addItem(withTitle: updates.updateAvailable ? "Update Available…" : "Check for Updates…", action: #selector(UpdateController.checkForUpdates(_:)), keyEquivalent: "")
        update.target = updates
        let quit = menu.addItem(withTitle: "Quit ColdKey", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"); quit.target = NSApp
        statusItem.menu = menu
    }
    private func launch(_ id: UUID) {
        guard let binding = store.bindings.first(where: { $0.id == id }) else { return }
        if binding.targetKind == .folder {
            guard !folderActionInProgress else { return }
            folderActionInProgress = true
            FinderAutomation.checkPermission { [weak self] permission in
                guard let self else { return }
                do {
                    try permission.get()
                    defer { self.folderActionInProgress = false }
                    // The binding may have been edited or removed while permission was checked.
                    guard let current = self.store.bindings.first(where: { $0.id == id }), current.targetKind == .folder else { return }
                    let updated = try self.folders.run(current)
                    if updated != current {
                        try self.store.save(self.store.bindings.map { $0.id == id ? updated : $0 })
                        self.rebuildMenu()
                    }
                } catch FolderError.automationRequired { self.requestFinderPermission(for: id) }
                catch FolderError.automationDenied { self.folderActionInProgress = false; self.showFinderPermissionSettings() }
                catch { self.folderActionInProgress = false; self.showError(error.localizedDescription) }
            }
            return
        }
        AppLauncher.run(binding) { [weak self] error in self?.showError(error) }
    }
    private func requestFinderPermission(for id: UUID) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Allow ColdKey to control Finder?"
        alert.informativeText = "This lets your folder shortcuts open a folder or close one matching Finder window. macOS will ask for permission next."
        alert.addButton(withTitle: "Continue…"); alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { folderActionInProgress = false; return }
        FinderAutomation.checkPermission(askUser: true) { [weak self] result in
            guard let self else { return }
            self.folderActionInProgress = false
            do { try result.get(); self.launch(id) }
            catch { self.showError(error.localizedDescription) }
        }
    }
    private func showFinderPermissionSettings() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Finder control is not allowed"
        alert.informativeText = FolderError.automationDenied.localizedDescription
        alert.addButton(withTitle: "Open Settings"); alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }
    @objc private func launchFromMenu(_ sender: NSMenuItem) { if let id = sender.representedObject as? UUID { launch(id) } }
    @objc private func addShortcut() { openEditor(nil) }
    @objc private func editShortcut(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        openEditor(store.bindings.first { $0.id == id })
    }
    @objc private func removeShortcut(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        do { try store.save(store.bindings.filter { $0.id != id }); restoreShortcuts() }
        catch { showError(error.localizedDescription) }
    }
    private func openEditor(_ binding: Binding?) {
        if let editor { editor.showWindow(nil); NSApp.activate(ignoringOtherApps: true); return }
        hotKeys.unregister()
        let controller = ShortcutEditor(binding: binding)
        var saved = false
        controller.onSave = { [weak self] draft in
            guard let self else { return "ColdKey is unavailable." }
            let error = self.saveBinding(draft)
            saved = error == nil
            return error
        }
        controller.onClose = { [weak self] in
            self?.editor = nil
            if saved { self?.rebuildMenu() } else { self?.restoreShortcuts() }
        }
        editor = controller
        controller.showWindow(nil); NSApp.activate(ignoringOtherApps: true)
    }
    func saveBinding(_ draft: Binding) -> String? {
        if store.bindings.contains(where: { draft.conflicts(with: $0) }) { return "That shortcut is already assigned." }
        var bindings = store.bindings.filter { $0.id != draft.id }; bindings.append(draft)
        let errors = hotKeys.register(bindings)
        guard errors.isEmpty else { hotKeys.unregister(); return errors.joined(separator: "\n") }
        do {
            try store.save(bindings)
            // Hold successful registrations through save/close instead of releasing and reclaiming them.
            failures = []
            return nil
        } catch { hotKeys.unregister(); return error.localizedDescription }
    }
    @objc private func showFailures() { showError(failures.joined(separator: "\n")) }
    @objc private func openSettings() {
        let controller = settings ?? LoginSettingsWindow(updates: updates)
        settings = controller
        controller.refresh()
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationDidBecomeActive(_ notification: Notification) { settings?.refresh() }
    private func showError(_ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert(); alert.messageText = "ColdKey"; alert.informativeText = message; alert.runModal()
    }
}
