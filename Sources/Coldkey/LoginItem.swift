import Foundation
import ServiceManagement

enum LoginItemStatus: Equatable {
    case notRegistered, enabled, requiresApproval, notFound, unknown

    var isRegistered: Bool { self == .enabled || self == .requiresApproval }
}

protocol LoginItemServicing {
    var status: LoginItemStatus { get }
    func register() throws
    func unregister() throws
    func openSettings()
}

struct SystemLoginItem: LoginItemServicing {
    var status: LoginItemStatus {
        switch SMAppService.mainApp.status {
        case .notRegistered: return .notRegistered
        case .enabled: return .enabled
        case .requiresApproval: return .requiresApproval
        case .notFound: return .notFound
        @unknown default: return .unknown
        }
    }
    func register() throws { try SMAppService.mainApp.register() }
    func unregister() throws { try SMAppService.mainApp.unregister() }
    func openSettings() { SMAppService.openSystemSettingsLoginItems() }
}

enum LoginItemInstallation {
    static func problem(bundleURL: URL = Bundle.main.bundleURL,
                        bundleIdentifier: String? = Bundle.main.bundleIdentifier,
                        applicationDirectories: [URL] = [
                            URL(fileURLWithPath: "/Applications", isDirectory: true),
                            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
                        ]) -> String? {
        let app = bundleURL.resolvingSymlinksInPath().standardizedFileURL
        let installed = applicationDirectories.contains { directory in
            let root = directory.resolvingSymlinksInPath().standardizedFileURL.path + "/"
            guard app.path.hasPrefix(root) else { return false }
            // Do not register disposable build bundles, even inside an Applications subfolder.
            return !app.path.dropFirst(root.count).split(separator: "/").contains { $0.hasPrefix(".") }
        }
        guard bundleIdentifier == "com.evanvonessen.coldkey", app.pathExtension == "app", installed else {
            return "Move Coldkey.app to Applications (or your home folder’s Applications folder), quit this copy, and open the installed copy to enable Start at login."
        }
        return nil
    }
}

final class LoginItemController {
    private let service: LoginItemServicing
    private let installationProblem: () -> String?
    private(set) var status: LoginItemStatus
    private(set) var errorMessage: String?

    init(service: LoginItemServicing = SystemLoginItem(),
         installationProblem: @escaping () -> String? = { LoginItemInstallation.problem() }) {
        self.service = service
        self.installationProblem = installationProblem
        self.status = service.status
        // macOS owns the persistent preference. Opening Coldkey never registers it.
    }

    var canToggle: Bool { status.isRegistered || (status != .unknown && installationProblem() == nil) }

    var message: String {
        if let errorMessage { return errorMessage }
        switch status {
        case .enabled: return "Coldkey will start when you sign in."
        case .requiresApproval:
            return "Waiting for approval in System Settings. Open Login Items to allow Coldkey, or clear this checkbox to cancel the request."
        case .notRegistered:
            return installationProblem() ?? "Off. Coldkey will not start automatically."
        case .notFound:
            return installationProblem() ?? "macOS could not find Coldkey’s login item. Try enabling it again from the installed app."
        case .unknown:
            return "macOS could not report the login-item status. Check Login Items in System Settings."
        }
    }

    func refresh() {
        let current = service.status
        if current != status { errorMessage = nil }
        status = current
    }

    func setEnabled(_ enabled: Bool) {
        refresh()
        errorMessage = nil
        guard status != .unknown else {
            errorMessage = "macOS could not report the login-item status. Check Login Items in System Settings before changing it."
            return
        }
        if enabled {
            guard !status.isRegistered else { return }
            if let problem = installationProblem() { errorMessage = problem; return }
        } else if status == .notRegistered { return }

        var failure: String?
        do {
            if enabled { try service.register() } else { try service.unregister() }
        } catch {
            failure = "Could not \(enabled ? "enable" : "turn off") Start at login. \(error.localizedDescription) Check Login Items in System Settings."
        }
        // Never show a requested value as saved when macOS rejected or deferred it.
        status = service.status
        errorMessage = failure
        if failure == nil && (enabled ? !status.isRegistered : status != .notRegistered) {
            errorMessage = "macOS has not confirmed the change. Check Login Items in System Settings and try again."
        }
    }

    func openSettings() { service.openSettings() }
}
