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
        guard !flags.contains(.shift), flags.intersection([.command, .option, .control]).isEmpty == false else {
            NSSound.beep(); return
        }
        let modifiers = (flags.contains(.command) ? UInt32(cmdKey) : 0) |
            (flags.contains(.option) ? UInt32(optionKey) : 0) |
            (flags.contains(.control) ? UInt32(controlKey) : 0)
        let special: [UInt16: String] = [36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 117: "⌦", 123: "←", 124: "→", 125: "↓", 126: "↑", 115: "Home", 119: "End", 116: "Page Up", 121: "Page Down"]
        let label = special[event.keyCode] ?? event.charactersIgnoringModifiers?.uppercased() ?? "Key \(event.keyCode)"
        onRecord?(UInt32(event.keyCode), modifiers, label)
        window?.makeFirstResponder(nil)
    }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard window?.firstResponder === self else { return false }
        keyDown(with: event)
        return true
    }
}

final class ShortcutEditor: NSWindowController, NSWindowDelegate {
    private var draft: Binding
    private let appButton = NSButton(title: "Choose Application…", target: nil, action: nil)
    private let recorder = ShortcutRecorder(title: "Record Shortcut", target: nil, action: nil)
    private let hide = NSButton(checkboxWithTitle: "Hide app when it is already in front", target: nil, action: nil)
    private let hideInBackground = NSButton(checkboxWithTitle: "Hide even when not frontmost", target: nil, action: nil)
    private let message = NSTextField(wrappingLabelWithString: "")
    var onSave: ((Binding) -> String?)?
    var onClose: (() -> Void)?
    init(binding: Binding?) {
        draft = binding ?? Binding(appPath: "", keyCode: 0, modifiers: 0, keyLabel: "", hideOnRepeat: false)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 410, height: 300), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        super.init(window: window)
        window.title = binding == nil ? "Add Shortcut" : "Edit Shortcut"
        window.delegate = self
        window.isReleasedWhenClosed = false
        appButton.target = self; appButton.action = #selector(chooseApp)
        appButton.bezelStyle = .rounded
        recorder.bezelStyle = .rounded
        if let binding { appButton.title = binding.name; recorder.title = binding.shortcut }
        hide.state = draft.hideOnRepeat ? .on : .off
        hideInBackground.state = draft.hideWhenNotFrontmost ? .on : .off
        hideInBackground.toolTip = "Hide this app whenever it is visible. Press the shortcut again to show it."
        recorder.onRecord = { [weak self] code, modifiers, label in
            guard let self else { return }
            self.draft.keyCode = code; self.draft.modifiers = modifiers; self.draft.keyLabel = label
            self.recorder.title = self.draft.shortcut
        }
        let hint = NSTextField(wrappingLabelWithString: "Use ⌘ Command, ⌥ Option or ⌃ Control with one key.")
        hint.font = .systemFont(ofSize: 11); hint.textColor = .secondaryLabelColor
        message.font = .systemFont(ofSize: 11); message.textColor = .systemRed
        let save = NSButton(title: "Save", target: self, action: #selector(saveBinding)); save.bezelStyle = .rounded; save.keyEquivalent = "\r"
        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancelEditing)); cancel.bezelStyle = .rounded; cancel.keyEquivalent = "\u{1b}"
        let buttons = NSStackView(views: [cancel, save]); buttons.orientation = .horizontal
        let stack = NSStackView(views: [appButton, recorder, hint, hide, hideInBackground, message, buttons])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 20), stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -20), stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 20)])
        window.center()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        panel.beginSheetModal(for: window!) { [weak self] response in
            guard response == .OK, let url = panel.url, let self else { return }
            self.draft.appPath = url.path; self.appButton.title = self.draft.name
        }
    }
    @objc private func saveBinding() {
        guard !draft.appPath.isEmpty, draft.modifiers != 0 else { message.stringValue = "Choose an application and record a shortcut."; return }
        draft.hideOnRepeat = hide.state == .on
        draft.hideWhenNotFrontmost = hideInBackground.state == .on
        if let error = onSave?(draft) { message.stringValue = error } else { close() }
    }
    @objc private func cancelEditing() { close() }
    func windowWillClose(_ notification: Notification) { onClose?() }
}
