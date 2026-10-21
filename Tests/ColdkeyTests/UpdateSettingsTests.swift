import AppKit
import XCTest
@testable import Coldkey

private final class FakeUpdateSettings: UpdateChecking {
    var automaticallyChecksForUpdates = true { didSet { changes += 1 } }
    var isAvailable = true
    var message = "Checks once a day. Downloads and installation require your approval."
    var changes = 0
}

@MainActor
final class UpdateSettingsTests: XCTestCase {
    private func controls<T: NSView>(_ type: T.Type, in view: NSView) -> [T] {
        (view as? T).map { [$0] } ?? view.subviews.flatMap { controls(type, in: $0) }
    }

    func testGentleUpdateDelegateCallbacksAreExposedToObjectiveC() {
        let updates = UpdateController()
        for selector in ["supportsGentleScheduledUpdateReminders", "standardUserDriverShouldHandleShowingScheduledUpdate:andInImmediateFocus:",
                         "standardUserDriverWillHandleShowingUpdate:forUpdate:state:", "standardUserDriverDidReceiveUserAttentionForUpdate:",
                         "standardUserDriverWillFinishUpdateSession"] {
            XCTAssertTrue(updates.responds(to: NSSelectorFromString(selector)), "Missing Sparkle callback: \(selector)")
        }
    }

    func testCheckboxReflectsPreferenceAndOnlyChangesItWhenClicked() throws {
        _ = NSApplication.shared
        let updates = FakeUpdateSettings()
        let settings = LoginSettingsWindow(updates: updates)
        defer { settings.close() }
        let content = try XCTUnwrap(settings.window?.contentView)
        let checkbox = try XCTUnwrap(controls(NSButton.self, in: content).first { $0.title == "Check for updates" })
        XCTAssertEqual(checkbox.state, .on)
        XCTAssertTrue(checkbox.isEnabled)
        XCTAssertEqual(updates.changes, 0)
        checkbox.performClick(nil)
        XCTAssertFalse(updates.automaticallyChecksForUpdates)
        XCTAssertEqual(checkbox.state, .off)
        settings.refresh()
        XCTAssertEqual(updates.changes, 1)
        let reopened = LoginSettingsWindow(updates: updates)
        defer { reopened.close() }
        let reopenedContent = try XCTUnwrap(reopened.window?.contentView)
        XCTAssertEqual(try XCTUnwrap(controls(NSButton.self, in: reopenedContent).first { $0.title == "Check for updates" }).state, .off)
        checkbox.performClick(nil)
        XCTAssertTrue(updates.automaticallyChecksForUpdates)
        XCTAssertEqual(updates.changes, 2)
    }

    func testUnavailableUpdaterIsDisabledAndOnlyCreditIsShown() throws {
        _ = NSApplication.shared
        let updates = FakeUpdateSettings()
        updates.isAvailable = false
        updates.message = "Run the packaged ColdKey app to check for updates."
        let settings = LoginSettingsWindow(updates: updates)
        defer { settings.close() }
        let content = try XCTUnwrap(settings.window?.contentView)
        content.layoutSubtreeIfNeeded()
        let checkbox = try XCTUnwrap(controls(NSButton.self, in: content).first { $0.title == "Check for updates" })
        XCTAssertFalse(checkbox.isEnabled)
        let labels = controls(NSTextField.self, in: content)
        XCTAssertEqual(labels.map(\.stringValue), ["Evan Von Essen"])
        let credit = try XCTUnwrap(labels.first { $0.stringValue == "Evan Von Essen" })
        XCTAssertEqual(credit.alignment, .center)
        XCTAssertEqual(credit.textColor, .secondaryLabelColor)
        XCTAssertEqual(credit.font?.pointSize, NSFont.smallSystemFontSize)
        let creditFrame = content.convert(credit.bounds, from: credit)
        XCTAssertEqual(creditFrame.midX, content.bounds.midX, accuracy: 0.5)
        XCTAssertEqual(creditFrame.minY, 18, accuracy: 0.5)
        for control in labels.map({ $0 as NSView }) + controls(NSButton.self, in: content) {
            XCTAssertTrue(content.bounds.contains(content.convert(control.bounds, from: control)))
            XCTAssertGreaterThanOrEqual(control.frame.height, control.fittingSize.height)
        }
    }
}
