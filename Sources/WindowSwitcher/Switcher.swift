import AppKit
import SwitcherCore

/// Turns presses into passes. A pass starts at the first press of a group, keeps the window order it found,
/// and ends when that group's hold modifiers are released.
final class Switcher {
    private struct Pass {
        let groupIndex: Int
        var cycle: CyclePass
        let windows: [CGWindowID: SwitchableWindow]
    }

    private let windows: Windows
    private let overlay = Overlay()
    private var groups = [SwitcherGroup]()
    private var pass: Pass?

    init(windows: Windows) {
        self.windows = windows
    }

    func configure(_ groups: [SwitcherGroup]) {
        end()
        self.groups = groups
    }

    func step(group groupIndex: Int, _ delta: Int) {
        if pass?.groupIndex != groupIndex { end() }
        if pass == nil { pass = startPass(groupIndex) }
        guard var current = pass, let id = current.cycle.step(delta), let window = current.windows[id] else { return }
        pass = current
        if groups[groupIndex].instant {
            windows.focus(window)
        } else {
            overlay.show(window.title.isEmpty ? window.appName : "\(window.appName) – \(window.title)")
        }
        // The hold can be released before the hotkey reaches us, and then no later modifier change ends the pass.
        modifiersChanged(NSEvent.modifierFlags)
    }

    func modifiersChanged(_ flags: NSEvent.ModifierFlags) {
        guard let pass, !holdIsDown(groups[pass.groupIndex], flags) else { return }
        end()
    }

    private func startPass(_ groupIndex: Int) -> Pass {
        let group = groups[groupIndex]
        let snapshot = windows.snapshot(group.spaces, group.order)
        let byId = Dictionary(snapshot.windows.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return Pass(groupIndex: groupIndex, cycle: CyclePass(ids: snapshot.windows.map(\.id), current: snapshot.current), windows: byId)
    }

    private func end() {
        guard let ended = pass else { return }
        pass = nil
        overlay.hide()
        if !groups[ended.groupIndex].instant, let id = ended.cycle.selected, let window = ended.windows[id] {
            windows.focus(window)
        }
    }

    private func holdIsDown(_ group: SwitcherGroup, _ flags: NSEvent.ModifierFlags) -> Bool {
        !flags.intersection(KeyCodes.eventModifiers(group.hold)).isEmpty
    }
}

/// The small title box shown while choosing in a non-instant group. A non-activating panel, so showing it
/// never takes focus away from the app the user is in.
final class Overlay {
    private let panel: NSPanel
    private let label = NSTextField(labelWithString: "")

    init() {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let background = NSVisualEffectView()
        background.material = .hudWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 12
        label.font = .systemFont(ofSize: 18, weight: .medium)
        label.lineBreakMode = .byTruncatingMiddle
        label.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -24),
            label.centerYAnchor.constraint(equalTo: background.centerYAnchor),
        ])
        panel.contentView = background
    }

    func show(_ text: String) {
        label.stringValue = text
        guard let screen = NSScreen.main else { return }
        let width = min(max(label.intrinsicContentSize.width + 48, 240), screen.visibleFrame.width * 0.6)
        let size = NSSize(width: width, height: 56)
        let origin = NSPoint(x: screen.visibleFrame.midX - size.width / 2, y: screen.visibleFrame.midY - size.height / 2)
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }
}
