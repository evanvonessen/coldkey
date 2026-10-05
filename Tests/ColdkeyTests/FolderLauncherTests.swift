import AppKit
import XCTest
@testable import Coldkey

private final class MockFinder: FinderControlling {
    enum Action: Equatable { case open(URL), focus(Int32), close(Int32) }
    var currentWindows: [FinderWindow] = []
    var actions: [Action] = []
    var error: Error?
    var actionError: Error?
    var queryCount = 0
    func windows() throws -> [FinderWindow] {
        queryCount += 1
        if let error { throw error }
        return currentWindows
    }
    func open(_ folder: URL) throws { actions.append(.open(folder)) }
    func focus(_ window: FinderWindow, folder: URL) throws { actions.append(.focus(window.id)) }
    func close(_ window: FinderWindow, folder: URL) throws {
        actions.append(.close(window.id))
        if let actionError { throw actionError }
    }
}

final class FolderLauncherTests: XCTestCase {
    private var directory: URL!
    private var binding: Binding!
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("Coldkey folder \(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        directory = FolderLocation.canonical(directory)
        binding = try FolderLocation.select(directory, for: Binding(appPath: "", keyCode: 2, modifiers: 256, keyLabel: "D", hideOnRepeat: false))
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: directory) }

    func testOpensAbsentFolderAndTogglesOnlyMatchingWindowAfterRestart() throws {
        let finder = MockFinder()
        _ = try FolderLauncher(finder: finder).run(binding)
        XCTAssertEqual(finder.actions, [.open(directory)])
        finder.currentWindows = [FinderWindow(id: 4, index: 1, folder: directory), FinderWindow(id: 5, index: 2, folder: directory.deletingLastPathComponent())]
        let reloaded = try JSONDecoder().decode(Binding.self, from: JSONEncoder().encode(binding))
        _ = try FolderLauncher(finder: finder).run(reloaded)
        XCTAssertEqual(finder.actions, [.open(directory), .close(4)])
        finder.currentWindows.removeFirst()
        _ = try FolderLauncher(finder: finder).run(reloaded)
        XCTAssertEqual(finder.actions.last, .open(directory))
    }

    func testMultipleMatchesCloseOnlyFrontmostWithStableTieBreak() throws {
        let finder = MockFinder()
        finder.currentWindows = [FinderWindow(id: 1, index: 1, folder: directory.deletingLastPathComponent()), FinderWindow(id: 9, index: 5, folder: directory), FinderWindow(id: 8, index: 2, folder: directory), FinderWindow(id: 7, index: 2, folder: directory)]
        _ = try FolderLauncher(finder: finder).run(binding)
        XCTAssertEqual(finder.actions, [.close(7)])
    }

    func testOpenOnlyFocusesExistingWindowWithoutDuplicatingOrClosing() throws {
        let finder = MockFinder()
        finder.currentWindows = [FinderWindow(id: 5, index: 3, folder: directory)]
        binding.closeFolderOnRepeat = false
        binding.hideOnRepeat = true; binding.hideWhenNotFrontmost = true
        _ = try FolderLauncher(finder: finder).run(binding)
        XCTAssertEqual(finder.actions, [.focus(5)])
    }

    func testBookmarkFollowsRenameAcrossSerialization() throws {
        let moved = directory.appendingPathExtension("renamed")
        try FileManager.default.moveItem(at: directory, to: moved)
        defer { try? FileManager.default.removeItem(at: moved) }
        let reloaded = try JSONDecoder().decode(Binding.self, from: JSONEncoder().encode(binding))
        let resolved = try FolderLocation.resolve(reloaded)
        XCTAssertEqual(resolved.appPath, moved.path)
        XCTAssertNotNil(resolved.folderBookmark)
        XCTAssertEqual(resolved.name, moved.lastPathComponent)
    }

    func testMissingFolderAndInvalidBookmarkNeverTouchFinder() throws {
        try FileManager.default.removeItem(at: directory)
        let finder = MockFinder()
        XCTAssertThrowsError(try FolderLauncher(finder: finder).run(binding))
        binding.folderBookmark = Data([1, 2, 3])
        XCTAssertThrowsError(try FolderLauncher(finder: finder).run(binding))
        XCTAssertEqual(finder.queryCount, 0)
        XCTAssertTrue(finder.actions.isEmpty)
    }

    func testPermissionsAndFinderFailuresLeaveAllWindowsUntouched() {
        for error in [FolderError.automationRequired, .automationDenied, .finderFailure("Timed out")] {
            let finder = MockFinder(); finder.error = error
            XCTAssertThrowsError(try FolderLauncher(finder: finder).run(binding))
            XCTAssertTrue(finder.actions.isEmpty)
        }
    }

    func testChangedWindowDoesNotFallBackToAnotherWindowOrReopenFolder() {
        let finder = MockFinder()
        finder.currentWindows = [FinderWindow(id: 4, index: 1, folder: directory), FinderWindow(id: 5, index: 2, folder: directory)]
        finder.actionError = FolderError.windowChanged
        XCTAssertThrowsError(try FolderLauncher(finder: finder).run(binding))
        XCTAssertEqual(finder.actions, [.close(4)])
    }

    func testFolderBookmarkAndToggleSurviveStoreReload() throws {
        let suite = "ColdkeyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        binding.closeFolderOnRepeat = false
        try BindingStore(defaults: defaults).save([binding])
        let restored = try XCTUnwrap(BindingStore(defaults: defaults).bindings.first)
        XCTAssertEqual(restored, binding)
        XCTAssertEqual(try FolderLocation.resolve(restored).appPath, directory.path)
    }

    func testSelectionCanonicalizesSymlinkAndRejectsFiles() throws {
        let link = directory.appendingPathComponent("link")
        let target = directory.appendingPathComponent("target")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        XCTAssertEqual(try FolderLocation.select(link, for: binding).appPath, target.path)
        let file = directory.appendingPathComponent("file")
        try Data().write(to: file)
        XCTAssertThrowsError(try FolderLocation.select(file, for: binding))
    }

    @MainActor
    func testFinderScriptCompilesWithoutExecutingOrRequestingPermission() throws {
        let script = try XCTUnwrap(NSAppleScript(source: FinderAutomation.source))
        var error: NSDictionary?
        XCTAssertTrue(script.compileAndReturnError(&error), "\(String(describing: error))")
    }
}
