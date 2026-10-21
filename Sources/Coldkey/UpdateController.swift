import AppKit
import Sparkle

protocol UpdateChecking: AnyObject {
    var automaticallyChecksForUpdates: Bool { get set }
    var isAvailable: Bool { get }
    var message: String { get }
}

final class UpdateController: NSObject, UpdateChecking, NSMenuItemValidation, SPUStandardUserDriverDelegate {
    private lazy var controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: self)
    private(set) var isAvailable = false
    private(set) var updateAvailable = false
    private var startupError: String?
    var onChange: (() -> Void)?

    func start() {
        guard !isAvailable else { return }
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            startupError = "Run the packaged ColdKey app to check for updates."
            return
        }
        do {
            try controller.updater.start()
            isAvailable = true
        } catch {
            startupError = "Updates are unavailable: \(error.localizedDescription)"
        }
        onChange?()
    }

    var automaticallyChecksForUpdates: Bool {
        get { isAvailable && controller.updater.automaticallyChecksForUpdates }
        set {
            guard isAvailable, newValue != controller.updater.automaticallyChecksForUpdates else { return }
            // Sparkle persists this preference and schedules/cancels the daily check.
            controller.updater.automaticallyChecksForUpdates = newValue
            onChange?()
        }
    }

    var message: String {
        startupError ?? "Checks once a day. Downloads and installation require your approval."
    }

    @objc func checkForUpdates(_ sender: Any?) {
        guard isAvailable, controller.updater.canCheckForUpdates else { return }
        NSApp.activate(ignoringOtherApps: true)
        controller.checkForUpdates(sender)
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        isAvailable && controller.updater.canCheckForUpdates
    }

    // A scheduled check adds a quiet menu reminder; it never steals focus or downloads an update.
    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool) -> Bool {
        false
    }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        updateAvailable = !handleShowingUpdate
        onChange?()
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        updateAvailable = false
        onChange?()
    }

    func standardUserDriverWillFinishUpdateSession() {
        updateAvailable = false
        onChange?()
    }
}
