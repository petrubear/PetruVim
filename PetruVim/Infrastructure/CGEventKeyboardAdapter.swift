import Cocoa
import CoreGraphics

final class CGEventKeyboardAdapter: KeyboardPort {
    var onKeyEvent: ((KeyEvent) -> Bool)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isSendingSyntheticEvent = false

    func startListening() {
        let trusted = AXIsProcessTrusted()
        let listenAccess = CGPreflightListenEventAccess()
        NSLog("[PetruVim] startListening: AXIsProcessTrusted=%@ CGPreflightListenEventAccess=%@",
              trusted ? "YES" : "NO", listenAccess ? "YES" : "NO")

        if !listenAccess {
            CGRequestListenEventAccess()
        }

        let keyDownMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let tapDisabledMask = CGEventMask(1 << CGEventType.tapDisabledByTimeout.rawValue)
            | CGEventMask(1 << CGEventType.tapDisabledByUserInput.rawValue)
        let eventMask = keyDownMask | tapDisabledMask

        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { proxy, type, event, refcon in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let adapter = Unmanaged<CGEventKeyboardAdapter>.fromOpaque(refcon).takeUnretainedValue()
                return adapter.handleCGEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let tap = tap else {
            NSLog("[PetruVim] CGEvent.tapCreate returned nil — key interception disabled. Ensure Accessibility is granted.")
            return
        }

        NSLog("[PetruVim] CGEvent tap created successfully")
        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stopListening() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    func postSyntheticEvent(_ event: KeyEvent) {
        guard let cgEvent = CGEvent(keyboardEventSource: nil, virtualKey: event.keyCode, keyDown: true) else { return }

        var flags = CGEventFlags()
        if event.modifiers.contains(.command) { flags.insert(.maskCommand) }
        if event.modifiers.contains(.shift) { flags.insert(.maskShift) }
        if event.modifiers.contains(.control) { flags.insert(.maskControl) }
        if event.modifiers.contains(.option) { flags.insert(.maskAlternate) }
        cgEvent.flags = flags

        isSendingSyntheticEvent = true
        cgEvent.post(tap: .cgSessionEventTap)
        isSendingSyntheticEvent = false
    }

    private func handleCGEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Ignore events we generated ourselves (undo/redo synthetic events) to prevent re-entrancy loops.
        if isSendingSyntheticEvent { return Unmanaged.passUnretained(event) }

        // macOS disables the tap if the callback is too slow. Re-enable it immediately.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            NSLog("[PetruVim] CGEvent tap was disabled (%@) — re-enabling", type == .tapDisabledByTimeout ? "timeout" : "userInput")
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return nil
        }

        guard type == .keyDown else { return Unmanaged.passUnretained(event) }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        var modifiers = KeyEvent.Modifiers()
        if flags.contains(.maskShift)     { modifiers.insert(.shift) }
        if flags.contains(.maskControl)   { modifiers.insert(.control) }
        if flags.contains(.maskAlternate) { modifiers.insert(.option) }
        if flags.contains(.maskCommand)   { modifiers.insert(.command) }

        // Get characters
        var length = 0
        event.keyboardGetUnicodeString(maxStringLength: 0, actualStringLength: &length, unicodeString: nil)
        var chars = [UniChar](repeating: 0, count: max(length, 1))
        event.keyboardGetUnicodeString(maxStringLength: chars.count, actualStringLength: &length, unicodeString: &chars)
        let characters = length > 0 ? String(utf16CodeUnits: chars, count: length) : nil

        let keyEvent = KeyEvent(keyCode: keyCode, characters: characters, modifiers: modifiers)

        if let handler = onKeyEvent, handler(keyEvent) {
            return nil  // suppress
        }
        return Unmanaged.passUnretained(event)
    }
}
