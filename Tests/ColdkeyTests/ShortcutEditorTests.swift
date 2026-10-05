import AppKit
import XCTest
@testable import Coldkey

@MainActor
final class ShortcutEditorTests: XCTestCase {
    private func button(_ title: String, in view: NSView) -> NSButton? {
        if let button = view as? NSButton, button.title == title { return button }
        return view.subviews.lazy.compactMap { self.button(title, in: $0) }.first
    }

    func testNewEditorDefaultsBothHideOptionsOffAndFitsControls() throws {
        _ = NSApplication.shared
        let editor = ShortcutEditor(binding: nil)
        defer { editor.close() }
        let content = try XCTUnwrap(editor.window?.contentView)
        content.layoutSubtreeIfNeeded()
        for title in ["Hide app when it is already in front", "Hide even when not frontmost", "Save"] {
            let control = try XCTUnwrap(button(title, in: content))
            XCTAssertEqual(control.state, .off)
            let frame = content.convert(control.bounds, from: control)
            XCTAssertTrue(content.bounds.contains(frame), "\(title) must fit in the editor")
            XCTAssertGreaterThanOrEqual(control.frame.width, control.fittingSize.width)
        }
        XCTAssertFalse(try XCTUnwrap(editor.window).isVisible)
    }

    func testEditorRestoresAndSavesBothHideOptionsIndependently() throws {
        _ = NSApplication.shared
        for original in [false, true] {
            for background in [false, true] {
                let binding = Binding(appPath: "/Applications/Safari.app", keyCode: 0,
                                      modifiers: 256, keyLabel: "A", hideOnRepeat: original,
                                      hideWhenNotFrontmost: background)
                let editor = ShortcutEditor(binding: binding)
                let content = try XCTUnwrap(editor.window?.contentView)
                let first = try XCTUnwrap(button("Hide app when it is already in front", in: content))
                let second = try XCTUnwrap(button("Hide even when not frontmost", in: content))
                XCTAssertEqual(first.state, original ? .on : .off)
                XCTAssertEqual(second.state, background ? .on : .off)
                second.performClick(nil)
                var saved: Binding?
                editor.onSave = { saved = $0; return nil }
                try XCTUnwrap(button("Save", in: content)).performClick(nil)
                let result = try XCTUnwrap(saved)
                XCTAssertEqual(result.id, binding.id)
                XCTAssertEqual(result.hideOnRepeat, original)
                XCTAssertEqual(result.hideWhenNotFrontmost, !background)
                editor.close()
            }
        }
    }
}
