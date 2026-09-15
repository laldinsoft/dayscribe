import Carbon
import DayScribeCore

@MainActor
final class GlobalShortcutManager {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var keyIsDown = false
    var onPress: (() -> Void)?

    func register() throws {
        var events = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, data in
            guard let data, let event else { return OSStatus(eventNotHandledErr) }
            var identifier = EventHotKeyID()
            let result = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier)
            guard result == noErr, identifier.signature == 0x44534352, identifier.id == 1 else {
                return OSStatus(eventNotHandledErr)
            }
            // Carbon delivers this application event on the main thread.
            MainActor.assumeIsolated {
                let manager = Unmanaged<GlobalShortcutManager>.fromOpaque(data).takeUnretainedValue()
                if GetEventKind(event) == UInt32(kEventHotKeyReleased) {
                    manager.keyIsDown = false
                } else if !manager.keyIsDown {
                    manager.keyIsDown = true
                    manager.onPress?()
                }
            }
            return noErr
        }, events.count, &events, pointer, &handler)
        guard status == noErr else {
            throw DayScribeError.message("Could not install the global shortcut (\(status)). Use the menu to record.")
        }
        let key = EventHotKeyID(signature: 0x44534352, id: 1)
        let result = RegisterEventHotKey(UInt32(kVK_ANSI_N), UInt32(controlKey | optionKey), key,
                                        GetApplicationEventTarget(), 0, &hotKey)
        guard result == noErr else {
            throw DayScribeError.message("Control–Option–N is unavailable (\(result)). Another app may be using it. You can still record from the menu.")
        }
    }

    func unregister() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
        hotKey = nil
        handler = nil
        keyIsDown = false
    }
}
