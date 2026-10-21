import AppKit

final class LoginSettingsWindow: NSWindowController, NSWindowDelegate {
    private let loginItem: LoginItemController
    private let checkbox = NSButton(checkboxWithTitle: "Start at login", target: nil, action: nil)
    private let message = NSTextField(wrappingLabelWithString: "")
    private let updates: UpdateChecking?
    private let updateCheckbox = NSButton(checkboxWithTitle: "Check for updates", target: nil, action: nil)
    private let updateMessage = NSTextField(wrappingLabelWithString: "")
    private let functionRowStatus: (() -> (active: Bool, permitted: Bool))?
    private let requestFunctionRowPermission: () -> Void
    private let openAccessibilitySettings: () -> Void
    private let functionRowMessage = NSTextField(wrappingLabelWithString: "")
    private let functionRowButton = NSButton(title: "Allow Function Row Shortcut…", target: nil, action: nil)
    var onFunctionRowPermissionChange: (() -> Void)?

    init(loginItem: LoginItemController = LoginItemController(), updates: UpdateChecking? = nil,
         functionRowShortcut: FunctionRowShortcutFilter? = nil,
         functionRowStatus: (() -> (active: Bool, permitted: Bool))? = nil,
         requestFunctionRowPermission: @escaping () -> Void = { FunctionRowShortcutFilter.requestPermission() },
         openAccessibilitySettings: @escaping () -> Void = {
             NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
         }) {
        self.loginItem = loginItem
        self.updates = updates
        let status = functionRowStatus ?? functionRowShortcut.map { filter in
            { (active: filter.isActive, permitted: FunctionRowShortcutFilter.hasPermission) }
        }
        self.functionRowStatus = status
        self.requestFunctionRowPermission = requestFunctionRowPermission
        self.openAccessibilitySettings = openAccessibilitySettings
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 470, height: status == nil ? 330 : 450),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        super.init(window: window)
        window.title = "ColdKey Settings"
        window.isReleasedWhenClosed = false
        window.delegate = self
        checkbox.allowsMixedState = true
        checkbox.target = self
        checkbox.action = #selector(toggleLoginItem)
        message.textColor = .secondaryLabelColor
        message.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        let settings = NSButton(title: "Open Login Items…", target: self, action: #selector(openLoginItems))
        settings.bezelStyle = .rounded
        updateCheckbox.target = self
        updateCheckbox.action = #selector(toggleUpdates)
        updateCheckbox.toolTip = "Check for new versions once a day. You decide when to download and install."
        updateMessage.textColor = .secondaryLabelColor
        updateMessage.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        functionRowMessage.textColor = .secondaryLabelColor
        functionRowMessage.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        functionRowButton.target = self
        functionRowButton.action = #selector(allowFunctionRowShortcut)
        functionRowButton.bezelStyle = .rounded
        let credit = NSTextField(labelWithString: "Evan Von Essen")
        credit.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        credit.textColor = .secondaryLabelColor
        credit.alignment = .center
        credit.translatesAutoresizingMaskIntoConstraints = false
        var controls: [NSView] = [checkbox, message, settings, updateCheckbox, updateMessage]
        if self.functionRowStatus != nil { controls += [functionRowMessage, functionRowButton] }
        let stack = NSStackView(views: controls)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        let content = window.contentView!
        content.addSubview(stack)
        content.addSubview(credit)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: credit.topAnchor, constant: -20),
            message.widthAnchor.constraint(equalTo: stack.widthAnchor),
            updateMessage.widthAnchor.constraint(equalTo: stack.widthAnchor),
            credit.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            credit.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -18)
        ])
        if self.functionRowStatus != nil {
            functionRowMessage.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        refresh()
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func refresh() {
        loginItem.refresh()
        switch loginItem.status {
        case .enabled: checkbox.state = .on
        case .requiresApproval: checkbox.state = .mixed
        case .notRegistered, .notFound, .unknown: checkbox.state = .off
        }
        checkbox.isEnabled = loginItem.canToggle
        message.stringValue = loginItem.message
        message.textColor = loginItem.errorMessage == nil ? .secondaryLabelColor : .systemRed
        updateCheckbox.state = updates?.automaticallyChecksForUpdates == true ? .on : .off
        updateCheckbox.isEnabled = updates?.isAvailable == true
        updateMessage.stringValue = updates?.message ?? "Run the packaged ColdKey app to check for updates."
        if let status = functionRowStatus?() {
            if status.active {
                functionRowMessage.stringValue = "Function row shortcut is active across apps in both row modes. Accessibility allows ColdKey to reserve this shortcut."
            } else if status.permitted {
                functionRowMessage.stringValue = "Accessibility is allowed, but the function row shortcut is inactive. Check ColdKey in Accessibility, then reopen ColdKey if needed."
            } else {
                functionRowMessage.stringValue = "Allow Accessibility to reserve the function row shortcut across apps in both row modes."
            }
            functionRowButton.title = status.permitted ? "Open Accessibility Settings…" : "Allow Function Row Shortcut…"
        }
    }

    func windowDidBecomeKey(_ notification: Notification) {
        onFunctionRowPermissionChange?()
        refresh()
    }

    @objc private func toggleLoginItem() {
        loginItem.refresh()
        // A pending (mixed) request can be cancelled, without registering it again.
        loginItem.setEnabled(!loginItem.status.isRegistered)
        refresh()
    }

    @objc private func openLoginItems() { loginItem.openSettings() }

    @objc private func toggleUpdates() {
        updates?.automaticallyChecksForUpdates = updateCheckbox.state == .on
        refresh()
    }

    @objc private func allowFunctionRowShortcut() {
        if functionRowStatus?().permitted == true { openAccessibilitySettings() }
        else { requestFunctionRowPermission() }
        onFunctionRowPermissionChange?()
        refresh()
    }
}
