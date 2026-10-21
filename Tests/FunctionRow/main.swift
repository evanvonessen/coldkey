import AppKit
import Carbon

// Compile with Sources/Coldkey/FunctionRowController.swift. This explicit native validation
// changes the live function-row setting twice and restores the exact original snapshots.
func verifyDefaultReservation() throws {
    var reference: EventHotKeyRef?
    let key = EventHotKeyID(signature: 0x434B5453, id: 1)
    let status = RegisterEventHotKey(UInt32(kVK_F12), UInt32(cmdKey), key,
                                     GetApplicationEventTarget(), OptionBits(kEventHotKeyExclusive), &reference)
    guard status == noErr, let reference else {
        throw NSError(domain: "ColdKeyValidation", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "⌘F12 could not be reserved (\(status))."])
    }
    defer { UnregisterEventHotKey(reference) }
    var duplicate: EventHotKeyRef?
    let conflict = RegisterEventHotKey(UInt32(kVK_F12), UInt32(cmdKey), EventHotKeyID(signature: key.signature, id: 2),
                                       GetApplicationEventTarget(), OptionBits(kEventHotKeyExclusive), &duplicate)
    if let duplicate { UnregisterEventHotKey(duplicate) }
    guard conflict != noErr else {
        throw NSError(domain: "ColdKeyValidation", code: 1, userInfo: [NSLocalizedDescriptionKey: "⌘F12 reservation was not exclusive."])
    }
    print("⌘F12 native exclusive registration and duplicate rejection verified.")
}
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let backend = SystemFunctionRowBackend()
let controller = FunctionRowController(backend: backend)
var validationFailed = false

do {
    let originalMode = try backend.readMode()
    let originalPreference = try backend.readPreference()
    defer {
        var failures: [String] = []
        do { try backend.setPreference(originalPreference) }
        catch { failures.append(error.localizedDescription) }
        do { try backend.setMode(originalMode) }
        catch { failures.append(error.localizedDescription) }
        do {
            if try backend.readMode() != originalMode { failures.append("Original runtime mode was not restored.") }
            let restoredPreference = try backend.readPreference()
            switch (restoredPreference, originalPreference) {
            case (nil, nil): break
            case (let restored as NSObject, let original as NSObject) where restored.isEqual(original): break
            default: failures.append("Original preference was not restored.")
            }
        } catch { failures.append(error.localizedDescription) }
        if failures.isEmpty { print("Exact original runtime mode and saved preference restored.") }
        else {
            for failure in failures { fputs("RESTORATION ERROR: \(failure)\n", stderr) }
            validationFailed = true
        }
    }

    print("Original mode: \(originalMode ? "F1–F12" : "hardware controls")")
    let firstMode = try controller.toggle()
    guard firstMode != originalMode, try backend.readMode() == firstMode,
          try backend.readPreference() as? Bool == firstMode else {
        throw FunctionRowError.modeNotConfirmed
    }
    print("First native toggle and saved preference verified.")
    try verifyDefaultReservation()
    let secondMode = try controller.toggle()
    guard secondMode == originalMode, try backend.readMode() == secondMode,
          try backend.readPreference() as? Bool == secondMode else {
        throw FunctionRowError.modeNotConfirmed
    }
    print("Second native toggle and saved preference verified.")
    try verifyDefaultReservation()
} catch {
    fputs("VALIDATION ERROR: \(error.localizedDescription)\n", stderr)
    validationFailed = true
}
if validationFailed { exit(EXIT_FAILURE) }
