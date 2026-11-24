import Foundation

/// What the ordering needs to know about a window, taken when a pass starts.
public struct WindowFacts: Equatable {
    public let id: UInt32
    public let appName: String
    public let title: String
    /// When the window last had focus (`systemUptime`), or nil if never seen focused.
    public let lastFocus: Double?
    /// Front-to-back position on the current Space, or nil when the window is not on screen.
    public let stackIndex: Int?

    public init(id: UInt32, appName: String, title: String, lastFocus: Double?, stackIndex: Int?) {
        self.id = id
        self.appName = appName
        self.title = title
        self.lastFocus = lastFocus
        self.stackIndex = stackIndex
    }
}

public enum WindowOrdering {
    public static func sorted(_ windows: [WindowFacts], by order: WindowOrder) -> [WindowFacts] {
        switch order {
            case .recent: return windows.sorted(by: isMoreRecent)
            // Window ids grow with creation, so they order windows by age.
            case .created: return windows.sorted { $0.id < $1.id }
            case .alphabetical: return windows.sorted(by: isAlphabeticallyBefore)
        }
    }

    /// Focus history first. A window never seen focused falls back to its stacking: the front-most window on
    /// screen is the one used last, which covers windows focused before the app started.
    private static func isMoreRecent(_ a: WindowFacts, _ b: WindowFacts) -> Bool {
        if a.lastFocus != b.lastFocus { return (a.lastFocus ?? -1) > (b.lastFocus ?? -1) }
        if a.stackIndex != b.stackIndex { return (a.stackIndex ?? Int.max) < (b.stackIndex ?? Int.max) }
        return a.id > b.id
    }

    private static func isAlphabeticallyBefore(_ a: WindowFacts, _ b: WindowFacts) -> Bool {
        let app = a.appName.localizedStandardCompare(b.appName)
        if app != .orderedSame { return app == .orderedAscending }
        let title = a.title.localizedStandardCompare(b.title)
        if title != .orderedSame { return title == .orderedAscending }
        return a.id < b.id
    }
}

/// One pass: the window order is frozen when it starts, so focusing a window (which makes it the most recent)
/// can't reshuffle the list under the next press and turn the pass into a toggle between two windows.
public struct CyclePass {
    public let ids: [UInt32]
    public private(set) var position: Int?

    /// `current` is the window the user is on; a pass steps away from it.
    public init(ids: [UInt32], current: UInt32?) {
        self.ids = ids
        position = current.flatMap { ids.firstIndex(of: $0) }
    }

    public var selected: UInt32? { position.map { ids[$0] } }

    /// Moves `delta` windows, wrapping. Without a current window, forward starts at the first and backward
    /// at the last.
    @discardableResult
    public mutating func step(_ delta: Int) -> UInt32? {
        guard !ids.isEmpty else { return nil }
        let count = ids.count
        if let position {
            self.position = ((position + delta) % count + count) % count
        } else {
            position = delta > 0 ? 0 : count - 1
        }
        return selected
    }
}
