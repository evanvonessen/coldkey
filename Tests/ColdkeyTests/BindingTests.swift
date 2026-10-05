import XCTest
import Carbon
@testable import Coldkey

final class BindingTests: XCTestCase {
    func testConflictIgnoresSelfButRejectsSameChordForAnotherApp() {
        let first = Binding(appPath: "/Applications/Safari.app", keyCode: 0, modifiers: UInt32(cmdKey), keyLabel: "A", hideOnRepeat: true)
        var second = first
        XCTAssertFalse(first.conflicts(with: second))
        second.id = UUID(); second.appPath = "/Applications/Mail.app"
        XCTAssertTrue(first.conflicts(with: second))
        second.modifiers = UInt32(optionKey)
        XCTAssertFalse(first.conflicts(with: second))
    }
    func testBindingsSurviveReloadAndRemoval() throws {
        let suite = "ColdkeyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let binding = Binding(appPath: "/Applications/Safari.app", keyCode: 0, modifiers: UInt32(cmdKey | optionKey), keyLabel: "A", hideOnRepeat: true)
        try BindingStore(defaults: defaults).save([binding])
        let restored = BindingStore(defaults: defaults)
        XCTAssertEqual(restored.bindings, [binding])
        XCTAssertEqual(restored.bindings.first?.shortcut, "⌥⌘A")
        try restored.save([])
        XCTAssertTrue(BindingStore(defaults: defaults).bindings.isEmpty)
    }
}
