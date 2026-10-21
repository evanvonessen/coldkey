import AppKit
import Carbon
import XCTest
@testable import Coldkey

@MainActor
final class FunctionRowInputTests: XCTestCase {
    private func keyEvent(type: NSEvent.EventType = .keyDown, code: Int = kVK_F12,
                          flags: NSEvent.ModifierFlags = .command, repeated: Bool = false) throws -> NSEvent {
        try XCTUnwrap(NSEvent.keyEvent(with: type, location: .zero, modifierFlags: flags,
                                      timestamp: 0, windowNumber: 0, context: nil, characters: "",
                                      charactersIgnoringModifiers: "", isARepeat: repeated, keyCode: UInt16(code)))
    }

    private func mediaEvent(code: Int = 0, down: Bool = true, flags: NSEvent.ModifierFlags = .command,
                            repeated: Bool = false, subtype: Int16 = 8, state: Int? = nil,
                            type: NSEvent.EventType = .systemDefined) throws -> NSEvent {
        let data = (code << 16) | ((state ?? (down ? 0x0a : 0x0b)) << 8) | (repeated ? 1 : 0)
        return try XCTUnwrap(NSEvent.otherEvent(with: type, location: .zero, modifierFlags: flags,
                                              timestamp: 0, windowNumber: 0, context: nil,
                                              subtype: subtype, data1: data, data2: -1))
    }

    private func parse(_ event: NSEvent) throws -> FunctionRowInput.Signal {
        try XCTUnwrap(FunctionRowInput.signal(for: event))
    }

    private func assertDecision(_ result: (consume: Bool, trigger: Bool), consume: Bool, trigger: Bool,
                                file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(result.consume, consume, file: file, line: line)
        XCTAssertEqual(result.trigger, trigger, file: file, line: line)
    }

    func testParsesStandardCommandF12DownUpAndRepeat() throws {
        for type in [NSEvent.EventType.keyDown, .keyUp] {
            let signal = try parse(keyEvent(type: type, flags: [.command, .function]))
            XCTAssertEqual(signal.keyCode, UInt32(kVK_F12))
            XCTAssertEqual(signal.modifiers, UInt32(cmdKey))
            XCTAssertEqual(signal.isDown, type == .keyDown)
            XCTAssertFalse(signal.isRepeat)
            XCTAssertFalse(signal.hasShift)
        }
        let repeated = try parse(keyEvent(repeated: true))
        XCTAssertTrue(repeated.isDown)
        XCTAssertTrue(repeated.isRepeat)
        let allModifiers = try parse(keyEvent(flags: [.command, .control, .option, .shift, .function]))
        XCTAssertEqual(allModifiers.modifiers, UInt32(cmdKey | controlKey | optionKey))
        XCTAssertTrue(allModifiers.hasShift)
    }

    func testParsesCommandVolumeUpAsCommandF12() throws {
        for down in [true, false] {
            let signal = try parse(mediaEvent(down: down, flags: [.command, .function]))
            XCTAssertEqual(signal.keyCode, UInt32(kVK_F12))
            XCTAssertEqual(signal.modifiers, UInt32(cmdKey))
            XCTAssertEqual(signal.isDown, down)
            XCTAssertFalse(signal.isRepeat)
            XCTAssertFalse(signal.hasShift)
        }
        let repeated = try parse(mediaEvent(repeated: true))
        XCTAssertTrue(repeated.isDown)
        XCTAssertTrue(repeated.isRepeat)
    }

    func testStableMediaAliasesMapToTheirPhysicalFunctionKeys() throws {
        // Rewind/previous and fast-forward/next share the F7 and F9 positions.
        let aliases = [(3, kVK_F1), (2, kVK_F2), (18, kVK_F7), (20, kVK_F7),
                       (16, kVK_F8), (17, kVK_F9), (19, kVK_F9), (7, kVK_F10),
                       (1, kVK_F11), (0, kVK_F12)]
        for (media, function) in aliases {
            let down = try mediaEvent(code: media, flags: [])
            let up = try mediaEvent(code: media, down: false, flags: [])
            XCTAssertEqual(try parse(down).keyCode, UInt32(function))
            XCTAssertEqual(try parse(up).keyCode, UInt32(function))
            XCTAssertEqual(FunctionRowInput.keyCode(forMediaEvent: down), UInt32(function))
            XCTAssertNil(FunctionRowInput.keyCode(forMediaEvent: up))
        }
    }

