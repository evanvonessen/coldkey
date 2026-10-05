import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let store = BindingStore()
    private let hotKeys = HotKeyManager()
    private var editor: ShortcutEditor?
    private var failures: [String] = []
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "command", accessibilityDescription: "Coldkey")
        statusItem.button?.toolTip = "Coldkey"
        hotKeys.onPress = { [weak self] id in self?.launch(id) }
        restoreShortcuts()
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
            let item = menu.addItem(withTitle: "\(binding.name)    \(binding.shortcut)", action: #selector(launchFromMenu(_:)), keyEquivalent: "")
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
        let quit = menu.addItem(withTitle: "Quit Coldkey", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"); quit.target = NSApp
        statusItem.menu = menu
    }
    private func launch(_ id: UUID) {
        guard let binding = store.bindings.first(where: { $0.id == id }) else { return }
        AppLauncher.run(binding) { [weak self] error in self?.showError(error) }
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
        controller.onSave = { [weak self] draft in
            guard let self else { return "Coldkey is unavailable." }
            if self.store.bindings.contains(where: { draft.conflicts(with: $0) }) { return "That shortcut is already assigned." }
            var bindings = self.store.bindings.filter { $0.id != draft.id }; bindings.append(draft)
            let errors = self.hotKeys.register(bindings)
            self.hotKeys.unregister()
            guard errors.isEmpty else { return errors.joined(separator: "\n") }
            do { try self.store.save(bindings); return nil } catch { return error.localizedDescription }
        }
        controller.onClose = { [weak self] in
            self?.editor = nil
            self?.restoreShortcuts()
        }
        editor = controller
        controller.showWindow(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc private func showFailures() { showError(failures.joined(separator: "\n")) }
    private func showError(_ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert(); alert.messageText = "Coldkey"; alert.informativeText = message; alert.runModal()
    }
}
