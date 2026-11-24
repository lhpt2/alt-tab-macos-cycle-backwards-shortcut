import AppKit
import SwitcherCore

/// `WindowSwitcher --keycodes` prints the code of every key pressed, for keys without a name in `KeyCodes`.
if CommandLine.arguments.contains("--keycodes") {
    print("Tasten drücken, Ctrl-C beendet. Braucht die Berechtigung \"Bedienungshilfen\" für das Terminal.")
    NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { print("keyCode \($0.keyCode)  \($0.charactersIgnoringModifiers ?? "")") }
    NSApplication.shared.setActivationPolicy(.accessory)
    NSApplication.shared.run()
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    static let configURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/window-switcher/config.json")

    private let hotKeys = HotKeys()
    private var windows: Windows?
    private var switcher: Switcher?
    private var statusItem: NSStatusItem?
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        makeStatusItem()
        // AX calls (window list, focus) and the release monitor need "Accessibility"; hotkeys alone would not.
        let prompt = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if AXIsProcessTrustedWithOptions(prompt) { return start() }
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
            guard AXIsProcessTrusted() else { return }
            timer.invalidate()
            self?.start()
        }
    }

    private func start() {
        let windows = Windows()
        let switcher = Switcher(windows: windows)
        self.windows = windows
        self.switcher = switcher
        // Global: modifier changes while another app is in front. Local: while our own overlay or menu is.
        NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak switcher] event in switcher?.modifiersChanged(event.modifierFlags) }
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak switcher] event in
            switcher?.modifiersChanged(event.modifierFlags)
            return event
        }
        reloadConfig()
    }

    @objc private func reloadConfig() {
        guard let switcher else { return }
        hotKeys.unregisterAll()
        let config: SwitcherConfig
        do {
            config = try loadConfig()
        } catch {
            return alert("Konfiguration nicht lesbar", "\(Self.configURL.path)\n\n\(error)")
        }
        var problems = config.problems()
        guard problems.isEmpty else { return alert("Konfiguration fehlerhaft", problems.joined(separator: "\n")) }
        switcher.configure(config.groups)
        for (index, group) in config.groups.enumerated() {
            for (bindings, delta) in [(group.forward, 1), (group.backward, -1)] {
                for binding in bindings {
                    guard let code = KeyCodes.code(binding.key) else {
                        problems.append("Gruppe \(index + 1): unbekannte Taste \"\(binding.key)\"")
                        continue
                    }
                    let registered = hotKeys.register(keyCode: code, modifiers: KeyCodes.carbonModifiers(binding.modifiers)) { [weak switcher] in
                        switcher?.step(group: index, delta)
                    }
                    if !registered { problems.append("Gruppe \(index + 1): \(binding.modifiers) + \(binding.key) ist schon belegt") }
                }
            }
        }
        if !problems.isEmpty { alert("Nicht alle Tasten aktiv", problems.joined(separator: "\n")) }
    }

    /// Writes the default config on first launch, so the user has a file to edit.
    private func loadConfig() throws -> SwitcherConfig {
        let url = Self.configURL
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try SwitcherConfig.default.encoded().write(to: url)
        }
        return try SwitcherConfig.decode(Data(contentsOf: url))
    }

    private func makeStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "⇥"
        let menu = NSMenu()
        menu.addItem(withTitle: "Konfiguration öffnen", action: #selector(openConfig), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Konfiguration neu laden", action: #selector(reloadConfig), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
    }

    @objc private func openConfig() {
        _ = try? loadConfig()
        NSWorkspace.shared.open(Self.configURL)
    }

    private func alert(_ title: String, _ text: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.setActivationPolicy(.accessory)
NSApplication.shared.run()
