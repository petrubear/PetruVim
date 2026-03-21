import Foundation
@testable import PetruVim

// MARK: - MockTextElement

final class MockTextElement: TextElementPort {
    var buffer: TextBuffer = TextBuffer("", cursor: 0)
    var writeCallCount = 0
    var lastWritten: TextBuffer?

    func readFocusedElement() throws -> TextBuffer { buffer }

    func updateFocusedElement(_ transform: (TextBuffer) throws -> TextBuffer?) throws {
        guard let newBuffer = try transform(buffer) else { return }
        buffer = newBuffer
        lastWritten = newBuffer
        writeCallCount += 1
    }
}

// MARK: - MockKeyboard

final class MockKeyboard: KeyboardPort {
    var onKeyEvent: ((KeyEvent) -> Bool)?
    var syntheticEvents: [KeyEvent] = []

    func startListening() {}
    func stopListening() {}
    func postSyntheticEvent(_ event: KeyEvent) { syntheticEvents.append(event) }

    @discardableResult
    func send(_ ch: Character) -> Bool {
        let event = KeyEvent(keyCode: 0, characters: String(ch), modifiers: [])
        return onKeyEvent?(event) ?? false
    }

    @discardableResult
    func sendEsc() -> Bool {
        let event = KeyEvent(keyCode: 53, characters: nil, modifiers: [])
        return onKeyEvent?(event) ?? false
    }
}

// MARK: - MockClipboard

final class MockClipboard: ClipboardPort {
    var contents: String?
    func read() -> String? { contents }
    func write(_ string: String) { contents = string }
}

// MARK: - MockNotifications

final class MockNotifications: NotificationPort {
    var postedModes: [VimMode] = []
    func postModeChange(_ mode: VimMode) { postedModes.append(mode) }
}

// MARK: - KeyEvent helpers

extension KeyEvent {
    static func char(_ ch: Character) -> KeyEvent {
        KeyEvent(keyCode: 0, characters: String(ch), modifiers: [])
    }
    static var esc: KeyEvent {
        KeyEvent(keyCode: 53, characters: nil, modifiers: [])
    }
}
