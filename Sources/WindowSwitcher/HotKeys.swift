import Carbon.HIToolbox

/// Global hotkeys through Carbon's `RegisterEventHotKey`: no permission needed, and the key press is
/// swallowed, so the front app never sees it.
final class HotKeys {
    private var refs = [EventHotKeyRef]()
    private var actions = [UInt32: () -> Void]()
    private var nextId: UInt32 = 1
    private var handler: EventHandlerRef?

    init() {
        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            var hotKey = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                           nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKey)
            guard status == noErr, let context else { return status }
            Unmanaged<HotKeys>.fromOpaque(context).takeUnretainedValue().actions[hotKey.id]?()
            return noErr
        }, 1, &pressed, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }

    /// False when macOS refuses the combination, usually because another app already registered it.
    func register(keyCode: UInt32, modifiers: UInt32, _ action: @escaping () -> Void) -> Bool {
        let id = EventHotKeyID(signature: OSType(0x5753_5743), id: nextId) // "WSWC"
        var ref: EventHotKeyRef?
        guard RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &ref) == noErr, let ref else { return false }
        refs.append(ref)
        actions[nextId] = action
        nextId += 1
        return true
    }

    func unregisterAll() {
        refs.forEach { UnregisterEventHotKey($0) }
        refs.removeAll()
        actions.removeAll()
    }
}
