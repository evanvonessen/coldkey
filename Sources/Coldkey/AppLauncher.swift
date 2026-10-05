import AppKit

enum AppLauncher {
    static func shouldHide(_ binding: Binding, isActive: Bool, isHidden: Bool) -> Bool {
        !isHidden && (binding.hideWhenNotFrontmost || (binding.hideOnRepeat && isActive))
    }

    static func run(_ binding: Binding, onError: @escaping (String) -> Void) {
        let url = URL(fileURLWithPath: binding.appPath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            onError("\(binding.name) could not be found. Edit its shortcut and choose the app again.")
            return
        }
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleURL?.standardizedFileURL == url.standardizedFileURL }) {
            if shouldHide(binding, isActive: app.isActive, isHidden: app.isHidden) { app.hide() }
            else { app.unhide(); app.activate(options: [.activateIgnoringOtherApps]) }
        } else {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
                if let error { DispatchQueue.main.async { onError(error.localizedDescription) } }
            }
        }
    }
}
