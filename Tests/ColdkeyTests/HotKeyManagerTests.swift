import AppKit
import Carbon
import XCTest
@testable import Coldkey

private final class MockHotKeys: HotKeyRegistering {
    struct Request {
        let code: UInt32, modifiers: UInt32, id: EventHotKeyID, options: OptionBits
    }
    var requests: [Request] = []
    var released: [EventHotKeyRef] = []
    var failingCodes: Set<UInt32> = []
    func register(keyCode: UInt32, modifiers: UInt32, id: EventHotKeyID, options: OptionBits) -> (OSStatus, EventHotKeyRef?) {
        requests.append(Request(code: keyCode, modifiers: modifiers, id: id, options: options))
        return failingCodes.contains(keyCode) ? (OSStatus(eventHotKeyExistsErr), nil) : (noErr, EventHotKeyRef(bitPattern: Int(id.id)))
    }
    func unregister(_ reference: EventHotKeyRef) { released.append(reference) }
}

@MainActor
final class HotKeyManagerTests: XCTestCase {
    private let down = UInt32(kEventHotKeyPressed), up = UInt32(kEventHotKeyReleased)
    private func binding(code: UInt32 = 2, modifiers: UInt32 = UInt32(cmdKey), kind: Binding.TargetKind = .application) -> Binding {
        Binding(appPath: "/Applications/Example.app", keyCode: code, modifiers: modifiers, keyLabel: "D", hideOnRepeat: true, targetKind: kind)
    }

    func testExclusivePressRepeatAndReleaseForAppsAndFolders() throws {
        for kind in [Binding.TargetKind.application, .folder] {
            let backend = MockHotKeys(), shortcut = binding(kind: kind)
            let manager = HotKeyManager(backend: backend, installHandler: false)
            var actions: [UUID] = []; manager.onPress = { actions.append($0) }
            XCTAssertTrue(manager.register([shortcut]).isEmpty)
            let request = try XCTUnwrap(backend.requests.first)
            XCTAssertEqual(request.options, OptionBits(kEventHotKeyExclusive))
            XCTAssertEqual(request.code, shortcut.keyCode)
            XCTAssertEqual(request.modifiers, shortcut.modifiers)
            XCTAssertEqual(manager.handle(request.id, kind: down), noErr)
            XCTAssertEqual(manager.handle(request.id, kind: down), noErr)
            XCTAssertEqual(actions, [shortcut.id])
            XCTAssertEqual(manager.handle(request.id, kind: up), noErr)
            XCTAssertEqual(manager.handle(request.id, kind: down), noErr)
            XCTAssertEqual(actions, [shortcut.id, shortcut.id])
        }
    }

    func testUnmatchedIDsSignaturesAndRawEventsAreNotConsumed() throws {
        let backend = MockHotKeys()
        let subject = HotKeyManager(backend: backend, installHandler: false)
        var count = 0; subject.onPress = { _ in count += 1 }
        XCTAssertTrue(subject.register([binding()]).isEmpty)
        let key = try XCTUnwrap(backend.requests.first).id
        XCTAssertEqual(subject.handle(EventHotKeyID(signature: key.signature, id: key.id + 100), kind: down), OSStatus(eventNotHandledErr))
        XCTAssertEqual(subject.handle(EventHotKeyID(signature: 0, id: key.id), kind: down), OSStatus(eventNotHandledErr))
        for kind in [kEventRawKeyDown, kEventRawKeyRepeat, kEventRawKeyUp, kEventRawKeyModifiersChanged] {
            XCTAssertEqual(subject.handle(key, kind: UInt32(kind)), OSStatus(eventNotHandledErr))
        }
        XCTAssertEqual(count, 0)
    }

    func testUnregisterDisablesKeysAndRebindDoesNotAcceptStaleEvents() throws {
        let backend = MockHotKeys()
        let manager = HotKeyManager(backend: backend, installHandler: false)
        var actions: [UUID] = []; manager.onPress = { actions.append($0) }
        let first = binding()
        XCTAssertTrue(manager.register([first]).isEmpty)
        let oldKey = try XCTUnwrap(backend.requests.last).id
        manager.handle(oldKey, kind: down)
        manager.unregister()
        XCTAssertEqual(backend.released.count, 1)
        XCTAssertTrue(manager.registeredIDs.isEmpty)
        XCTAssertEqual(manager.handle(oldKey, kind: down), OSStatus(eventNotHandledErr))
        XCTAssertEqual(manager.handle(oldKey, kind: up), OSStatus(eventNotHandledErr))
        let second = binding(code: 3, modifiers: UInt32(controlKey | optionKey))
        XCTAssertTrue(manager.register([second]).isEmpty)
        let newKey = try XCTUnwrap(backend.requests.last).id
        XCTAssertNotEqual(oldKey.id, newKey.id)
        XCTAssertEqual(manager.handle(oldKey, kind: down), OSStatus(eventNotHandledErr))
        manager.handle(newKey, kind: down)
        XCTAssertEqual(actions, [first.id, second.id])
        XCTAssertTrue(manager.register([]).isEmpty)
        XCTAssertTrue(manager.registeredIDs.isEmpty)
        XCTAssertEqual(backend.released.count, 2)
    }

