import AppKit
import Carbon

final class FinderAutomation: FinderControlling {
    static func checkPermission(askUser: Bool = false, completion: @escaping (Result<Void, Error>) -> Void) {
        // Apple's permission API can wait for the user, so keep it off the main thread.
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try permissionStatus(askUser: askUser) }
            DispatchQueue.main.async { completion(result) }
        }
    }

    private static func permissionStatus(askUser: Bool) throws {
        let target = NSAppleEventDescriptor(bundleIdentifier: "com.apple.finder")
        let status = AEDeterminePermissionToAutomateTarget(target.aeDesc, typeWildCard, typeWildCard, askUser)
        switch status {
        case noErr: return
        case OSStatus(errAEEventWouldRequireUserConsent): throw FolderError.automationRequired
        case OSStatus(errAEEventNotPermitted): throw FolderError.automationDenied
        case OSStatus(procNotFound): throw FolderError.finderFailure("Open Finder, then try the shortcut again.")
        default: throw FolderError.finderFailure("Automation is unavailable (\(status)).")
        }
    }

    private func call(_ handler: String, arguments: [NSAppleEventDescriptor] = []) throws -> NSAppleEventDescriptor {
        // AppDelegate preflights permission asynchronously before reaching this main-thread script call.
        guard let script = NSAppleScript(source: Self.source) else { throw FolderError.finderFailure("Cannot load Finder controls.") }
        let event = NSAppleEventDescriptor(eventClass: AEEventClass(kASAppleScriptSuite), eventID: AEEventID(kASSubroutineEvent), targetDescriptor: nil, returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
        event.setParam(NSAppleEventDescriptor(string: handler), forKeyword: AEKeyword(keyASSubroutineName))
        let params = NSAppleEventDescriptor.list()
        for (index, value) in arguments.enumerated() { params.insert(value, at: index + 1) }
        event.setParam(params, forKeyword: AEKeyword(keyDirectObject))
        var error: NSDictionary?
        let result = script.executeAppleEvent(event, error: &error)
        if let error {
            if (error[NSAppleScript.errorNumber] as? Int) == Int(errAEEventNotPermitted) { throw FolderError.automationDenied }
            throw FolderError.finderFailure(error[NSAppleScript.errorMessage] as? String ?? "Try the shortcut again.")
        }
        return result
    }

    func windows() throws -> [FinderWindow] {
        let result = try call("listwindows")
        guard result.descriptorType == typeAEList else { throw FolderError.finderFailure("Unexpected window list. Try again.") }
        return try (0..<result.numberOfItems).map { offset in
            guard let item = result.atIndex(offset + 1), let id = item.atIndex(1),
                  let index = item.atIndex(2), let path = item.atIndex(3)?.stringValue, let isFrontmost = item.atIndex(4),
                  id.int32Value > 0, index.int32Value > 0, path.hasPrefix("/") else {
                throw FolderError.finderFailure("A Finder window could not be identified safely. Try again.")
            }
            return FinderWindow(id: id.int32Value, index: Int(index.int32Value), folder: URL(fileURLWithPath: path), isFrontmost: isFrontmost.booleanValue)
        }
    }

    func open(_ folder: URL) throws { _ = try call("openfolder", arguments: [.init(string: folder.path)]) }
    func focus(_ window: FinderWindow, folder: URL) throws { try act("focusfolder", window: window, folder: folder) }
    func close(_ window: FinderWindow, folder: URL, onlyIfFrontmost: Bool) throws {
        let result = try call("closefolder", arguments: [.init(int32: window.id), .init(string: folder.path), .init(boolean: onlyIfFrontmost)])
        guard result.booleanValue else { throw FolderError.windowChanged }
    }

    private func act(_ handler: String, window: FinderWindow, folder: URL) throws {
        let result = try call(handler, arguments: [.init(int32: window.id), .init(string: folder.path)])
        guard result.booleanValue else { throw FolderError.windowChanged }
    }

    // Paths are Apple-event parameters, never interpolated into executable script source.
    // Recheck the exact window ID and target immediately before closing or focusing it.
    static let source = """
    on listwindows()
        with timeout of 5 seconds
            tell application id "com.apple.finder"
                set found to {}
                repeat with w in (get Finder windows)
                    try
                        if closeable of w then
                            set isWindowFront to my isfrontwindow(id of w)
                            set end of found to {id of w, index of w, POSIX path of (target of w as alias), isWindowFront}
                        end if
                    on error messageText number errorCode
                        if errorCode is -1743 then error messageText number errorCode
                    end try
                end repeat
                return found
            end tell
        end timeout
    end listwindows

    on isfrontwindow(windowID)
        tell application id "com.apple.finder"
            if not frontmost then return false
            try
                return (id of front window is windowID) and not (collapsed of Finder window id windowID)
            on error
                return false
            end try
        end tell
    end isfrontwindow

    on openfolder(folderPath)
        set desiredFolder to (POSIX file folderPath) as alias
        with timeout of 5 seconds
            tell application id "com.apple.finder"
                make new Finder window to desiredFolder
                activate
            end tell
        end timeout
    end openfolder

    on focusfolder(windowID, folderPath)
        set desiredFolder to (POSIX file folderPath) as alias
        with timeout of 5 seconds
            tell application id "com.apple.finder"
                if not (exists Finder window id windowID) then return false
                set w to Finder window id windowID
                if (target of w as alias) is not desiredFolder then return false
                set collapsed of w to false
                set index of w to 1
                activate
                return true
            end tell
        end timeout
    end focusfolder

    on closefolder(windowID, folderPath, onlyIfFrontmost)
        set desiredFolder to (POSIX file folderPath) as alias
        with timeout of 5 seconds
            tell application id "com.apple.finder"
                if not (exists Finder window id windowID) then return false
                set w to Finder window id windowID
                if (target of w as alias) is not desiredFolder then return false
                -- Recheck focus at action time. A backgrounded window should be raised, not closed.
                if onlyIfFrontmost and not (my isfrontwindow(windowID)) then
                    set collapsed of w to false
                    set index of w to 1
                    activate
                    return true
                end if
                close w
                return true
            end tell
        end timeout
    end closefolder
    """
}
