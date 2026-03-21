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
            mode = .visual
            if let buffer = try? textElement.readFocusedElement() {
                let offset = buffer.cursorOffset
                visualAnchor = offset
                // Show initial 1-char selection at the cursor
                let selEnd = min(offset + 1, buffer.text.count)
                let initial = TextBuffer(buffer.text, cursor: offset, selection: offset..<selEnd)
                try? textElement.writeFocusedElement(initial)
            }
            notifications.postModeChange(.visual)

        case .motion(let count, let motion):
            guard let buffer = try? textElement.readFocusedElement() else { return }
            let anchor = mode == .visual ? visualAnchor : nil
            let result = MotionResolver.apply(motion, count: count, to: buffer, visualAnchor: anchor)
            try? textElement.writeFocusedElement(result)

        case .operatorMotion(let count, let op, let motion):
            guard let buffer = try? textElement.readFocusedElement() else { return }
            let result = OperatorResolver.apply(op, motion: motion, count: count, buffer: buffer, register: register, lastChange: lastChange)
            try? textElement.writeFocusedElement(result.buffer)
            if let yanked = result.yankedText {
                register = yanked
                clipboard.write(yanked)
            }
            if op == .change {
                mode = .insert
                notifications.postModeChange(.insert)
            }
            saveLastChange(command)

        case .operatorLine(let count, let op):
            guard let buffer = try? textElement.readFocusedElement() else { return }
            let result = OperatorResolver.applyToLine(op, count: count, buffer: buffer)
            try? textElement.writeFocusedElement(result.buffer)
            if let yanked = result.yankedText {
                register = yanked
                clipboard.write(yanked)
            }
            if op == .change {
                mode = .insert
                notifications.postModeChange(.insert)
            }
            saveLastChange(command)

        case .operatorVisual(let op):
            guard let buffer = try? textElement.readFocusedElement() else { return }
            let result = OperatorResolver.applyToVisualSelection(op, buffer: buffer)
            try? textElement.writeFocusedElement(result.buffer)
            if let yanked = result.yankedText {
                register = yanked
                clipboard.write(yanked)
            }
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
        }
    }

    // MARK: - Standalone operators

    private func executeStandalone(_ op: VimOperator, count: Int) {
        switch op {
        case .deleteChar:
            guard let buffer = try? textElement.readFocusedElement() else { return }
            let result = OperatorResolver.apply(.deleteChar, motion: .right, count: count, buffer: buffer, register: register, lastChange: lastChange)
            try? textElement.writeFocusedElement(result.buffer)
            if let yanked = result.yankedText {
                register = yanked
                clipboard.write(yanked)
            }
            saveLastChange(.standalone(count: count, .deleteChar))

        case .paste(let before):
            // Read from clipboard if register is empty
            if register == nil {
                register = clipboard.read()
            }
            guard let buffer = try? textElement.readFocusedElement() else { return }
            let result = OperatorResolver.apply(.paste(before: before), motion: .right, count: 1, buffer: buffer, register: register, lastChange: lastChange)
            try? textElement.writeFocusedElement(result.buffer)
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
        guard let buffer = try? textElement.readFocusedElement() else { return }

        switch ep {
        case .i:
            // Cursor stays in place
            break

        case .a:
            // Move cursor right by 1, allowing past the last char (insert mode semantics)
            let newOffset = min(buffer.cursorOffset + 1, buffer.text.count)
            try? textElement.writeFocusedElement(TextBuffer(buffer.text, cursor: newOffset))

        case .I:
            // Move to first non-blank of line
            let result = MotionResolver.apply(.lineFirstNonBlank, count: 1, to: buffer)
            try? textElement.writeFocusedElement(result)

        case .A:
            // Move to end of line
            let text = buffer.text
            let lineEnd = buffer.lineEndIndex
            let offset = text.distance(from: text.startIndex, to: lineEnd)
            let result = TextBuffer(text, cursor: offset)
            try? textElement.writeFocusedElement(result)

        case .o:
            // Insert newline below current line, cursor on new line
            var text = buffer.text
            let lineEnd = buffer.lineEndIndex
            text.insert("\n", at: lineEnd)
            let offset = text.distance(from: text.startIndex, to: lineEnd) + 1
            let result = TextBuffer(text, cursor: offset)
            try? textElement.writeFocusedElement(result)

        case .O:
            // Insert newline above current line, cursor on new line
            var text = buffer.text
            let lineStart = buffer.lineStartIndex
            text.insert("\n", at: lineStart)
            let offset = text.distance(from: text.startIndex, to: lineStart)
            let result = TextBuffer(text, cursor: offset)
            try? textElement.writeFocusedElement(result)
        }
    }

    // MARK: - Helpers

    private func saveLastChange(_ command: VimCommand) {
        switch command {
        case .motion,
             .standalone(_, .undo),
             .standalone(_, .redo),
             .standalone(_, .repeatLast):
            break
        default:
            lastChange = command
        }
    }
}
