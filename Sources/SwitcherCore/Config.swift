import Foundation

public enum SpaceScope: String, Codable {
    case current
    case all
}

public enum WindowOrder: String, Codable {
    /// Most recently focused first; switching changes the order.
    case recent
    /// Fixed: oldest window first.
    case created
    /// Fixed: by app name, then window title.
    case alphabetical
}

public struct KeyBinding: Codable, Equatable {
    public var modifiers: [String]
    /// A key name (see `KeyCodes` in the app target) or a raw virtual keycode such as "50".
    public var key: String

    public init(modifiers: [String], key: String) {
        self.modifiers = modifiers
        self.key = key
    }
}

public struct SwitcherGroup: Codable, Equatable {
    /// While any of these modifiers is held, presses belong to one pass; releasing them ends it.
    public var hold: [String]
    public var forward: [KeyBinding]
    public var backward: [KeyBinding]
    public var spaces: SpaceScope
    public var order: WindowOrder
    /// true: every press focuses its window. false: presses only select, the release focuses.
    public var instant: Bool

    public init(hold: [String], forward: [KeyBinding], backward: [KeyBinding], spaces: SpaceScope, order: WindowOrder, instant: Bool) {
        self.hold = hold
        self.forward = forward
        self.backward = backward
        self.spaces = spaces
        self.order = order
        self.instant = instant
    }
}

public struct SwitcherConfig: Codable, Equatable {
    public var groups: [SwitcherGroup]

    public init(groups: [SwitcherGroup]) {
        self.groups = groups
    }

    public static let `default` = SwitcherConfig(groups: [
        SwitcherGroup(hold: ["option"],
                      forward: [KeyBinding(modifiers: ["option"], key: "tab")],
                      backward: [KeyBinding(modifiers: ["option", "shift"], key: "tab")],
                      spaces: .all, order: .recent, instant: true),
        SwitcherGroup(hold: ["option"],
                      forward: [KeyBinding(modifiers: ["option"], key: "^")],
                      backward: [KeyBinding(modifiers: ["option", "shift"], key: "^")],
                      spaces: .current, order: .recent, instant: true),
    ])

    public static func decode(_ data: Data) throws -> SwitcherConfig {
        try JSONDecoder().decode(SwitcherConfig.self, from: data)
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    /// Problems that make a group unusable, as messages for the user. Empty when the config is fine.
    public func problems() -> [String] {
        groups.enumerated().flatMap { index, group in Self.problems(group, "Gruppe \(index + 1)") }
    }

    private static func problems(_ group: SwitcherGroup, _ name: String) -> [String] {
        var problems = [String]()
        let hold = Set(group.hold.map(Modifier.normalized))
        if group.hold.isEmpty { problems.append("\(name): \"hold\" ist leer") }
        problems += group.hold.filter { Modifier.normalized($0) == nil }.map { "\(name): unbekannter Modifier \"\($0)\"" }
        for binding in group.forward + group.backward {
            let modifiers = binding.modifiers.map(Modifier.normalized)
            problems += zip(binding.modifiers, modifiers).filter { $1 == nil }.map { "\(name): unbekannter Modifier \"\($0.0)\"" }
            // A press without the hold modifiers would start a pass that its own release could never end.
            if !hold.isSubset(of: Set(modifiers)) {
                problems.append("\(name): \(binding.modifiers) + \(binding.key) enthält nicht alle hold-Modifier \(group.hold)")
            }
        }
        return problems
    }
}

/// Modifier names accepted in the config, mapped to one canonical name each.
public enum Modifier {
    public static func normalized(_ name: String) -> String? {
        switch name.lowercased() {
            case "command", "cmd", "⌘": return "command"
            case "option", "alt", "opt", "⌥": return "option"
            case "control", "ctrl", "⌃": return "control"
            case "shift", "⇧": return "shift"
            default: return nil
        }
    }
}
