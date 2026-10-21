import AppKit
import XCTest
@testable import Coldkey

private final class FakeLoginItem: LoginItemServicing {
    var status: LoginItemStatus = .notRegistered
    var afterRegister: LoginItemStatus = .enabled
    var afterUnregister: LoginItemStatus = .notRegistered
    var registerError: Error?
    var unregisterError: Error?
    var registrations = 0
    var removals = 0
    var settingsOpened = 0
    func register() throws {
        registrations += 1
        if let registerError { throw registerError }
        status = afterRegister
    }
    func unregister() throws {
        removals += 1
        if let unregisterError { throw unregisterError }
        status = afterUnregister
    }
    func openSettings() { settingsOpened += 1 }
}

final class LoginItemTests: XCTestCase {
    func testFreshLaunchAndRefreshNeverRegisterOrOpenSettings() {
        let service = FakeLoginItem()
        let model = LoginItemController(service: service, installationProblem: { nil })
        model.refresh()
        XCTAssertEqual(model.status, .notRegistered)
        XCTAssertEqual(service.registrations, 0)
        XCTAssertEqual(service.removals, 0)
        XCTAssertEqual(service.settingsOpened, 0)
    }

    func testEnableDisableAndRelaunchUseSystemPreference() {
        let service = FakeLoginItem()
        let model = LoginItemController(service: service, installationProblem: { nil })
        model.setEnabled(true)
        XCTAssertEqual(model.status, .enabled)
        XCTAssertNil(model.errorMessage)
        let relaunched = LoginItemController(service: service, installationProblem: { nil })
        XCTAssertEqual(relaunched.status, .enabled)
        XCTAssertEqual(service.registrations, 1)
        relaunched.setEnabled(false)
        XCTAssertEqual(relaunched.status, .notRegistered)
        XCTAssertEqual(service.removals, 1)
    }

    func testApprovalIsPendingAndCanBeCancelledWithoutReRegistering() {
        let service = FakeLoginItem()
        service.afterRegister = .requiresApproval
        let model = LoginItemController(service: service, installationProblem: { nil })
        model.setEnabled(true)
        XCTAssertEqual(model.status, .requiresApproval)
        XCTAssertTrue(model.message.contains("Waiting for approval"))
        model.setEnabled(true)
        XCTAssertEqual(service.registrations, 1)
        XCTAssertEqual(service.settingsOpened, 0)
        model.setEnabled(false)
        XCTAssertEqual(model.status, .notRegistered)
        XCTAssertEqual(service.removals, 1)
    }

    func testExternalSettingsChangesAreReflectedWithoutBeingOverridden() {
        let service = FakeLoginItem()
        let model = LoginItemController(service: service, installationProblem: { nil })
        for status: LoginItemStatus in [.enabled, .requiresApproval, .notRegistered, .notFound, .unknown] {
            service.status = status
            model.refresh()
            XCTAssertEqual(model.status, status)
        }
        XCTAssertFalse(model.canToggle)
        model.setEnabled(true)
        model.setEnabled(false)
        XCTAssertEqual(service.registrations, 0)
        XCTAssertEqual(service.removals, 0)
    }

    func testRegisterAndUnregisterFailuresKeepActualStateAndExplainError() {
        let service = FakeLoginItem()
        let failure = NSError(domain: "LoginItemTest", code: 1, userInfo: [NSLocalizedDescriptionKey: "Registration denied."])
        service.registerError = failure
        let model = LoginItemController(service: service, installationProblem: { nil })
        model.setEnabled(true)
        XCTAssertEqual(model.status, .notRegistered)
        XCTAssertTrue(model.message.contains("Registration denied."))
        service.status = .enabled
        model.refresh()
        XCTAssertNil(model.errorMessage)
        service.unregisterError = failure
        model.setEnabled(false)
        XCTAssertEqual(model.status, .enabled)
        XCTAssertTrue(model.message.contains("Could not turn off"))
    }

