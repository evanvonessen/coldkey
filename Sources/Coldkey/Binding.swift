import AppKit
import Carbon

struct Binding: Codable, Identifiable, Equatable {
    enum TargetKind: String, Codable { case application, folder }
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
}
