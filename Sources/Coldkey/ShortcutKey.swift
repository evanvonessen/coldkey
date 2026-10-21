import Carbon

enum ShortcutKey {
    // Virtual key codes are not ordered by function-key number.
    static let functionKeyLabels: [UInt32: String] = Dictionary(uniqueKeysWithValues: [
        kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
        kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20
    ].enumerated().map { (UInt32($0.element), "F\($0.offset + 1)") })

    static func isValid(keyCode: UInt32, modifiers: UInt32) -> Bool {
        let allowedModifiers = UInt32(cmdKey | optionKey | controlKey)
        let modifierKeys: Set<UInt32> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
        return modifiers & ~allowedModifiers == 0 && keyCode <= 127 && !modifierKeys.contains(keyCode)
            && (modifiers != 0 || functionKeyLabels[keyCode] != nil)
    }
}
