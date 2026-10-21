import AppKit
import XCTest
@testable import Coldkey

@MainActor
final class FunctionRowSettingsWindowTests: XCTestCase {
    private func controls<T: NSView>(_ type: T.Type, in view: NSView) -> [T] {
        (view as? T).map { [$0] } ?? view.subviews.flatMap { controls(type, in: $0) }
    }

    func testPermissionIsRequestedOnlyWhenAllowIsClickedAndRefreshReportsActualState() throws {
        _ = NSApplication.shared
        var permitted = false
        var requests = 0
        var settingsOpened = 0
        var refreshes = 0
        let settings = LoginSettingsWindow(
            functionRowStatus: { (active: false, permitted: permitted) },
            requestFunctionRowPermission: { requests += 1; permitted = true },
            openAccessibilitySettings: { settingsOpened += 1 })
        defer { settings.close() }
        settings.onFunctionRowPermissionChange = { refreshes += 1 }
        let window = try XCTUnwrap(settings.window)
        let content = try XCTUnwrap(window.contentView)
        let allow = try XCTUnwrap(controls(NSButton.self, in: content).first { $0.title == "Allow Function Row Shortcut…" })
        XCTAssertFalse(window.isVisible)
        XCTAssertEqual(requests, 0)
        XCTAssertEqual(settingsOpened, 0)
        settings.refresh()
        XCTAssertEqual(requests, 0)
        XCTAssertEqual(controls(NSTextField.self, in: content).map(\.stringValue), ["Evan Von Essen"])
        allow.performClick(nil)
        XCTAssertEqual(requests, 1)
        XCTAssertEqual(settingsOpened, 0)
        XCTAssertEqual(refreshes, 1)
        XCTAssertEqual(allow.title, "Open Accessibility Settings…")
        XCTAssertEqual(controls(NSTextField.self, in: content).map(\.stringValue), ["Evan Von Essen"])
    }

    func testTrustedInactiveShortcutOpensSettingsAndPermissionCallbackCanActivateIt() throws {
        _ = NSApplication.shared
        var active = false
        var requests = 0
        var settingsOpened = 0
        let settings = LoginSettingsWindow(
            functionRowStatus: { (active: active, permitted: true) },
            requestFunctionRowPermission: { requests += 1 },
            openAccessibilitySettings: { settingsOpened += 1 })
        defer { settings.close() }
        settings.onFunctionRowPermissionChange = { active = true }
        let content = try XCTUnwrap(settings.window?.contentView)
        let button = try XCTUnwrap(controls(NSButton.self, in: content).first { $0.title == "Open Accessibility Settings…" })
        XCTAssertEqual(settingsOpened, 0)
        button.performClick(nil)
        XCTAssertEqual(settingsOpened, 1)
        XCTAssertEqual(requests, 0)
        XCTAssertEqual(controls(NSTextField.self, in: content).map(\.stringValue), ["Evan Von Essen"])
    }

    func testReopeningSettingsRefreshesPermissionAndControlsFitAboveCenteredCredit() throws {
        _ = NSApplication.shared
        var permitted = false
        var active = false
        var refreshes = 0
        let settings = LoginSettingsWindow(
            functionRowStatus: { (active: active, permitted: permitted) },
            requestFunctionRowPermission: {}, openAccessibilitySettings: {})
        defer { settings.close() }
        settings.onFunctionRowPermissionChange = { refreshes += 1; active = permitted }
        let content = try XCTUnwrap(settings.window?.contentView)
        let permissionButton = try XCTUnwrap(controls(NSButton.self, in: content).first { $0.title == "Allow Function Row Shortcut…" })
        permitted = true
        settings.windowDidBecomeKey(Notification(name: NSWindow.didBecomeKeyNotification))
        XCTAssertEqual(refreshes, 1)
        XCTAssertEqual(permissionButton.title, "Open Accessibility Settings…")
        XCTAssertEqual(controls(NSTextField.self, in: content).map(\.stringValue), ["Evan Von Essen"])
        content.layoutSubtreeIfNeeded()
        let labels = controls(NSTextField.self, in: content)
        let credit = try XCTUnwrap(labels.first { $0.stringValue == "Evan Von Essen" })
        let creditFrame = content.convert(credit.bounds, from: credit)
        XCTAssertEqual(creditFrame.midX, content.bounds.midX, accuracy: 0.5)
        XCTAssertEqual(creditFrame.minY, 18, accuracy: 0.5)
        XCTAssertEqual(credit.textColor, .secondaryLabelColor)
        for control in labels.map({ $0 as NSView }) + controls(NSButton.self, in: content) {
            let frame = content.convert(control.bounds, from: control)
            XCTAssertTrue(content.bounds.contains(frame))
            XCTAssertGreaterThanOrEqual(control.frame.height, control.fittingSize.height)
            if control !== credit { XCTAssertGreaterThanOrEqual(frame.minY, creditFrame.maxY + 20) }
        }
    }
}
