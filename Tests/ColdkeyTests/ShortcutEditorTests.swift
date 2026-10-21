import AppKit
import Carbon
import XCTest
@testable import Coldkey

@MainActor
final class ShortcutEditorTests: XCTestCase {
    private func button(_ title: String, in view: NSView) -> NSButton? {
        if let button = view as? NSButton, button.title == title { return button }
        return view.subviews.lazy.compactMap { self.button(title, in: $0) }.first
    }

    private func recorder(in view: NSView) -> ShortcutRecorder? {
        if let recorder = view as? ShortcutRecorder { return recorder }
        return view.subviews.lazy.compactMap { self.recorder(in: $0) }.first
    }

    private func targetControl(in view: NSView) -> NSSegmentedControl? {
        if let control = view as? NSSegmentedControl { return control }
        return view.subviews.lazy.compactMap { self.targetControl(in: $0) }.first
    }

    private func keyEvent(code: Int, modifiers: NSEvent.ModifierFlags = [], characters: String = "") throws -> NSEvent {
        try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers,
                                      timestamp: 0, windowNumber: 0, context: nil, characters: characters,
                                      charactersIgnoringModifiers: characters, isARepeat: false, keyCode: UInt16(code)))
    }

    func testRecorderAcceptsEveryBareFunctionKeyWithOrWithoutFunctionFlag() throws {
        _ = NSApplication.shared
        let keys = [
            (kVK_F1, "F1"), (kVK_F2, "F2"), (kVK_F3, "F3"), (kVK_F4, "F4"), (kVK_F5, "F5"),
            (kVK_F6, "F6"), (kVK_F7, "F7"), (kVK_F8, "F8"), (kVK_F9, "F9"), (kVK_F10, "F10"),
            (kVK_F11, "F11"), (kVK_F12, "F12"), (kVK_F13, "F13"), (kVK_F14, "F14"), (kVK_F15, "F15"),
            (kVK_F16, "F16"), (kVK_F17, "F17"), (kVK_F18, "F18"), (kVK_F19, "F19"), (kVK_F20, "F20")
        ]
        for flags in [NSEvent.ModifierFlags(), .function] {
            for (code, label) in keys {
                let recorder = ShortcutRecorder(title: "Record Shortcut", target: nil, action: nil)
                var recorded: (code: UInt32, modifiers: UInt32, label: String)?
                recorder.onRecord = { recorded = ($0, $1, $2) }
                // Function-key events expose private-use characters, not printable labels.
                recorder.keyDown(with: try keyEvent(code: code, modifiers: flags, characters: "\u{F704}"))
                let result = try XCTUnwrap(recorded, "\(label) must record with flags \(flags)")
                XCTAssertEqual(result.code, UInt32(code))
                XCTAssertEqual(result.modifiers, 0)
                XCTAssertEqual(result.label, label)
            }
        }
    }

    func testRecorderKeepsModifiedFunctionKeysAndExistingChords() throws {
        _ = NSApplication.shared
        let cases: [(Int, NSEvent.ModifierFlags, UInt32, String, String)] = [
            (kVK_F1, [.command, .function], UInt32(cmdKey), "\u{F704}", "F1"),
            (kVK_F12, [.option, .function], UInt32(optionKey), "\u{F70F}", "F12"),
            (kVK_F20, [.control, .function], UInt32(controlKey), "\u{F717}", "F20"),
            (kVK_ANSI_A, [.command, .option, .control], UInt32(cmdKey | optionKey | controlKey), "a", "A")
        ]
        for (code, flags, modifiers, characters, label) in cases {
            let recorder = ShortcutRecorder(title: "Record Shortcut", target: nil, action: nil)
            var recorded: (code: UInt32, modifiers: UInt32, label: String)?
            recorder.onRecord = { recorded = ($0, $1, $2) }
            recorder.keyDown(with: try keyEvent(code: code, modifiers: flags, characters: characters))
            let result = try XCTUnwrap(recorded)
            XCTAssertEqual(result.code, UInt32(code))
            XCTAssertEqual(result.modifiers, modifiers)
            XCTAssertEqual(result.label, label)
        }
    }

    func testRecorderRejectsBareOrdinaryKeysArrowsAndShiftedFunctionKeys() throws {
        _ = NSApplication.shared
        let recorder = ShortcutRecorder(title: "Record Shortcut", target: nil, action: nil)
        var recordCount = 0
        recorder.onRecord = { _, _, _ in recordCount += 1 }
        let cases: [(Int, NSEvent.ModifierFlags)] = [
            (kVK_ANSI_A, []), (kVK_LeftArrow, .function),
            (kVK_F1, [.shift, .function]), (kVK_F1, [.shift, .command, .function])
        ]
        for (code, flags) in cases {
            recorder.keyDown(with: try keyEvent(code: code, modifiers: flags, characters: "a"))
        }
        XCTAssertEqual(recordCount, 0)
    }

    func testEditorSavesRecordedBareFunctionKeyForApplicationsAndFolders() throws {
        _ = NSApplication.shared
        for kind in [Binding.TargetKind.application, .folder] {
            let binding = Binding(appPath: kind == .application ? "/Applications/Safari.app" : "/tmp/Example.folder",
                                  keyCode: UInt32(kVK_ANSI_A), modifiers: UInt32(cmdKey), keyLabel: "A",
                                  hideOnRepeat: false, targetKind: kind)
            let editor = ShortcutEditor(binding: binding)
            defer { editor.close() }
            let content = try XCTUnwrap(editor.window?.contentView)
            let recorder = try XCTUnwrap(recorder(in: content))
            recorder.keyDown(with: try keyEvent(code: kVK_F1, modifiers: .function, characters: "\u{F704}"))
            XCTAssertEqual(recorder.title, "F1")
            var saved: Binding?
            editor.onSave = { saved = $0; return nil }
            try XCTUnwrap(button("Save", in: content)).performClick(nil)
            let result = try XCTUnwrap(saved)
            XCTAssertEqual(result.id, binding.id)
            XCTAssertEqual(result.appPath, binding.appPath)
            XCTAssertEqual(result.targetKind, kind)
            XCTAssertEqual(result.keyCode, UInt32(kVK_F1))
            XCTAssertEqual(result.modifiers, 0)
            XCTAssertEqual(result.keyLabel, "F1")
            XCTAssertEqual(result.shortcut, "F1")
        }
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

    func testFolderEditorKeepsOptionsSeparateAndCancelledSelectionUnchanged() throws {
        _ = NSApplication.shared
        let binding = Binding(appPath: "/tmp/Example.folder", keyCode: 2, modifiers: 256, keyLabel: "D", hideOnRepeat: true, hideWhenNotFrontmost: true, targetKind: .folder, folderBookmark: Data([7]), closeFolderOnRepeat: true)
        let editor = ShortcutEditor(binding: binding)
        defer { editor.close() }
        let content = try XCTUnwrap(editor.window?.contentView)
        content.layoutSubtreeIfNeeded()
        XCTAssertTrue(try XCTUnwrap(button("Hide app when it is already in front", in: content)).isHidden)
        XCTAssertTrue(try XCTUnwrap(button("Hide even when not frontmost", in: content)).isHidden)
        let close = try XCTUnwrap(button("Close folder window when it is already in front", in: content))
        XCTAssertFalse(close.isHidden)
        XCTAssertTrue(content.bounds.contains(content.convert(close.bounds, from: close)))
        XCTAssertGreaterThanOrEqual(close.frame.width, close.fittingSize.width)
        editor.selectTarget(nil)
        var saved: Binding?
        editor.onSave = { saved = $0; return nil }
        try XCTUnwrap(button("Save", in: content)).performClick(nil)
        XCTAssertEqual(saved, binding)
    }

    func testFolderEditorRestoresAndSavesBothOptionsIndependently() throws {
        _ = NSApplication.shared
        for firstOption in [false, true] {
            for secondOption in [false, true] {
                let binding = Binding(appPath: "/tmp/Example.folder", keyCode: 2, modifiers: 256, keyLabel: "D", hideOnRepeat: true, hideWhenNotFrontmost: true, targetKind: .folder, closeFolderOnRepeat: firstOption, closeFolderWhenNotFrontmost: secondOption)
                let editor = ShortcutEditor(binding: binding)
                defer { editor.close() }
                let content = try XCTUnwrap(editor.window?.contentView)
                content.layoutSubtreeIfNeeded()
                let first = try XCTUnwrap(button("Close folder window when it is already in front", in: content))
                let second = try XCTUnwrap(button("Close even when not frontmost", in: content))
                for control in [first, second, try XCTUnwrap(button("Save", in: content))] {
                    XCTAssertFalse(control.isHidden)
                    XCTAssertTrue(content.bounds.contains(content.convert(control.bounds, from: control)))
                    XCTAssertGreaterThanOrEqual(control.frame.width, control.fittingSize.width)
                }
                XCTAssertEqual(first.state, firstOption ? .on : .off)
                XCTAssertEqual(second.state, secondOption ? .on : .off)
                first.performClick(nil); second.performClick(nil)
                var saved: Binding?
                editor.onSave = { saved = $0; return nil }
                try XCTUnwrap(button("Save", in: content)).performClick(nil)
                let result = try XCTUnwrap(saved)
                XCTAssertEqual(result.closeFolderOnRepeat, !firstOption)
                XCTAssertEqual(result.closeFolderWhenNotFrontmost, !secondOption)
                XCTAssertEqual(result.hideOnRepeat, binding.hideOnRepeat)
                XCTAssertEqual(result.hideWhenNotFrontmost, binding.hideWhenNotFrontmost)
            }
        }
    }

    func testFunctionRowEditorSavesWithoutTargetAndHidesAppAndFolderOptions() throws {
        _ = NSApplication.shared
        let original = Binding.functionRowDefault()
        let editor = ShortcutEditor(binding: original)
        defer { editor.close() }
        let content = try XCTUnwrap(editor.window?.contentView)
        content.layoutSubtreeIfNeeded()
        XCTAssertEqual(try XCTUnwrap(targetControl(in: content)).selectedSegment, 2)
        for title in ["Choose Application…", "Hide app when it is already in front", "Hide even when not frontmost",
                      "Close folder window when it is already in front", "Close even when not frontmost"] {
            XCTAssertTrue(try XCTUnwrap(button(title, in: content)).isHidden, title)
        }
        let recorder = try XCTUnwrap(recorder(in: content))
        recorder.keyDown(with: try keyEvent(code: kVK_ANSI_K, modifiers: [.control, .option], characters: "k"))
        var saved: Binding?
        editor.onSave = { saved = $0; return nil }
        try XCTUnwrap(button("Save", in: content)).performClick(nil)
        let result = try XCTUnwrap(saved)
        XCTAssertEqual(result.id, original.id)
        XCTAssertEqual(result.targetKind, .functionRow)
        XCTAssertTrue(result.appPath.isEmpty)
        XCTAssertEqual(result.shortcut, "⌃⌥K")
    }

    func testNewEditorCanChooseFunctionRowAndRecordCommandF12() throws {
        _ = NSApplication.shared
        let editor = ShortcutEditor(binding: nil)
        defer { editor.close() }
        let content = try XCTUnwrap(editor.window?.contentView)
        let control = try XCTUnwrap(targetControl(in: content))
        control.selectedSegment = 2
        NSApp.sendAction(try XCTUnwrap(control.action), to: control.target, from: control)
        let recorder = try XCTUnwrap(recorder(in: content))
        recorder.keyDown(with: try keyEvent(code: kVK_F12, modifiers: [.command, .function], characters: "\u{F70F}"))
        var saved: Binding?
        editor.onSave = { saved = $0; return nil }
        try XCTUnwrap(button("Save", in: content)).performClick(nil)
        let result = try XCTUnwrap(saved)
        XCTAssertEqual(result.targetKind, .functionRow)
        XCTAssertTrue(result.appPath.isEmpty)
        XCTAssertEqual(result.shortcut, "⌘F12")
    }

    func testFunctionRowEditorRejectsKeysWithoutReliableMediaAliases() throws {
        _ = NSApplication.shared
        let editor = ShortcutEditor(binding: .functionRowDefault())
        defer { editor.close() }
        let content = try XCTUnwrap(editor.window?.contentView)
        let recorder = try XCTUnwrap(recorder(in: content))
        var saved: Binding?
        editor.onSave = { saved = $0; return nil }
        for code in [kVK_F3, kVK_F4, kVK_F5, kVK_F6] {
            recorder.keyDown(with: try keyEvent(code: code, modifiers: [.command, .function]))
            try XCTUnwrap(button("Save", in: content)).performClick(nil)
            XCTAssertNil(saved)
        }
    }

    func testReservedShortcutRecordsOnlyWhenRecorderHasFocus() throws {
        _ = NSApplication.shared
        let original = Binding.functionRowDefault()
        let editor = ShortcutEditor(binding: original)
        defer { editor.close() }
        let content = try XCTUnwrap(editor.window?.contentView)
        let recorder = try XCTUnwrap(recorder(in: content))
        let window = try XCTUnwrap(editor.window)
        window.makeFirstResponder(nil)
        XCTAssertFalse(editor.recordReservedShortcut(original))
        XCTAssertTrue(window.makeFirstResponder(recorder))
        XCTAssertTrue(editor.recordReservedShortcut(original))
        XCTAssertFalse(window.firstResponder === recorder)
        XCTAssertEqual(recorder.title, "⌘F12")
        var saved: Binding?
        editor.onSave = { saved = $0; return nil }
        try XCTUnwrap(button("Save", in: content)).performClick(nil)
        XCTAssertEqual(saved, original)
    }

    func testEditorRecordsMediaModeCommandF12WhileRecorderHasFocus() throws {
        _ = NSApplication.shared
        let editor = ShortcutEditor(binding: .functionRowDefault())
        defer { editor.close() }
        let content = try XCTUnwrap(editor.window?.contentView)
        let recorder = try XCTUnwrap(recorder(in: content))
        let window = try XCTUnwrap(editor.window)
        XCTAssertTrue(window.makeFirstResponder(recorder))
        // NX_SYSDEFINED media event: sound-up (0), key-down (0xA), no repeat.
        let mediaEvent = try XCTUnwrap(NSEvent.otherEvent(with: .systemDefined, location: .zero,
            modifierFlags: .command, timestamp: 0, windowNumber: window.windowNumber,
            context: nil, subtype: 8, data1: 0xA00, data2: -1))
        window.sendEvent(mediaEvent)
        XCTAssertEqual(recorder.title, "⌘F12")
        XCTAssertFalse(window.firstResponder === recorder)
        var saved: Binding?
        editor.onSave = { saved = $0; return nil }
        try XCTUnwrap(button("Save", in: content)).performClick(nil)
        XCTAssertEqual(saved?.shortcut, "⌘F12")
    }
}
