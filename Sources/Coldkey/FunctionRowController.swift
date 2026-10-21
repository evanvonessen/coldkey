import Foundation
import IOKit
import IOKit.hidsystem

protocol FunctionRowBackend {
    func readMode() throws -> Bool
    func setMode(_ functionKeys: Bool) throws
    func readPreference() throws -> Any?
    func setPreference(_ value: Any?) throws
}

enum FunctionRowError: LocalizedError {
    case unavailable, modeNotConfirmed, preferenceUnavailable, preferenceNotSaved, preferenceNotConfirmed
    case accessFailed(operation: String, status: kern_return_t)
    case restorationFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "macOS could not report the function-row mode. Check Function Keys in System Settings → Keyboard → Keyboard Shortcuts."
        case .modeNotConfirmed:
            return "macOS did not confirm the new function-row mode. Try again or check Function Keys in System Settings."
        case .preferenceUnavailable:
            return "macOS could not read the saved function-key setting. Try again."
        case .preferenceNotSaved:
            return "macOS could not save the function-key setting. Try again."
        case .preferenceNotConfirmed:
            return "macOS did not confirm that the function-key setting was saved. Try again."
        case .accessFailed(let operation, let status):
            let reason = String(cString: mach_error_string(status))
            return "macOS could not \(operation) the function-key setting (\(reason)). Check Function Keys in System Settings → Keyboard → Keyboard Shortcuts."
        case .restorationFailed(let reason):
            return "\(reason) The previous function-key setting could not be fully restored. Check Function Keys in System Settings → Keyboard → Keyboard Shortcuts."
        }
    }
}

struct SystemFunctionRowBackend: FunctionRowBackend {
    private let modeKey = kIOHIDFKeyModeKey as CFString
    private let preferenceKey = "com.apple.keyboard.fnState" as CFString

    private func withConnection<T>(_ action: (io_connect_t) throws -> T) throws -> T {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOHIDSystem"))
        guard service != IO_OBJECT_NULL else { throw FunctionRowError.unavailable }
        defer { IOObjectRelease(service) }
        var connection = io_connect_t(IO_OBJECT_NULL)
        let status = IOServiceOpen(service, mach_task_self_, UInt32(kIOHIDParamConnectType), &connection)
        guard status == KERN_SUCCESS else { throw FunctionRowError.accessFailed(operation: "access", status: status) }
        defer { IOServiceClose(connection) }
        return try action(connection)
    }

    func readMode() throws -> Bool {
        try withConnection { connection in
            var parameter: Unmanaged<CFTypeRef>?
            let status = IOHIDCopyCFTypeParameter(connection, modeKey, &parameter)
            guard status == KERN_SUCCESS else { throw FunctionRowError.accessFailed(operation: "read", status: status) }
            guard let value = parameter?.takeRetainedValue(), CFGetTypeID(value) == CFNumberGetTypeID() else {
                throw FunctionRowError.unavailable
            }
            var mode: Int32 = 0
            guard CFNumberGetValue((value as! CFNumber), .sInt32Type, &mode), mode == 0 || mode == 1 else {
                throw FunctionRowError.unavailable
            }
            return mode == 1
        }
    }

    func setMode(_ functionKeys: Bool) throws {
        try withConnection { connection in
            // CFNumber is required by the HID keyboard filter; a CFBoolean is ignored.
            let status = IOHIDSetCFTypeParameter(connection, modeKey, NSNumber(value: functionKeys ? 1 : 0))
            guard status == KERN_SUCCESS else { throw FunctionRowError.accessFailed(operation: "change", status: status) }
        }
    }

    func readPreference() throws -> Any? {
        guard CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) else {
            throw FunctionRowError.preferenceUnavailable
        }
        return CFPreferencesCopyValue(preferenceKey, kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }

    func setPreference(_ value: Any?) throws {
        CFPreferencesSetValue(preferenceKey, value as CFPropertyList?, kCFPreferencesAnyApplication,
                              kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        guard CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) else {
            throw FunctionRowError.preferenceNotSaved
        }
    }
}

final class FunctionRowController {
    private let backend: FunctionRowBackend
    private let lock = NSLock()

    init(backend: FunctionRowBackend = SystemFunctionRowBackend()) { self.backend = backend }

    func isFunctionMode() throws -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return try backend.readMode()
    }

    @discardableResult
    func toggle() throws -> Bool {
        lock.lock()
        defer { lock.unlock() }
        // Read macOS each time so changes made in System Settings are respected.
        let originalMode = try backend.readMode()
        let originalPreference = try backend.readPreference()
        let newMode = !originalMode
        var preferenceAttempted = false
        do {
            try backend.setMode(newMode)
            guard try backend.readMode() == newMode else { throw FunctionRowError.modeNotConfirmed }
            preferenceAttempted = true
            try backend.setPreference(newMode)
            guard try backend.readPreference() as? Bool == newMode else { throw FunctionRowError.preferenceNotConfirmed }
            guard try backend.readMode() == newMode else { throw FunctionRowError.modeNotConfirmed }
            return newMode
        } catch {
            let failure = error
            var restorationFailed = false
            // A failed setter can have partially applied its value, so always undo an attempted write.
            if preferenceAttempted {
                do {
                    try backend.setPreference(originalPreference)
                    let restored = try backend.readPreference()
                    if !Self.samePreference(restored, originalPreference) { restorationFailed = true }
                } catch { restorationFailed = true }
            }
            // Restore live mode last in case saving preferences also refreshes the HID setting.
            do {
                try backend.setMode(originalMode)
                guard try backend.readMode() == originalMode else { throw FunctionRowError.modeNotConfirmed }
            } catch { restorationFailed = true }
            if restorationFailed { throw FunctionRowError.restorationFailed(failure.localizedDescription) }
            throw failure
        }
    }

    private static func samePreference(_ first: Any?, _ second: Any?) -> Bool {
        switch (first, second) {
        case (nil, nil): return true
        case (let first as NSObject, let second as NSObject): return first.isEqual(second)
        default: return false
        }
    }
}
