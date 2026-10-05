import AppKit

enum FolderError: LocalizedError {
    case unavailable, automationRequired, automationDenied, windowChanged
    case finderFailure(String)

    var errorDescription: String? {
        switch self {
        case .unavailable: return "The folder could not be found or accessed. Edit its shortcut and choose the folder again."
        case .automationRequired: return "Allow Coldkey to control Finder to open and close the selected folder's window."
        case .automationDenied: return "Allow Finder under System Settings → Privacy & Security → Automation → Coldkey, then try again."
        case .windowChanged: return "That Finder window changed before Coldkey could act. Press the shortcut again."
        case .finderFailure(let message): return "Finder could not finish: \(message)"
        }
    }
}

enum FolderLocation {
    static func canonical(_ url: URL) -> URL { url.standardizedFileURL.resolvingSymlinksInPath() }

    static func select(_ url: URL, for binding: Binding) throws -> Binding {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let folder = canonical(url)
        let values = try folder.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
        guard values.isDirectory == true, values.isPackage != true else { throw FolderError.unavailable }
        var selected = binding
        selected.targetKind = .folder
        selected.appPath = folder.path
        // This app is not sandboxed. A regular bookmark tracks folder moves without broader permissions.
        selected.folderBookmark = try folder.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        return selected
    }

    static func resolve(_ binding: Binding) throws -> Binding {
        do {
            var stale = false
            let url: URL
            if let bookmark = binding.folderBookmark {
                url = try URL(resolvingBookmarkData: bookmark, options: [.withoutUI, .withoutMounting], relativeTo: nil, bookmarkDataIsStale: &stale)
            } else {
                url = URL(fileURLWithPath: binding.appPath)
            }
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let folder = canonical(url)
            let values = try folder.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
            guard values.isDirectory == true, values.isPackage != true else { throw FolderError.unavailable }
            if stale || folder.path != binding.appPath || binding.folderBookmark == nil {
                return try select(folder, for: binding)
            }
            return binding
        } catch { throw FolderError.unavailable }
    }
}

struct FinderWindow: Equatable {
    let id: Int32
    let index: Int
    let folder: URL
}

protocol FinderControlling {
    func windows() throws -> [FinderWindow]
    func open(_ folder: URL) throws
    func focus(_ window: FinderWindow, folder: URL) throws
    func close(_ window: FinderWindow, folder: URL) throws
}

final class FolderLauncher {
    private let finder: FinderControlling
    init(finder: FinderControlling = FinderAutomation()) { self.finder = finder }

    func run(_ binding: Binding) throws -> Binding {
        let resolved = try FolderLocation.resolve(binding)
        let folder = URL(fileURLWithPath: resolved.appPath)
        let access = folder.startAccessingSecurityScopedResource()
        defer { if access { folder.stopAccessingSecurityScopedResource() } }
        let matches = try finder.windows().filter { FolderLocation.canonical($0.folder) == folder }
        // One action only: choose the frontmost matching window, with a stable ID tie-breaker.
        if let window = matches.min(by: { ($0.index, $0.id) < ($1.index, $1.id) }) {
            if resolved.closeFolderOnRepeat { try finder.close(window, folder: folder) }
            else { try finder.focus(window, folder: folder) }
        } else {
            try finder.open(folder)
        }
        return resolved
    }
}
