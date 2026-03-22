import Foundation

@MainActor
final class VimEngine {
    private(set) var mode: VimMode = .normal

    private let textElement: TextElementPort
    private let keyboard: KeyboardPort
    private let clipboard: ClipboardPort
    private let notifications: NotificationPort

    private let parser = CommandParser()
    private var register: String?
    private var lastChange: VimCommand?
    private var visualAnchor: Int?  // stored as offset to be safe across String instances

    init(
        textElement: TextElementPort,
        keyboard: KeyboardPort,
        clipboard: ClipboardPort,
        notifications: NotificationPort
    ) {
        self.textElement = textElement
        self.keyboard = keyboard
        self.clipboard = clipboard
        self.notifications = notifications
    }

    func start() {
        keyboard.onKeyEvent = { [weak self] event in
            guard let self else { return false }
            return MainActor.assumeIsolated { self.handleKeyEvent(event) }
        }
        keyboard.startListening()
    }

    func stop() {
        keyboard.stopListening()
    }

    // MARK: - Key handling

    private func handleKeyEvent(_ event: KeyEvent) -> Bool {
        if event.isCommandModified || event.isOptionModified {
            return false
        }

        switch mode {
        case .insert:
            if event.keyCode == 53 {
                // ESC - exit insert mode
                mode = .normal
                parser.reset()
                notifications.postModeChange(.normal)
                return true
            }
            return false

        case .normal, .visual:
            return handleCommandMode(event)
        }
    }

    private func handleCommandMode(_ event: KeyEvent) -> Bool {
        guard let command = parser.feed(event, mode: mode) else {
            return true // Suppress key, waiting for more input
        }
        if case .passThrough = command { return false }
        executeCommand(command)
        return true
    }

    // MARK: - Command execution

    private func executeCommand(_ command: VimCommand) {
        switch command {
        case .exitToNormal:
            mode = .normal
            visualAnchor = nil
            parser.reset()
            notifications.postModeChange(.normal)

        case .enterInsert(let ep):
            mode = .insert
            applyInsertEntryPoint(ep)
            notifications.postModeChange(.insert)

        case .enterVisual:
            var anchor: Int?
            try? textElement.updateFocusedElement { buffer in
                anchor = buffer.cursorOffset
                let selEnd = min(buffer.cursorOffset + 1, buffer.text.count)
                return TextBuffer(buffer.text, cursor: buffer.cursorOffset, selection: buffer.cursorOffset..<selEnd)
            }
            guard let anchor else { return }  // AX failed — stay in current mode
            mode = .visual
            visualAnchor = anchor
            notifications.postModeChange(.visual)

        case .motion(let count, let motion):
            let anchor = mode == .visual ? visualAnchor : nil
            try? textElement.updateFocusedElement { buffer in
                MotionResolver.apply(motion, count: count, to: buffer, visualAnchor: anchor)
            }

        case .operatorMotion(let count, let op, let motion):
            var yanked: String?
            try? textElement.updateFocusedElement { [self] buffer in
                let result = OperatorResolver.apply(op, motion: motion, count: count, buffer: buffer, register: register)
                yanked = result.yankedText
                return result.buffer
            }
            if let y = yanked { register = y; clipboard.write(y) }
            if op == .change { mode = .insert; notifications.postModeChange(.insert) }
            saveLastChange(command)

        case .operatorLine(let count, let op):
            var yanked: String?
            try? textElement.updateFocusedElement { buffer in
                let result = OperatorResolver.applyToLine(op, count: count, buffer: buffer)
                yanked = result.yankedText
                return result.buffer
            }
            if let y = yanked { register = y; clipboard.write(y) }
            if op == .change { mode = .insert; notifications.postModeChange(.insert) }
            saveLastChange(command)

        case .operatorVisual(let op):
            var yanked: String?
            try? textElement.updateFocusedElement { buffer in
                let result = OperatorResolver.applyToVisualSelection(op, buffer: buffer)
                yanked = result.yankedText
                return result.buffer
            }
            if let y = yanked { register = y; clipboard.write(y) }
            mode = .normal
            visualAnchor = nil
            if op == .change {
                mode = .insert
                notifications.postModeChange(.insert)
            } else {
                notifications.postModeChange(.normal)
            }
            saveLastChange(command)

        case .standalone(let count, let op):
            executeStandalone(op, count: count)

        case .passThrough:
            break
        }
    }

    // MARK: - Standalone operators

    private func executeStandalone(_ op: VimOperator, count: Int) {
        switch op {
        case .deleteChar:
            var yanked: String?
            try? textElement.updateFocusedElement { buffer in
                // motion: .right and register are ignored by deleteChar; passing nil to make that explicit
                let result = OperatorResolver.apply(.deleteChar, motion: .right, count: count, buffer: buffer, register: nil)
                yanked = result.yankedText
                return result.buffer
            }
            if let y = yanked { register = y; clipboard.write(y) }
            saveLastChange(.standalone(count: count, .deleteChar))

        case .paste(let before):
            if register == nil { register = clipboard.read() }
            try? textElement.updateFocusedElement { [self] buffer in
                OperatorResolver.apply(
                    .paste(before: before), motion: .right, count: count,
                    buffer: buffer, register: register).buffer
            }
            saveLastChange(.standalone(count: count, .paste(before: before)))

        case .undo:
            let event = KeyEvent(keyCode: 6, characters: "z", modifiers: .command)
            keyboard.postSyntheticEvent(event)

        case .redo:
            let event = KeyEvent(keyCode: 6, characters: "z", modifiers: [.command, .shift])
            keyboard.postSyntheticEvent(event)

        case .repeatLast:
            if let last = lastChange {
                executeCommand(last)
            }

        default:
            break
        }
    }

    // MARK: - Insert entry points

    private func applyInsertEntryPoint(_ ep: InsertEntryPoint) {
        switch ep {
        case .i:
            break // Cursor stays in place — no AX call needed

        case .a:
            try? textElement.updateFocusedElement { buffer in
                let newOffset = min(buffer.cursorOffset + 1, buffer.text.count)
                return TextBuffer(buffer.text, cursor: newOffset)
            }

        case .I:
            try? textElement.updateFocusedElement { buffer in
                MotionResolver.apply(.lineFirstNonBlank, count: 1, to: buffer)
            }

        case .A:
            try? textElement.updateFocusedElement { buffer in
                let offset = buffer.text.distance(from: buffer.text.startIndex, to: buffer.lineEndIndex)
                return TextBuffer(buffer.text, cursor: offset)
            }

        case .o:
            try? textElement.updateFocusedElement { buffer in
                var text = buffer.text
                let lineEnd = buffer.lineEndIndex
                text.insert("\n", at: lineEnd)
                let offset = text.distance(from: text.startIndex, to: lineEnd) + 1
                return TextBuffer(text, cursor: offset)
            }

        case .O:
            try? textElement.updateFocusedElement { buffer in
                var text = buffer.text
                let lineStart = buffer.lineStartIndex
                text.insert("\n", at: lineStart)
                let offset = text.distance(from: text.startIndex, to: lineStart)
                return TextBuffer(text, cursor: offset)
            }
        }
    }

    // MARK: - Helpers

    private func saveLastChange(_ command: VimCommand) {
        switch command {
        case .motion,
             .passThrough,
             .standalone(_, .undo),
             .standalone(_, .redo),
             .standalone(_, .repeatLast):
            break
        default:
            lastChange = command
        }
    }
}
