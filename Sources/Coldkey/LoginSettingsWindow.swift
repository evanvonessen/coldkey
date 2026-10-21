import AppKit

final class LoginSettingsWindow: NSWindowController, NSWindowDelegate {
    private let loginItem: LoginItemController
    private let checkbox = NSButton(checkboxWithTitle: "Start at login", target: nil, action: nil)
    private let message = NSTextField(wrappingLabelWithString: "")
    private let updates: UpdateChecking?
    private let updateCheckbox = NSButton(checkboxWithTitle: "Check for updates", target: nil, action: nil)
    private let updateMessage = NSTextField(wrappingLabelWithString: "")

    init(loginItem: LoginItemController = LoginItemController(), updates: UpdateChecking? = nil) {
        self.loginItem = loginItem
        self.updates = updates
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 470, height: 330),
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
        let credit = NSTextField(labelWithString: "Evan Von Essen")
        credit.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        credit.textColor = .secondaryLabelColor
        credit.alignment = .center
        credit.translatesAutoresizingMaskIntoConstraints = false
        let stack = NSStackView(views: [checkbox, message, settings, updateCheckbox, updateMessage])
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
    }

    func windowDidBecomeKey(_ notification: Notification) { refresh() }

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
}