    func testSuccessReturnWithoutStatusChangeIsNotReportedAsSuccess() {
        let service = FakeLoginItem()
        service.afterRegister = .notRegistered
        let model = LoginItemController(service: service, installationProblem: { nil })
        model.setEnabled(true)
        XCTAssertEqual(model.status, .notRegistered)
        XCTAssertNotNil(model.errorMessage)
        service.status = .enabled
        service.afterUnregister = .enabled
        model.setEnabled(false)
        XCTAssertEqual(model.status, .enabled)
        XCTAssertNotNil(model.errorMessage)
    }

    func testDevelopmentCopyCannotEnableButCanDisableExistingRegistration() {
        let service = FakeLoginItem()
        let model = LoginItemController(service: service, installationProblem: { "Move ColdKey to Applications." })
        XCTAssertFalse(model.canToggle)
        model.setEnabled(true)
        XCTAssertEqual(service.registrations, 0)
        XCTAssertEqual(model.status, .notRegistered)
        XCTAssertEqual(model.message, "Move ColdKey to Applications.")
        service.status = .requiresApproval
        model.refresh()
        XCTAssertTrue(model.canToggle)
        model.setEnabled(false)
        XCTAssertEqual(service.removals, 1)
        XCTAssertEqual(model.status, .notRegistered)
    }

    func testRepeatedOffAndOnRequestsDoNotRepeatSystemCalls() {
        let service = FakeLoginItem()
        let model = LoginItemController(service: service, installationProblem: { nil })
        model.setEnabled(false)
        model.setEnabled(true)
        model.setEnabled(true)
        XCTAssertEqual(service.registrations, 1)
        XCTAssertEqual(service.removals, 0)
        model.openSettings()
        XCTAssertEqual(service.settingsOpened, 1)
    }

    func testInstallationPolicyAcceptsApplicationsAndRejectsDisposableOrNonAppCopies() {
        let roots = [URL(fileURLWithPath: "/Applications"), URL(fileURLWithPath: "/Users/example/Applications")]
        for path in ["/Applications/ColdKey.app", "/Applications/Utilities/ColdKey.app", "/Users/example/Applications/ColdKey.app"] {
            XCTAssertNil(LoginItemInstallation.problem(bundleURL: URL(fileURLWithPath: path), bundleIdentifier: "com.evanvonessen.coldkey", applicationDirectories: roots), path)
        }
        for path in ["/tmp/.build/ColdKey.app", "/ApplicationsOther/ColdKey.app", "/Applications/Project/.build/ColdKey.app", "/Applications/Coldkey", "/Users/example/Downloads/ColdKey.app"] {
            XCTAssertNotNil(LoginItemInstallation.problem(bundleURL: URL(fileURLWithPath: path), bundleIdentifier: "com.evanvonessen.coldkey", applicationDirectories: roots), path)
        }
        XCTAssertNotNil(LoginItemInstallation.problem(bundleURL: URL(fileURLWithPath: "/Applications/ColdKey.app"), bundleIdentifier: nil, applicationDirectories: roots))
    }

    func testApplicationsSymlinkToBuildCopyDoesNotBypassInstallationPolicy() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let applications = root.appendingPathComponent("Applications")
        let build = root.appendingPathComponent("build/ColdKey.app")
        try FileManager.default.createDirectory(at: applications, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: build, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let link = applications.appendingPathComponent("ColdKey.app")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: build)
        XCTAssertNotNil(LoginItemInstallation.problem(bundleURL: link, bundleIdentifier: "com.evanvonessen.coldkey", applicationDirectories: [applications]))
    }
}

@MainActor
final class LoginSettingsWindowTests: XCTestCase {
    private func controls<T: NSView>(_ type: T.Type, in view: NSView) -> [T] {
        (view as? T).map { [$0] } ?? view.subviews.flatMap { controls(type, in: $0) }
    }