    func testIgnoresUnknownMediaKeysSubtypesStatesAndOtherEventTypes() throws {
        let events = try [mediaEvent(code: 6), mediaEvent(subtype: 7), mediaEvent(state: 0x09),
                          mediaEvent(state: 0x0c), mediaEvent(type: .applicationDefined)]
        for event in events {
            XCTAssertNil(FunctionRowInput.signal(for: event))
            XCTAssertNil(FunctionRowInput.keyCode(forMediaEvent: event))
        }
        XCTAssertNil(FunctionRowInput.keyCode(forMediaEvent: try keyEvent()))
    }

    func testRejectsAmbiguousF3ThroughF6ButKeepsStableKeysAndModifiedLetters() {
        var binding = Binding.functionRowDefault()
        for code in [kVK_F3, kVK_F4, kVK_F5, kVK_F6] {
            for modifiers in [UInt32(0), UInt32(cmdKey)] {
                binding.keyCode = UInt32(code); binding.modifiers = modifiers
                XCTAssertFalse(FunctionRowInput.supports(binding: binding))
            }
        }
        for code in [kVK_F1, kVK_F2, kVK_F7, kVK_F8, kVK_F9, kVK_F10, kVK_F11, kVK_F12,
                     kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20] {
            binding.keyCode = UInt32(code); binding.modifiers = 0
            XCTAssertTrue(FunctionRowInput.supports(binding: binding))
        }
        binding.keyCode = UInt32(kVK_ANSI_K); binding.modifiers = UInt32(controlKey | optionKey)
        XCTAssertTrue(FunctionRowInput.supports(binding: binding))
        binding.modifiers = 0
        XCTAssertFalse(FunctionRowInput.supports(binding: binding))
        binding.keyCode = UInt32(kVK_F12); binding.modifiers = UInt32(cmdKey | shiftKey)
        XCTAssertFalse(FunctionRowInput.supports(binding: binding))
    }

    func testLatchReleasesAcrossBothDirectionsOfFunctionRowModeChange() throws {
        let binding = Binding.functionRowDefault()
        let transitions = try [(keyEvent(), mediaEvent(down: false)),
                               (mediaEvent(), keyEvent(type: .keyUp))]
        for (down, up) in transitions {
            var press = FunctionRowPress()
            assertDecision(press.handle(try parse(down), binding: binding), consume: true, trigger: true)
            XCTAssertTrue(press.isHeld)
            assertDecision(press.handle(try parse(up), binding: binding), consume: true, trigger: false)
            XCTAssertFalse(press.isHeld)
            assertDecision(press.handle(try parse(down), binding: binding), consume: true, trigger: true)
        }
    }

    func testLatchConsumesRepeatsAndDuplicateRepresentationsWithoutRetriggering() throws {
        let binding = Binding.functionRowDefault()
        var press = FunctionRowPress()
        assertDecision(press.handle(try parse(keyEvent()), binding: binding), consume: true, trigger: true)
        for event in try [keyEvent(repeated: true), mediaEvent(repeated: true), mediaEvent(), keyEvent()] {
            assertDecision(press.handle(try parse(event), binding: binding), consume: true, trigger: false)
        }
        assertDecision(press.handle(try parse(mediaEvent(down: false)), binding: binding), consume: true, trigger: false)
        assertDecision(press.handle(try parse(mediaEvent()), binding: binding), consume: true, trigger: true)
    }

    func testFirstRepeatAfterResetIsConsumedWithoutTriggering() throws {
        let binding = Binding.functionRowDefault()
        for event in try [keyEvent(repeated: true), mediaEvent(repeated: true)] {
            var press = FunctionRowPress()
            assertDecision(press.handle(try parse(event), binding: binding), consume: true, trigger: false)
            XCTAssertTrue(press.isHeld)
            assertDecision(press.handle(try parse(keyEvent(type: .keyUp)), binding: binding), consume: true, trigger: false)
            XCTAssertFalse(press.isHeld)
            assertDecision(press.handle(try parse(keyEvent()), binding: binding), consume: true, trigger: true)
        }
    }

