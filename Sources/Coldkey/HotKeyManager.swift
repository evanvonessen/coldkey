import Carbon

final class HotKeyManager {
    private var references: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?
    private var actions: [UInt32: UUID] = [:]
    var onPress: ((UUID) -> Void)?
    init() {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var key = EventHotKeyID()
            let result = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &key)
            guard result == noErr else { return result }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(context).takeUnretainedValue()
            if let id = manager.actions[key.id] { manager.onPress?(id) }
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }
    func unregister() {
        references.forEach { UnregisterEventHotKey($0) }
        references.removeAll()
        actions.removeAll()
    }
    func register(_ bindings: [Binding]) -> [String] {
        unregister()
        var failures: [String] = []
        for (index, binding) in bindings.enumerated() {
            let number = UInt32(index + 1)
            var reference: EventHotKeyRef?
            let status = RegisterEventHotKey(binding.keyCode, binding.modifiers, EventHotKeyID(signature: 0x434F4C44, id: number), GetApplicationEventTarget(), 0, &reference)
            if status == noErr, let reference {
                references.append(reference)
                actions[number] = binding.id
            } else { failures.append("\(binding.name): \(binding.shortcut) is unavailable (\(status)).") }
        }
        return failures
    }
    deinit {
        unregister()
        if let handler { RemoveEventHandler(handler) }
    }
}