    func testConflictsAreReportedAndNeverActivated() throws {
        let backend = MockHotKeys(); backend.failingCodes = [2]
        let manager = HotKeyManager(backend: backend, installHandler: false)
        let unavailable = binding(), available = binding(code: 3)
        let errors = manager.register([unavailable, available])
        XCTAssertEqual(errors.count, 1)
        XCTAssertTrue(errors[0].contains("reserved exclusively"))
        XCTAssertEqual(manager.registeredIDs, [available.id])
        XCTAssertEqual(manager.handle(try XCTUnwrap(backend.requests.first).id, kind: down), OSStatus(eventNotHandledErr))
    }

    func testUnsafeModifierCombinationsAreRejectedWithoutRegistration() {
        let backend = MockHotKeys()
        let manager = HotKeyManager(backend: backend, installHandler: false)
        let invalid = [binding(modifiers: 0), binding(modifiers: UInt32(cmdKey | shiftKey)), binding(code: 55), binding(code: 255)]
        XCTAssertEqual(manager.register(invalid).count, invalid.count)
        XCTAssertTrue(backend.requests.isEmpty)
        XCTAssertTrue(manager.registeredIDs.isEmpty)
    }

    func testFailedSavePreservesStoredBindingsAndSuccessKeepsReservation() throws {
        let suite = "ColdkeyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = BindingStore(defaults: defaults)
        let original = binding(code: 3)
        try store.save([original])
        let backend = MockHotKeys(); backend.failingCodes = [2]
        let manager = HotKeyManager(backend: backend, installHandler: false)
        let delegate = AppDelegate(store: store, hotKeys: manager)
        let newBinding = binding()
        XCTAssertNotNil(delegate.saveBinding(newBinding))
        XCTAssertEqual(BindingStore(defaults: defaults).bindings, [original])
        XCTAssertTrue(manager.registeredIDs.isEmpty)
        backend.failingCodes = []
        XCTAssertNil(delegate.saveBinding(newBinding))
        XCTAssertEqual(manager.registeredIDs, [original.id, newBinding.id])
        XCTAssertEqual(BindingStore(defaults: defaults).bindings, [original, newBinding])
        let requestCount = backend.requests.count
        var duplicate = original; duplicate.id = UUID()
        XCTAssertNotNil(delegate.saveBinding(duplicate))
        XCTAssertEqual(backend.requests.count, requestCount)
    }

    func testDeinitReleasesReservations() {
        let backend = MockHotKeys()
        var manager: HotKeyManager? = HotKeyManager(backend: backend, installHandler: false)
        XCTAssertTrue(manager!.register([binding()]).isEmpty)
        manager = nil
        XCTAssertEqual(backend.released.count, 1)
    }

    func testNativeCarbonExclusiveConflictAndReleaseWithoutKeyboardInjection() throws {
        let backend = CarbonHotKeyRegistration()
        let keyCode = UInt32(kVK_F20), modifiers = UInt32(cmdKey | optionKey | controlKey)
        let first = backend.register(keyCode: keyCode, modifiers: modifiers, id: EventHotKeyID(signature: 0x54455354, id: 1), options: OptionBits(kEventHotKeyExclusive))
        guard first.0 == noErr, let reference = first.1 else { throw XCTSkip("Native test chord unavailable: \(first.0)") }
        let duplicate = backend.register(keyCode: keyCode, modifiers: modifiers, id: EventHotKeyID(signature: 0x54455354, id: 2), options: OptionBits(kEventHotKeyExclusive))
        if let extra = duplicate.1 { backend.unregister(extra) }
        XCTAssertNotEqual(duplicate.0, noErr)
        backend.unregister(reference)
        let retry = backend.register(keyCode: keyCode, modifiers: modifiers, id: EventHotKeyID(signature: 0x54455354, id: 3), options: OptionBits(kEventHotKeyExclusive))
        if let retryReference = retry.1 { backend.unregister(retryReference) }
        XCTAssertEqual(retry.0, noErr)
    }

    func testInstalledCarbonHandlerConsumesOnlyItsPressAndReleaseEvents() throws {
        let backend = MockHotKeys()
        let manager = HotKeyManager(backend: backend)
        var count = 0; manager.onPress = { _ in count += 1 }
        XCTAssertTrue(manager.register([binding()]).isEmpty)
        var key = try XCTUnwrap(backend.requests.first).id
        for kind in [down, down, up, down, up] {
            var event: EventRef?
            XCTAssertEqual(CreateEvent(nil, OSType(kEventClassKeyboard), kind, 0, EventAttributes(kEventAttributeUserEvent), &event), noErr)
            let created = try XCTUnwrap(event)
            defer { ReleaseEvent(created) }
            XCTAssertEqual(SetEventParameter(created, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), MemoryLayout<EventHotKeyID>.size, &key), noErr)
            XCTAssertEqual(SendEventToEventTarget(created, GetApplicationEventTarget()), noErr)
        }
        XCTAssertEqual(count, 2)
    }
}
