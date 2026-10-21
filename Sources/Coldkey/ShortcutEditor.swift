import AppKit
import Carbon
import UniformTypeIdentifiers

final class ShortcutRecorder: NSButton {
    var onRecord: ((UInt32, UInt32, String) -> Void)?
    override var acceptsFirstResponder: Bool { true }
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        title = "Press shortcut…"
    }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { window?.makeFirstResponder(nil); return }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let modifiers = (flags.contains(.command) ? UInt32(cmdKey) : 0) |
            (flags.contains(.option) ? UInt32(optionKey) : 0) |
            (flags.contains(.control) ? UInt32(controlKey) : 0)
        guard !flags.contains(.shift), ShortcutKey.isValid(keyCode: UInt32(event.keyCode), modifiers: modifiers) else {
            NSSound.beep(); return
        }
        let special: [UInt16: String] = [36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 117: "⌦", 123: "←", 124: "→", 125: "↓", 126: "↑", 115: "Home", 119: "End", 116: "Page Up", 121: "Page Down"]
        let label = ShortcutKey.functionKeyLabels[UInt32(event.keyCode)] ?? special[event.keyCode] ?? event.charactersIgnoringModifiers?.uppercased() ?? "Key \(event.keyCode)"
        record(code: UInt32(event.keyCode), modifiers: modifiers, label: label)
    }
    func record(code: UInt32, modifiers: UInt32, label: String) {
        guard ShortcutKey.isValid(keyCode: code, modifiers: modifiers) else { NSSound.beep(); return }
        onRecord?(code, modifiers, label)
        window?.makeFirstResponder(nil)
    }
    func recordMediaEvent(_ event: NSEvent) -> Bool {
        guard let code = FunctionRowInput.keyCode(forMediaEvent: event) else { return false }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !flags.contains(.shift) else { NSSound.beep(); return true }
        let modifiers = (flags.contains(.command) ? UInt32(cmdKey) : 0) |
            (flags.contains(.option) ? UInt32(optionKey) : 0) |
            (flags.contains(.control) ? UInt32(controlKey) : 0)
        record(code: code, modifiers: modifiers, label: ShortcutKey.functionKeyLabels[code] ?? "Key \(code)")
        return true
    }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard window?.firstResponder === self else { return false }
        keyDown(with: event)
        return true
    }
}

private final class ShortcutEditorWindow: NSWindow {
    override func sendEvent(_ event: NSEvent) {
        if event.type == .systemDefined, let recorder = firstResponder as? ShortcutRecorder,
           recorder.recordMediaEvent(event) { return }
        super.sendEvent(event)
    }
}

