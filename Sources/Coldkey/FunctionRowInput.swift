import AppKit
import Carbon
import ApplicationServices

// macOS delivers icon-row controls as NX_SYSDEFINED events rather than F-key events.
enum FunctionRowInput {
    static let mediaKeys: [Int: UInt32] = [
        3: UInt32(kVK_F1), 2: UInt32(kVK_F2),
        18: UInt32(kVK_F7), 20: UInt32(kVK_F7), 16: UInt32(kVK_F8),
        17: UInt32(kVK_F9), 19: UInt32(kVK_F9), 7: UInt32(kVK_F10),
        1: UInt32(kVK_F11), 0: UInt32(kVK_F12)
    ]
    struct Signal {
        let keyCode: UInt32
        let modifiers: UInt32
        let isDown: Bool
        let isRepeat: Bool
        let hasShift: Bool
    }
    static func supports(binding: Binding) -> Bool {
        let ambiguous = [kVK_F3, kVK_F4, kVK_F5, kVK_F6].map(UInt32.init)
        return ShortcutKey.isValid(keyCode: binding.keyCode, modifiers: binding.modifiers)
            && !ambiguous.contains(binding.keyCode)
    }
    static func signal(for event: NSEvent) -> Signal? {
        let code: UInt32
        let down: Bool
        let repeated: Bool
        switch event.type {
        case .keyDown, .keyUp:
            code = UInt32(event.keyCode); down = event.type == .keyDown; repeated = event.isARepeat
        case .systemDefined:
            guard event.subtype.rawValue == 8,
                  let mediaCode = mediaKeys[(event.data1 >> 16) & 0xffff] else { return nil }
            let state = (event.data1 >> 8) & 0xff
            guard state == 0x0a || state == 0x0b else { return nil }
            code = mediaCode; down = state == 0x0a; repeated = event.data1 & 1 != 0
        default: return nil
        }
        let flags = event.modifierFlags
        let modifiers = (flags.contains(.command) ? UInt32(cmdKey) : 0)
            | (flags.contains(.option) ? UInt32(optionKey) : 0)
            | (flags.contains(.control) ? UInt32(controlKey) : 0)
        return Signal(keyCode: code, modifiers: modifiers, isDown: down,
                      isRepeat: repeated, hasShift: flags.contains(.shift))
    }
    static func keyCode(forMediaEvent event: NSEvent) -> UInt32? {
        guard event.type == .systemDefined, let signal = signal(for: event),
              signal.isDown, !signal.isRepeat else { return nil }
        return signal.keyCode
    }
}

// One latch covers both representations: changing the row mode can change the key-up event.
struct FunctionRowPress {
    private(set) var isHeld = false
    private var tapOwnsPress = false
    mutating func releaseFromCarbon(binding: Binding) {
        guard !tapOwnsPress else { return }
        _ = handle(.init(keyCode: binding.keyCode, modifiers: 0, isDown: false, isRepeat: false, hasShift: false),
                   binding: binding, fromTap: false)
    }
    mutating func handle(_ signal: FunctionRowInput.Signal, binding: Binding, fromTap: Bool = true) -> (consume: Bool, trigger: Bool) {
        guard signal.keyCode == binding.keyCode else { return (false, false) }
        if isHeld {
            if !signal.isDown { isHeld = false; tapOwnsPress = false }
            else if fromTap { tapOwnsPress = true }
            return (true, false)
        }
        guard signal.isDown, !signal.hasShift, signal.modifiers == binding.modifiers else { return (false, false) }
        // A repeat arriving after a timeout/rebind must not toggle a second time.
        isHeld = true; tapOwnsPress = fromTap
        return (true, !signal.isRepeat)
    }
}

final class FunctionRowShortcutFilter {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private(set) var binding: Binding?
    private var press = FunctionRowPress()
    var onPress: ((Binding) -> Void)?
    var onChange: (() -> Void)?
    var isActive: Bool { tap.map(CGEvent.tapIsEnabled) ?? false }
    static var hasPermission: Bool { AXIsProcessTrusted() }

    static func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options),
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    func configure(_ binding: Binding?) {
        if self.binding != binding { press = FunctionRowPress() }
        self.binding = binding
        guard let binding, FunctionRowInput.supports(binding: binding), Self.hasPermission else { stop(); return }
        if let tap { CGEvent.tapEnable(tap: tap, enable: true); return }
        let mask = (CGEventMask(1) << CGEventType.keyDown.rawValue)
            | (CGEventMask(1) << CGEventType.keyUp.rawValue) | (CGEventMask(1) << 14)
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                           options: .defaultTap, eventsOfInterest: mask,
                                           callback: { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            let owner = Unmanaged<FunctionRowShortcutFilter>.fromOpaque(context).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                owner.press = FunctionRowPress()
                if let tap = owner.tap, FunctionRowShortcutFilter.hasPermission { CGEvent.tapEnable(tap: tap, enable: true) }
                DispatchQueue.main.async { [weak owner] in owner?.onChange?() }
                return Unmanaged.passUnretained(event)
            }
            guard let native = NSEvent(cgEvent: event), let signal = FunctionRowInput.signal(for: native),
                  let binding = owner.binding else { return Unmanaged.passUnretained(event) }
            let result = owner.press.handle(signal, binding: binding)
            if result.trigger {
                // IOKit and UI work stay outside the tap callback to avoid event delivery timeouts.
                DispatchQueue.main.async { [weak owner] in
                    guard let owner, owner.binding == binding else { return }
                    owner.onPress?(binding)
                }
            }
            return result.consume ? nil : Unmanaged.passUnretained(event)
        }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return }
        tap = port
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        if let source { CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes) }
        CGEvent.tapEnable(tap: port, enable: true)
    }
    // Carbon also reserves the canonical chord exclusively. The latch prevents duplicate delivery.
    func canonicalPress(_ binding: Binding) {
        guard self.binding?.id == binding.id else { return }
        guard isActive else { Self.requestPermission(); return }
        let signal = FunctionRowInput.Signal(keyCode: binding.keyCode, modifiers: binding.modifiers,
                                              isDown: true, isRepeat: false, hasShift: false)
        if press.handle(signal, binding: binding, fromTap: false).trigger { onPress?(binding) }
    }
    func canonicalRelease(_ id: UUID) {
        guard let binding, binding.id == id else { return }
        // A Carbon release may mean the modifiers changed, rather than the physical key came up.
        press.releaseFromCarbon(binding: binding)
    }
    private func stop() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CFMachPortInvalidate(tap) }
        source = nil; tap = nil; press = FunctionRowPress()
    }
    deinit { stop() }
}