    func testCheckboxStartsOffAndTogglesWithoutShowingAWindow() throws {
        _ = NSApplication.shared
        let service = FakeLoginItem()
        let settings = LoginSettingsWindow(loginItem: LoginItemController(service: service, installationProblem: { nil }))
        defer { settings.close() }
        let window = try XCTUnwrap(settings.window)
        let content = try XCTUnwrap(window.contentView)
        let checkbox = try XCTUnwrap(controls(NSButton.self, in: content).first { $0.title == "Start at login" })
        XCTAssertEqual(checkbox.state, .off)
        XCTAssertFalse(window.isVisible)
        XCTAssertEqual(service.registrations, 0)
        checkbox.performClick(nil)
        XCTAssertEqual(checkbox.state, .on)
        XCTAssertEqual(service.registrations, 1)
        checkbox.performClick(nil)
        XCTAssertEqual(checkbox.state, .off)
        XCTAssertEqual(service.removals, 1)
        content.layoutSubtreeIfNeeded()
        for control in controls(NSButton.self, in: content) + controls(NSTextField.self, in: content).map({ $0 as NSView }) {
            XCTAssertTrue(content.bounds.contains(content.convert(control.bounds, from: control)))
            XCTAssertGreaterThanOrEqual(control.frame.height, control.fittingSize.height)
        }
    }

    func testPendingApprovalIsMixedAndCancelWorksAndSettingsOpensOnlyOnClick() throws {
        _ = NSApplication.shared
        let service = FakeLoginItem()
        service.afterRegister = .requiresApproval
        let settings = LoginSettingsWindow(loginItem: LoginItemController(service: service, installationProblem: { nil }))
        defer { settings.close() }
        let content = try XCTUnwrap(settings.window?.contentView)
        let checkbox = try XCTUnwrap(controls(NSButton.self, in: content).first { $0.title == "Start at login" })
        checkbox.performClick(nil)
        XCTAssertEqual(checkbox.state, .mixed)
        XCTAssertEqual(controls(NSTextField.self, in: content).map(\.stringValue), ["Evan Von Essen"])
        XCTAssertEqual(service.settingsOpened, 0)
        try XCTUnwrap(controls(NSButton.self, in: content).first { $0.title == "Open Login Items…" }).performClick(nil)
        XCTAssertEqual(service.settingsOpened, 1)
        checkbox.performClick(nil)
        XCTAssertEqual(checkbox.state, .off)
        XCTAssertEqual(service.removals, 1)
    }

    func testReopeningSettingsRefreshesExternalChangesAndFailedChangesKeepActualState() throws {
        _ = NSApplication.shared
        let service = FakeLoginItem()
        let settings = LoginSettingsWindow(loginItem: LoginItemController(service: service, installationProblem: { nil }))
        defer { settings.close() }
        let content = try XCTUnwrap(settings.window?.contentView)
        let checkbox = try XCTUnwrap(controls(NSButton.self, in: content).first { $0.title == "Start at login" })
        service.status = .enabled
        settings.windowDidBecomeKey(Notification(name: NSWindow.didBecomeKeyNotification))
        XCTAssertEqual(checkbox.state, .on)
        service.unregisterError = NSError(domain: "LoginItemTest", code: 1, userInfo: [NSLocalizedDescriptionKey: "Operation denied."])
        checkbox.performClick(nil)
        XCTAssertEqual(checkbox.state, .on)
        XCTAssertEqual(controls(NSTextField.self, in: content).map(\.stringValue), ["Evan Von Essen"])
    }

    func testBuildCopyDisablesCheckboxWithoutExplanatoryLabels() throws {
        _ = NSApplication.shared
        let service = FakeLoginItem()
        let problem = try XCTUnwrap(LoginItemInstallation.problem(bundleURL: URL(fileURLWithPath: "/tmp/.build/ColdKey.app"), bundleIdentifier: "com.evanvonessen.coldkey"))
        let settings = LoginSettingsWindow(loginItem: LoginItemController(service: service, installationProblem: { problem }))
        defer { settings.close() }
        let content = try XCTUnwrap(settings.window?.contentView)
        let checkbox = try XCTUnwrap(controls(NSButton.self, in: content).first { $0.title == "Start at login" })
        XCTAssertFalse(checkbox.isEnabled)
        XCTAssertEqual(checkbox.state, .off)
        XCTAssertEqual(service.registrations, 0)
        let label = try XCTUnwrap(controls(NSTextField.self, in: content).first)
        XCTAssertEqual(label.stringValue, "Evan Von Essen")
        content.layoutSubtreeIfNeeded()
        XCTAssertTrue(content.bounds.contains(content.convert(label.bounds, from: label)))
        XCTAssertGreaterThanOrEqual(label.frame.height, label.fittingSize.height)
    }
}
