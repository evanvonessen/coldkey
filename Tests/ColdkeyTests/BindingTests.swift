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

    func testOlderSavedShortcutsKeepTheirBehavior() throws {
        let suite = "ColdkeyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let id = UUID()
        let legacy = """
        [{"id":"\(id.uuidString)","appPath":"/Applications/Safari.app","keyCode":0,"modifiers":256,"keyLabel":"A","hideOnRepeat":true}]
        """
        defaults.set(Data(legacy.utf8), forKey: "bindings")
        let restored = BindingStore(defaults: defaults)
        XCTAssertEqual(restored.bindings.count, 1)
        let binding = try XCTUnwrap(restored.bindings.first)
        XCTAssertEqual(binding.id, id)
        XCTAssertTrue(binding.hideOnRepeat)
        XCTAssertFalse(binding.hideWhenNotFrontmost)
        XCTAssertEqual(binding.targetKind, .application)
        XCTAssertNil(binding.folderBookmark)
    }

    func testBackgroundHideSavesIndependentlyOfOriginalOption() throws {
        let suite = "ColdkeyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        for originalOption in [false, true] {
            var binding = Binding(appPath: "/Applications/Safari.app", keyCode: 0, modifiers: UInt32(cmdKey), keyLabel: "A", hideOnRepeat: originalOption)
            XCTAssertFalse(binding.hideWhenNotFrontmost)
            binding.hideWhenNotFrontmost = true
            try BindingStore(defaults: defaults).save([binding])
            XCTAssertEqual(BindingStore(defaults: defaults).bindings, [binding])
            binding.hideWhenNotFrontmost = false
            try BindingStore(defaults: defaults).save([binding])
            XCTAssertEqual(BindingStore(defaults: defaults).bindings, [binding])
        }
    }

    func testLegacyFolderCloseOptionMigratesToBackgroundOptionOnly() throws {
        for legacyClose in [false, true] {
            let legacy = """
            {"id":"\(UUID().uuidString)","appPath":"/tmp/Example","keyCode":2,"modifiers":256,"keyLabel":"D","hideOnRepeat":false,"targetKind":"folder","closeFolderOnRepeat":\(legacyClose)}
            """
            let decoded = try JSONDecoder().decode(Binding.self, from: Data(legacy.utf8))
            XCTAssertFalse(decoded.closeFolderOnRepeat)
            XCTAssertEqual(decoded.closeFolderWhenNotFrontmost, legacyClose)
            let reloaded = try JSONDecoder().decode(Binding.self, from: JSONEncoder().encode(decoded))
            XCTAssertEqual(reloaded, decoded)
        }
    }

    func testLegacyAppOptionsDoNotTurnOnFolderClosing() throws {
        let legacy = """
        {"id":"\(UUID().uuidString)","appPath":"/Applications/Safari.app","keyCode":2,"modifiers":256,"keyLabel":"D","hideOnRepeat":true,"hideWhenNotFrontmost":true,"targetKind":"application","closeFolderOnRepeat":true}
        """
        let decoded = try JSONDecoder().decode(Binding.self, from: Data(legacy.utf8))
        XCTAssertTrue(decoded.hideOnRepeat)
        XCTAssertTrue(decoded.hideWhenNotFrontmost)
        XCTAssertFalse(decoded.closeFolderOnRepeat)
        XCTAssertFalse(decoded.closeFolderWhenNotFrontmost)
    }
}