final class ShortcutEditor: NSWindowController, NSWindowDelegate {
    private var draft: Binding
    private let targetType = NSSegmentedControl(labels: ["Application", "Folder", "Function Row"], trackingMode: .selectOne, target: nil, action: nil)
    private let appButton = NSButton(title: "Choose Application…", target: nil, action: nil)
    private let recorder = ShortcutRecorder(title: "Record Shortcut", target: nil, action: nil)
    private let hide = NSButton(checkboxWithTitle: "Hide app when it is already in front", target: nil, action: nil)
    private let hideInBackground = NSButton(checkboxWithTitle: "Hide even when not frontmost", target: nil, action: nil)
    private let closeFolder = NSButton(checkboxWithTitle: "Close folder window when it is already in front", target: nil, action: nil)
    private let closeFolderInBackground = NSButton(checkboxWithTitle: "Close even when not frontmost", target: nil, action: nil)
    private let folderHint = NSTextField(wrappingLabelWithString: "Closes only one matching Finder window. Other windows stay open. Finder control permission is requested when you first use this shortcut.")
    private let hint = NSTextField(wrappingLabelWithString: "")
    private let message = NSTextField(wrappingLabelWithString: "")
    var onSave: ((Binding) -> String?)?
    var onClose: (() -> Void)?
    init(binding: Binding?) {
        draft = binding ?? Binding(appPath: "", keyCode: 0, modifiers: 0, keyLabel: "", hideOnRepeat: false)
        let window = ShortcutEditorWindow(contentRect: NSRect(x: 0, y: 0, width: 450, height: 390), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        super.init(window: window)
        window.title = binding == nil ? "Add Shortcut" : "Edit Shortcut"
        window.delegate = self
        window.isReleasedWhenClosed = false
        switch draft.targetKind {
        case .application: targetType.selectedSegment = 0
        case .folder: targetType.selectedSegment = 1
        case .functionRow: targetType.selectedSegment = 2
        }
        targetType.target = self; targetType.action = #selector(changeTargetType)
        appButton.target = self; appButton.action = #selector(chooseTarget)
        appButton.bezelStyle = .rounded
        recorder.bezelStyle = .rounded
        if let binding { appButton.title = binding.name; recorder.title = binding.shortcut }
        hide.state = draft.hideOnRepeat ? .on : .off
        hideInBackground.state = draft.hideWhenNotFrontmost ? .on : .off
        hideInBackground.toolTip = "Hide this app whenever it is visible. Press the shortcut again to show it."
        closeFolder.state = draft.closeFolderOnRepeat ? .on : .off
        closeFolder.toolTip = "Close only when this folder's window is the frontmost Finder window and Finder is the active app. Otherwise, bring it forward."
        closeFolderInBackground.state = draft.closeFolderWhenNotFrontmost ? .on : .off
        closeFolderInBackground.toolTip = "Close one matching folder window even when another app or Finder window is in front."
        folderHint.font = .systemFont(ofSize: 11); folderHint.textColor = .secondaryLabelColor
        recorder.onRecord = { [weak self] code, modifiers, label in
            guard let self else { return }
            self.draft.keyCode = code; self.draft.modifiers = modifiers; self.draft.keyLabel = label
            self.recorder.title = self.draft.shortcut
        }
        hint.font = .systemFont(ofSize: 11); hint.textColor = .secondaryLabelColor
        message.font = .systemFont(ofSize: 11); message.textColor = .systemRed
        let save = NSButton(title: "Save", target: self, action: #selector(saveBinding)); save.bezelStyle = .rounded; save.keyEquivalent = "\r"
        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancelEditing)); cancel.bezelStyle = .rounded; cancel.keyEquivalent = "\u{1b}"
        let buttons = NSStackView(views: [cancel, save]); buttons.orientation = .horizontal
        let stack = NSStackView(views: [targetType, appButton, recorder, hint, hide, hideInBackground, closeFolder, closeFolderInBackground, folderHint, message, buttons])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 12
        stack.detachesHiddenViews = true
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 20), stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -20), stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 20)])
        updateTargetControls()
        window.center()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    private func updateTargetControls() {
        let folder = draft.targetKind == .folder
        let functionRow = draft.targetKind == .functionRow
        appButton.isHidden = functionRow
        hide.isHidden = folder || functionRow; hideInBackground.isHidden = folder || functionRow
        closeFolder.isHidden = !folder; closeFolderInBackground.isHidden = !folder; folderHint.isHidden = !folder
        appButton.title = draft.appPath.isEmpty ? (folder ? "Choose Folder…" : "Choose Application…") : draft.name
        appButton.toolTip = draft.appPath.isEmpty ? nil : draft.appPath
        hint.stringValue = functionRow
            ? "Switches between icon controls and standard function keys globally. This shortcut is reserved for ColdKey in both modes until changed or removed. Use F1, F2, F7–F20, or a modified letter or other key."
            : "Use F1–F20 alone, or ⌘ Command, ⌥ Option or ⌃ Control with one key."
        recorder.toolTip = functionRow
            ? "Record a shortcut to toggle the function row in every app. ⌘F12 works in both row modes."
            : "If a function key changes brightness or volume, enable standard function keys in System Settings → Keyboard → Keyboard Shortcuts → Function Keys."
    }
    @objc private func changeTargetType() {
        let kind: Binding.TargetKind = targetType.selectedSegment == 2 ? .functionRow : (targetType.selectedSegment == 1 ? .folder : .application)
        guard kind != draft.targetKind else { return }
        draft.targetKind = kind; draft.appPath = ""; draft.folderBookmark = nil
        message.stringValue = ""
        updateTargetControls()
    }
    func selectTarget(_ url: URL?) {
        guard draft.targetKind != .functionRow, let url else { return }
        do {
            if draft.targetKind == .folder { draft = try FolderLocation.select(url, for: draft) }
            else { draft.appPath = url.path; draft.folderBookmark = nil }
            message.stringValue = ""
            updateTargetControls()
        } catch { message.stringValue = "Cannot use that folder. Choose an accessible folder and try again." }
    }
    @objc private func chooseTarget() {
        let panel = NSOpenPanel()
        let folder = draft.targetKind == .folder
        if !folder { panel.allowedContentTypes = [.applicationBundle] }
        panel.directoryURL = folder ? FileManager.default.homeDirectoryForCurrentUser : URL(fileURLWithPath: "/Applications")
        panel.canChooseFiles = !folder; panel.canChooseDirectories = folder
        panel.treatsFilePackagesAsDirectories = false; panel.allowsMultipleSelection = false
        panel.beginSheetModal(for: window!) { [weak self] response in
            guard response == .OK else { return }
            self?.selectTarget(panel.url)
        }
    }
    @objc private func saveBinding() {
        let functionRow = draft.targetKind == .functionRow
        guard (functionRow || !draft.appPath.isEmpty), !draft.keyLabel.isEmpty,
              ShortcutKey.isValid(keyCode: draft.keyCode, modifiers: draft.modifiers) else {
            message.stringValue = functionRow ? "Record a shortcut to toggle the function row." : "Choose an application or folder and record a shortcut."
            return
        }
        guard !functionRow || FunctionRowInput.supports(binding: draft) else {
            message.stringValue = "Choose F1, F2, F7–F20, or a modified letter or other key so the shortcut works in both function-row modes."
            return
        }
        draft.hideOnRepeat = hide.state == .on
        draft.hideWhenNotFrontmost = hideInBackground.state == .on
        draft.closeFolderOnRepeat = closeFolder.state == .on
        draft.closeFolderWhenNotFrontmost = closeFolderInBackground.state == .on
        if let error = onSave?(draft) { message.stringValue = error } else { close() }
    }
    func recordReservedShortcut(_ binding: Binding) -> Bool {
        guard window?.firstResponder === recorder else { return false }
        recorder.record(code: binding.keyCode, modifiers: binding.modifiers, label: binding.keyLabel)
        return true
    }
    @objc private func cancelEditing() { close() }
    func windowWillClose(_ notification: Notification) { onClose?() }
}
