import XCTest
@testable import Coldkey

final class AppLauncherTests: XCTestCase {
    private func binding(original: Bool = false, background: Bool = false) -> Binding {
        Binding(appPath: "/Applications/Safari.app", keyCode: 0, modifiers: 256,
                keyLabel: "A", hideOnRepeat: original, hideWhenNotFrontmost: background)
    }

    func testBothOptionsOffAlwaysShowsRunningApp() {
        XCTAssertFalse(AppLauncher.shouldHide(binding(), isActive: true, isHidden: false))
        XCTAssertFalse(AppLauncher.shouldHide(binding(), isActive: false, isHidden: false))
        XCTAssertFalse(AppLauncher.shouldHide(binding(), isActive: false, isHidden: true))
    }

    func testOriginalOptionOnlyHidesFrontmostApp() {
        XCTAssertTrue(AppLauncher.shouldHide(binding(original: true), isActive: true, isHidden: false))
        XCTAssertFalse(AppLauncher.shouldHide(binding(original: true), isActive: false, isHidden: false))
        XCTAssertFalse(AppLauncher.shouldHide(binding(original: true), isActive: false, isHidden: true))
    }

    func testNewOptionHidesVisibleAppsAndRestoresHiddenApps() {
        for originalOption in [false, true] {
            let shortcut = binding(original: originalOption, background: true)
            XCTAssertTrue(AppLauncher.shouldHide(shortcut, isActive: true, isHidden: false))
            XCTAssertTrue(AppLauncher.shouldHide(shortcut, isActive: false, isHidden: false))
            XCTAssertFalse(AppLauncher.shouldHide(shortcut, isActive: false, isHidden: true))
        }
    }
}
