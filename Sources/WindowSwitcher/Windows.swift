import AppKit
import ApplicationServices
import SwitcherCore

/// Private but long-stable (used by most window managers): the CGWindowID behind an AX window element.
@_silgen_name("_AXUIElementGetWindow")
private func axWindowId(_ element: AXUIElement, _ id: UnsafeMutablePointer<CGWindowID>) -> AXError

struct SwitchableWindow {
    let id: CGWindowID
    let element: AXUIElement
    let app: NSRunningApplication
    let appName: String
    let title: String
}

/// Window list and focus, through the Accessibility API. Every call is an IPC round trip to the other app,
/// so each app element gets a short timeout: a hung app costs at most that, not a frozen switcher.
final class Windows {
    private static let messagingTimeout: Float = 0.2
    private var lastFocus = [CGWindowID: Double]()

    init() {
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
                                                          object: nil, queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.recordFocusedWindow(of: app)
        }
        if let front = NSWorkspace.shared.frontmostApplication { recordFocusedWindow(of: front) }
    }

    /// The windows of a pass, in the group's order, plus the one the user is on.
    func snapshot(_ spaces: SpaceScope, _ order: WindowOrder) -> (windows: [SwitchableWindow], current: CGWindowID?) {
        let current = NSWorkspace.shared.frontmostApplication.flatMap(focusedWindowId)
        if let current { lastFocus[current] = ProcessInfo.processInfo.systemUptime }
        let onScreen = onScreenStack()
        let windows = allWindows().filter { spaces == .all || onScreen[$0.id] != nil }
        let byId = Dictionary(windows.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let facts = windows.map { WindowFacts(id: $0.id, appName: $0.appName, title: $0.title,
                                              lastFocus: lastFocus[$0.id], stackIndex: onScreen[$0.id]) }
        return (WindowOrdering.sorted(facts, by: order).compactMap { byId[$0.id] }, current)
    }

    /// Fronts exactly this window (`WindowServer`), then raises it within its app. Without the private
    /// functions it falls back to activating the app, which can jump to another Space.
    func focus(_ window: SwitchableWindow) {
        if window.app.isHidden { window.app.unhide() }
        if WindowServer.isAvailable {
            WindowServer.focus(pid: window.app.processIdentifier, windowId: window.id)
        } else {
            AXUIElementSetAttributeValue(appElement(window.app.processIdentifier), kAXFrontmostAttribute as CFString, kCFBooleanTrue)
            window.app.activate(options: [])
        }
        AXUIElementSetAttributeValue(window.element, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(window.element, kAXRaiseAction as CFString)
        lastFocus[window.id] = ProcessInfo.processInfo.systemUptime
    }

    private func recordFocusedWindow(of app: NSRunningApplication) {
        guard let id = focusedWindowId(app) else { return }
        lastFocus[id] = ProcessInfo.processInfo.systemUptime
    }

    private func focusedWindowId(_ app: NSRunningApplication) -> CGWindowID? {
        let element: AXUIElement? = attribute(appElement(app.processIdentifier), kAXFocusedWindowAttribute)
        return element.flatMap(windowId)
    }

    private func allWindows() -> [SwitchableWindow] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.processIdentifier != getpid() }
            .flatMap { windows(of: $0) }
    }

    /// Standard windows only (no panels, sheets or palettes), and not minimized.
    private func windows(of app: NSRunningApplication) -> [SwitchableWindow] {
        let elements: [AXUIElement] = attribute(appElement(app.processIdentifier), kAXWindowsAttribute) ?? []
        return elements.compactMap { element in
            guard attribute(element, kAXSubroleAttribute) as String? == kAXStandardWindowSubrole,
                  attribute(element, kAXMinimizedAttribute) as Bool? != true,
                  let id = windowId(element) else { return nil }
            return SwitchableWindow(id: id, element: element, app: app, appName: app.localizedName ?? "",
                                    title: attribute(element, kAXTitleAttribute) ?? "")
        }
    }

    /// Window id → front-to-back position, for the windows on screen now: those of the current Space(s).
    private func onScreenStack() -> [CGWindowID: Int] {
        let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let ids = info.filter { ($0[kCGWindowLayer as String] as? Int) == 0 }.compactMap { $0[kCGWindowNumber as String] as? CGWindowID }
        return Dictionary(ids.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private func appElement(_ pid: pid_t) -> AXUIElement {
        let element = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(element, Self.messagingTimeout)
        return element
    }

    private func windowId(_ element: AXUIElement) -> CGWindowID? {
        var id: CGWindowID = 0
        guard axWindowId(element, &id) == .success, id != 0 else { return nil }
        return id
    }

    private func attribute<T>(_ element: AXUIElement, _ name: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success, let value else { return nil }
        return value as? T
    }
}
