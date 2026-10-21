import Carbon
import Foundation

protocol HotKeyRegistering {
    func register(keyCode: UInt32, modifiers: UInt32, id: EventHotKeyID, options: OptionBits) -> (OSStatus, EventHotKeyRef?)
    func unregister(_ reference: EventHotKeyRef)
}

struct CarbonHotKeyRegistration: HotKeyRegistering {
    func register(keyCode: UInt32, modifiers: UInt32, id: EventHotKeyID, options: OptionBits) -> (OSStatus, EventHotKeyRef?) {
        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), options, &reference)
        return (status, reference)
    }
    func unregister(_ reference: EventHotKeyRef) { UnregisterEventHotKey(reference) }
}

final class HotKeyManager {
    static let signature: OSType = 0x434F4C44
    // Carbon registration and dispatch run on the main thread. Never reuse an ID after rebinding.
    private static var nextIdentifier: UInt32 = 1
    private let backend: HotKeyRegistering
    private struct Registration {
        let binding: Binding
        let number: UInt32
        let reference: EventHotKeyRef
    }
    private var registrations: [Registration] = []
    private var handler: EventHandlerRef?
    private var handlerStatus: OSStatus = noErr
    private var actions: [UInt32: UUID] = [:]
    private var pressed: Set<UInt32> = []
    var registeredIDs: Set<UUID> { Set(actions.values) }
    var onPress: ((UUID) -> Void)?
    var onRelease: ((UUID) -> Void)?

    init(backend: HotKeyRegistering = CarbonHotKeyRegistration(), installHandler: Bool = true) {
        self.backend = backend
        guard installHandler else { return }
        let types = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]
        handlerStatus = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var key = EventHotKeyID()
            let result = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &key)
            guard result == noErr else { return result }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(context).takeUnretainedValue()
            return manager.handle(key, kind: GetEventKind(event))
        }, types.count, types, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }

    @discardableResult
    func handle(_ key: EventHotKeyID, kind: UInt32) -> OSStatus {
        guard key.signature == Self.signature, let id = actions[key.id] else { return OSStatus(eventNotHandledErr) }
        switch kind {
        case UInt32(kEventHotKeyPressed):
            if pressed.insert(key.id).inserted { onPress?(id) }
        case UInt32(kEventHotKeyReleased):
            if pressed.remove(key.id) != nil { onRelease?(id) }
        default: return OSStatus(eventNotHandledErr)
        }
        return noErr
    }

    func unregister() {
        registrations.forEach { backend.unregister($0.reference) }
        registrations.removeAll(); actions.removeAll(); pressed.removeAll()
    }

    func register(_ bindings: [Binding]) -> [String] {
        unregister()
        var failures: [String] = []
        for binding in bindings { failures += replace(registrations.map(\.binding) + [binding]) }
        return failures
    }

    // Reserve replacements before releasing old keys. Failed changes leave every old reservation intact.
    func replace(_ bindings: [Binding]) -> [String] {
        guard handlerStatus == noErr else { return ["ColdKey could not listen for shortcuts (\(handlerStatus)). Restart the app and try again."] }
        var failures: [String] = []
        var desired: [Registration] = []
        var acquired: [Registration] = []
        var identifiers = Set<UUID>()
        for binding in bindings {
            guard identifiers.insert(binding.id).inserted else {
                failures.append("Duplicate shortcut. Remove the duplicate and try again."); continue
            }
            if let existing = registrations.first(where: {
                $0.binding.id == binding.id && $0.binding.keyCode == binding.keyCode && $0.binding.modifiers == binding.modifiers
            }) {
                desired.append(Registration(binding: binding, number: existing.number, reference: existing.reference))
                continue
            }
            guard ShortcutKey.isValid(keyCode: binding.keyCode, modifiers: binding.modifiers) else {
                failures.append("\(binding.name): choose F1–F20 alone, or Command, Option, or Control with one non-modifier key.")
                continue
            }
            guard Self.nextIdentifier < UInt32.max else {
                failures.append("Restart ColdKey before registering another shortcut."); continue
            }
            let number = Self.nextIdentifier
            Self.nextIdentifier += 1
            let (status, reference) = backend.register(keyCode: binding.keyCode, modifiers: binding.modifiers,
                                                      id: EventHotKeyID(signature: Self.signature, id: number),
                                                      options: OptionBits(kEventHotKeyExclusive))
            if status == noErr, let reference {
                let registration = Registration(binding: binding, number: number, reference: reference)
                acquired.append(registration); desired.append(registration)
            } else {
                if let reference { backend.unregister(reference) }
                failures.append("\(binding.name): \(binding.shortcut) could not be reserved exclusively (\(status)). Choose another shortcut or release it in the other app.")
            }
        }
        guard failures.isEmpty else {
            acquired.forEach { backend.unregister($0.reference) }
            return failures
        }
        let retained = Set(desired.map(\.number))
        registrations.filter { !retained.contains($0.number) }.forEach { backend.unregister($0.reference) }
        registrations = desired
        actions = Dictionary(uniqueKeysWithValues: desired.map { ($0.number, $0.binding.id) })
        pressed.formIntersection(retained)
        return []
    }

    deinit {
        unregister()
        if let handler { RemoveEventHandler(handler) }
    }
}
