import AppKit
import Carbon

struct Binding: Codable, Identifiable, Equatable {
    var id = UUID()
    var appPath: String
    var keyCode: UInt32
    var modifiers: UInt32
    var keyLabel: String
    var hideOnRepeat: Bool
    var name: String { URL(fileURLWithPath: appPath).deletingPathExtension().lastPathComponent }
    var shortcut: String {
        (modifiers & UInt32(controlKey) != 0 ? "⌃" : "") +
        (modifiers & UInt32(optionKey) != 0 ? "⌥" : "") +
        (modifiers & UInt32(cmdKey) != 0 ? "⌘" : "") + keyLabel
    }
    func conflicts(with other: Binding) -> Bool {
        id != other.id && keyCode == other.keyCode && modifiers == other.modifiers
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
