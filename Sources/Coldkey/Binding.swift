import AppKit
import Carbon

struct Binding: Codable, Identifiable, Equatable {
    enum TargetKind: String, Codable { case application, folder, functionRow }
    var id = UUID()
    var appPath: String
    var keyCode: UInt32
    var modifiers: UInt32
    var keyLabel: String
    var hideOnRepeat: Bool
    var hideWhenNotFrontmost = false
    var targetKind: TargetKind = .application
    var folderBookmark: Data? = nil
    var closeFolderOnRepeat = false
    var closeFolderWhenNotFrontmost = false
    var name: String {
        if targetKind == .functionRow { return "Toggle Function Row" }
        let url = URL(fileURLWithPath: appPath)
        return targetKind == .folder ? url.lastPathComponent : url.deletingPathExtension().lastPathComponent
    }
    var shortcut: String {
        (modifiers & UInt32(controlKey) != 0 ? "⌃" : "") +
        (modifiers & UInt32(optionKey) != 0 ? "⌥" : "") +
        (modifiers & UInt32(cmdKey) != 0 ? "⌘" : "") + keyLabel
    }
    func conflicts(with other: Binding) -> Bool {
        id != other.id && keyCode == other.keyCode && modifiers == other.modifiers
    }

    static func functionRowDefault() -> Binding {
        Binding(id: UUID(uuidString: "B6C8841D-9DE5-42BF-AC3A-19780CEFE331")!, appPath: "",
                keyCode: UInt32(kVK_F12), modifiers: UInt32(cmdKey), keyLabel: "F12",
                hideOnRepeat: false, targetKind: .functionRow)
    }
}

extension Binding {
    private enum CodingKeys: String, CodingKey {
        case id, appPath, keyCode, modifiers, keyLabel, hideOnRepeat, hideWhenNotFrontmost
        case targetKind, folderBookmark, closeFolderOnRepeat, closeFolderWhenNotFrontmost
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        appPath = try values.decode(String.self, forKey: .appPath)
        keyCode = try values.decode(UInt32.self, forKey: .keyCode)
        modifiers = try values.decode(UInt32.self, forKey: .modifiers)
        keyLabel = try values.decode(String.self, forKey: .keyLabel)
        hideOnRepeat = try values.decode(Bool.self, forKey: .hideOnRepeat)
        hideWhenNotFrontmost = try values.decodeIfPresent(Bool.self, forKey: .hideWhenNotFrontmost) ?? false
        targetKind = try values.decodeIfPresent(TargetKind.self, forKey: .targetKind) ?? .application
        folderBookmark = try values.decodeIfPresent(Data.self, forKey: .folderBookmark)
        if values.contains(.closeFolderWhenNotFrontmost) {
            closeFolderOnRepeat = try values.decodeIfPresent(Bool.self, forKey: .closeFolderOnRepeat) ?? false
            closeFolderWhenNotFrontmost = try values.decode(Bool.self, forKey: .closeFolderWhenNotFrontmost)
        } else if targetKind == .folder {
            // The previous single folder option closed matching windows even in the background.
            closeFolderOnRepeat = false
            closeFolderWhenNotFrontmost = try values.decodeIfPresent(Bool.self, forKey: .closeFolderOnRepeat) ?? true
        }
    }
}

final class BindingStore {
    private static let functionRowMigrationKey = "functionRowShortcutAdded"
    private let defaults: UserDefaults
    private(set) var bindings: [Binding]
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        bindings = defaults.data(forKey: "bindings").flatMap { try? JSONDecoder().decode([Binding].self, from: $0) } ?? []
    }
    func save(_ bindings: [Binding]) throws {
        let data = try JSONEncoder().encode(bindings)
        defaults.set(data, forKey: "bindings")
        self.bindings = bindings
    }

    // Run only at a real app launch, rather than when a store is opened for editing or tests.
    // Remember the first attempt so a deliberately removed or rebound shortcut stays removed.
    func ensureFunctionRowShortcut() throws -> String? {
        guard !defaults.bool(forKey: Self.functionRowMigrationKey) else { return nil }
        let shortcut = Binding.functionRowDefault()
        var warning: String?
        var updated = bindings
        if !bindings.contains(where: { $0.targetKind == .functionRow }) {
            if let existing = bindings.first(where: { $0.keyCode == shortcut.keyCode && $0.modifiers == shortcut.modifiers }) {
                warning = "⌘F12 is already assigned to \(existing.name). Add a Function Row shortcut with another key to toggle the function row."
            } else {
                updated.append(shortcut)
            }
        }
        try save(updated)
        defaults.set(true, forKey: Self.functionRowMigrationKey)
        return warning
    }
}
