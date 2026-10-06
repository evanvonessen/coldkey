import AppKit

final class LoginSettingsWindow: NSWindowController, NSWindowDelegate {
    private let loginItem: LoginItemController
    private let checkbox = NSButton(checkboxWithTitle: "Start at login", target: nil, action: nil)
    private let message = NSTextField(wrappingLabelWithString: "")

    init(loginItem: LoginItemController = LoginItemController()) {
        self.loginItem = loginItem
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 470, height: 210),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        super.init(window: window)
        window.title = "Coldkey Settings"
        window.isReleasedWhenClosed = false
        window.delegate = self
        checkbox.allowsMixedState = true
        checkbox.target = self
        checkbox.action = #selector(toggleLoginItem)
        message.textColor = .secondaryLabelColor
        message.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        let settings = NSButton(title: "Open Login Items…", target: self, action: #selector(openLoginItems))
        settings.bezelStyle = .rounded
        let stack = NSStackView(views: [checkbox, message, settings])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        let content = window.contentView!
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -24),
            message.widthAnchor.constraint(equalTo: stack.widthAnchor)
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
    }

    func windowDidBecomeKey(_ notification: Notification) { refresh() }

    @objc private func toggleLoginItem() {
        loginItem.refresh()
        // A pending (mixed) request can be cancelled, without registering it again.
        loginItem.setEnabled(!loginItem.status.isRegistered)
        refresh()
    }

    @objc private func openLoginItems() { loginItem.openSettings() }
}