    func testReleasingModifierBeforeFunctionKeyStillClearsLatch() throws {
        let binding = Binding.functionRowDefault()
        for release in try [keyEvent(type: .keyUp, flags: []), mediaEvent(down: false, flags: [])] {
            var press = FunctionRowPress()
            assertDecision(press.handle(try parse(keyEvent()), binding: binding), consume: true, trigger: true)
            // The held key's release must be swallowed even after Command is released.
            assertDecision(press.handle(try parse(release), binding: binding), consume: true, trigger: false)
            XCTAssertFalse(press.isHeld)
            assertDecision(press.handle(try parse(keyEvent()), binding: binding), consume: true, trigger: true)
        }
    }

    func testUnrelatedKeysWrongModifiersShiftAndUnmatchedReleasesAreForwarded() throws {
        let binding = Binding.functionRowDefault()
        var press = FunctionRowPress()
        let events = try [keyEvent(code: kVK_F11), keyEvent(flags: []), keyEvent(flags: [.command, .option]),
                          keyEvent(flags: [.command, .shift]), mediaEvent(flags: [.command, .shift]),
                          keyEvent(type: .keyUp), mediaEvent(down: false)]
        for event in events {
            assertDecision(press.handle(try parse(event), binding: binding), consume: false, trigger: false)
            XCTAssertFalse(press.isHeld)
        }
        assertDecision(press.handle(try parse(keyEvent()), binding: binding), consume: true, trigger: true)
        assertDecision(press.handle(try parse(keyEvent(type: .keyUp, code: kVK_F11)), binding: binding), consume: false, trigger: false)
        XCTAssertTrue(press.isHeld)
    }

    func testEarlyCarbonReleaseCannotClearTapOwnedPress() throws {
        let binding = Binding.functionRowDefault()
        let down = try parse(keyEvent())
        var press = FunctionRowPress()
        assertDecision(press.handle(down, binding: binding), consume: true, trigger: true)
        press.releaseFromCarbon(binding: binding)
        XCTAssertTrue(press.isHeld)
        assertDecision(press.handle(try parse(mediaEvent(flags: [], repeated: true)), binding: binding), consume: true, trigger: false)
        assertDecision(press.handle(try parse(mediaEvent(down: false, flags: [])), binding: binding), consume: true, trigger: false)
        XCTAssertFalse(press.isHeld)
        // A canonical-only fallback still releases if the tap missed that press entirely.
        assertDecision(press.handle(down, binding: binding, fromTap: false), consume: true, trigger: true)
        press.releaseFromCarbon(binding: binding)
        XCTAssertFalse(press.isHeld)
        // Whichever path arrives first, a tap-observed down owns the eventual key-up.
        _ = press.handle(down, binding: binding, fromTap: false)
        _ = press.handle(down, binding: binding)
        press.releaseFromCarbon(binding: binding)
        XCTAssertTrue(press.isHeld)
    }

    func testRecorderIgnoresMediaKeyUpAndRepeats() throws {
        _ = NSApplication.shared
        let recorder = ShortcutRecorder(title: "Record Shortcut", target: nil, action: nil)
        var records: [(UInt32, UInt32, String)] = []
        recorder.onRecord = { records.append(($0, $1, $2)) }
        XCTAssertFalse(recorder.recordMediaEvent(try mediaEvent(down: false)))
        XCTAssertFalse(recorder.recordMediaEvent(try mediaEvent(repeated: true)))
        XCTAssertTrue(records.isEmpty)
        XCTAssertTrue(recorder.recordMediaEvent(try mediaEvent()))
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.0, UInt32(kVK_F12))
        XCTAssertEqual(records.first?.1, UInt32(cmdKey))
        XCTAssertEqual(records.first?.2, "F12")
    }
}
