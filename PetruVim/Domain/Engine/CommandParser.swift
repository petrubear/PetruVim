import Foundation

final class CommandParser {
    private var pendingOperator: VimOperator?
    private var countBuffer: String = ""
    private var awaitingChar: ((Character) -> VimCommand)?
    private var gPending: Bool = false

    func reset() {
        pendingOperator = nil
        countBuffer = ""
        awaitingChar = nil
        gPending = false
    }

    func feed(_ event: KeyEvent, mode: VimMode) -> VimCommand? {
        // Pass through command/option modified keys
        if event.isCommandModified || event.isOptionModified {
            return nil
        }

        // ESC always exits
        if event.keyCode == 53 {
            reset()
            return .exitToNormal
        }

        // Handle awaiting character (for f/F/t/T)
        if let handler = awaitingChar {
            awaitingChar = nil
            guard let chars = event.characters, let ch = chars.first else {
                reset()
                return nil
            }
            let cmd = handler(ch)
            let result = applyCount(to: cmd)
            reset()
            return result
        }

        guard let chars = event.characters, !chars.isEmpty else {
            return nil
        }

        let ch = chars.first!

        // Handle g prefix
        if gPending {
            gPending = false
            if ch == "g" {
                let cmd = resolveMotionOrOperator(.fileStart, mode: mode)
                let result = applyCount(to: cmd)
                reset()
                return result
            } else {
                reset()
                return nil
            }
        }

        // Count accumulation: digits 1-9 start count, 0 continues if count started
        if ch.isNumber {
            let digit = ch
            if digit == "0" && countBuffer.isEmpty {
                // 0 is lineStart motion
                let cmd = resolveMotionOrOperator(.lineStart, mode: mode)
                let result = applyCount(to: cmd)
                resetAfterCommand()
                return result
            } else {
                countBuffer.append(digit)
                return nil
            }
        }

        switch mode {
        case .normal:
            return feedNormal(ch)
        case .visual:
            return feedVisual(ch)
        case .insert:
            return nil
        }
    }

    // MARK: - Normal mode

    private func feedNormal(_ ch: Character) -> VimCommand? {
        // Motion keys
        if let motion = motionForChar(ch) {
            if let op = pendingOperator {
                let count = currentCount()
                let cmd = VimCommand.operatorMotion(count: count, op, motion)
                reset()
                return cmd
            }
            let cmd = VimCommand.motion(count: currentCount(), motion)
            resetAfterCommand()
            return cmd
        }

        // Awaiting character motions
        if ch == "f" || ch == "F" || ch == "t" || ch == "T" {
            let op = pendingOperator
            awaitingChar = { [self] foundChar in
                let motion: Motion
                switch ch {
                case "f": motion = .findForward(foundChar)
                case "F": motion = .findBackward(foundChar)
                case "t": motion = .tillForward(foundChar)
                case "T": motion = .tillBackward(foundChar)
                default: motion = .findForward(foundChar)
                }
                if let op = op {
                    return .operatorMotion(count: self.currentCount(), op, motion)
                }
                return .motion(count: self.currentCount(), motion)
            }
            return nil
        }

        // g prefix
        if ch == "g" {
            gPending = true
            return nil
        }

        // Operator keys
        if ch == "d" || ch == "c" || ch == "y" {
            let op: VimOperator
            switch ch {
            case "d": op = .delete
            case "c": op = .change
            case "y": op = .yank
            default: return nil
            }

            if let pending = pendingOperator, pending == op {
                // dd, cc, yy
                let count = currentCount()
                let cmd = VimCommand.operatorLine(count: count, op)
                reset()
                return cmd
            }

            pendingOperator = op
            return nil
        }

        // Insert entry points
        switch ch {
        case "i":
            let cmd = VimCommand.enterInsert(.i)
            reset()
            return cmd
        case "a":
            let cmd = VimCommand.enterInsert(.a)
            reset()
            return cmd
        case "I":
            let cmd = VimCommand.enterInsert(.I)
            reset()
            return cmd
        case "A":
            let cmd = VimCommand.enterInsert(.A)
            reset()
            return cmd
        case "o":
            let cmd = VimCommand.enterInsert(.o)
            reset()
            return cmd
        case "O":
            let cmd = VimCommand.enterInsert(.O)
            reset()
            return cmd
        default:
            break
        }

        // Visual mode
        if ch == "v" {
            reset()
            return .enterVisual
        }

        // Standalone operators
        if ch == "x" {
            let cmd = VimCommand.standalone(count: currentCount(), .deleteChar)
            reset()
            return cmd
        }
        if ch == "p" {
            let cmd = VimCommand.standalone(count: currentCount(), .paste(before: false))
            reset()
            return cmd
        }
        if ch == "P" {
            let cmd = VimCommand.standalone(count: currentCount(), .paste(before: true))
            reset()
            return cmd
        }
        if ch == "u" {
            let cmd = VimCommand.standalone(count: 1, .undo)
            reset()
            return cmd
        }
        if ch == "." {
            let cmd = VimCommand.standalone(count: 1, .repeatLast)
            reset()
            return cmd
        }

        // Ctrl-R for redo: check control modifier
        // Note: Ctrl-R comes through as characters "\u{12}" (ASCII 18)
        if ch == "\u{12}" {
            let cmd = VimCommand.standalone(count: 1, .redo)
            reset()
            return cmd
        }

        // G for fileEnd
        if ch == "G" {
            let cmd = resolveMotionOrOperator(.fileEnd, mode: .normal)
            let result = applyCount(to: cmd)
            resetAfterCommand()
            return result
        }

        // $ for lineEnd
        if ch == "$" {
            let cmd = resolveMotionOrOperator(.lineEnd, mode: .normal)
            let result = applyCount(to: cmd)
            resetAfterCommand()
            return result
        }

        // ^ for lineFirstNonBlank
        if ch == "^" {
            let cmd = resolveMotionOrOperator(.lineFirstNonBlank, mode: .normal)
            let result = applyCount(to: cmd)
            resetAfterCommand()
            return result
        }

        // _ for lineDown
        if ch == "_" {
            let cmd = resolveMotionOrOperator(.lineDown, mode: .normal)
            let result = applyCount(to: cmd)
            resetAfterCommand()
            return result
        }

        // Unknown key, reset
        reset()
        return nil
    }

    // MARK: - Visual mode

    private func feedVisual(_ ch: Character) -> VimCommand? {
        // Motion keys
        if let motion = motionForChar(ch) {
            let cmd = VimCommand.motion(count: currentCount(), motion)
            resetAfterCommand()
            return cmd
        }

        // Awaiting character motions
        if ch == "f" || ch == "F" || ch == "t" || ch == "T" {
            awaitingChar = { [self] foundChar in
                let motion: Motion
                switch ch {
                case "f": motion = .findForward(foundChar)
                case "F": motion = .findBackward(foundChar)
                case "t": motion = .tillForward(foundChar)
                case "T": motion = .tillBackward(foundChar)
                default: motion = .findForward(foundChar)
                }
                return .motion(count: self.currentCount(), motion)
            }
            return nil
        }

        if ch == "g" {
            gPending = true
            return nil
        }

        // Operator keys in visual mode
        if ch == "d" {
            reset()
            return .operatorVisual(.delete)
        }
        if ch == "c" {
            reset()
            return .operatorVisual(.change)
        }
        if ch == "y" {
            reset()
            return .operatorVisual(.yank)
        }

        // G, $, ^, _ motions
        if ch == "G" {
            let cmd = VimCommand.motion(count: currentCount(), .fileEnd)
            resetAfterCommand()
            return cmd
        }
        if ch == "$" {
            let cmd = VimCommand.motion(count: currentCount(), .lineEnd)
            resetAfterCommand()
            return cmd
        }
        if ch == "^" {
            let cmd = VimCommand.motion(count: currentCount(), .lineFirstNonBlank)
            resetAfterCommand()
            return cmd
        }
        if ch == "_" {
            let cmd = VimCommand.motion(count: currentCount(), .lineDown)
            resetAfterCommand()
            return cmd
        }

        reset()
        return nil
    }

    // MARK: - Helpers

    private func motionForChar(_ ch: Character) -> Motion? {
        switch ch {
        case "h": return .left
        case "l": return .right
        case "j": return .down
        case "k": return .up
        case "w": return .wordForward
        case "b": return .wordBackward
        case "e": return .wordEnd
        case "W": return .wordForwardBig
        case "B": return .wordBackwardBig
        case "E": return .wordEndBig
        default: return nil
        }
    }

    private func currentCount() -> Int {
        if countBuffer.isEmpty { return 1 }
        return Int(countBuffer) ?? 1
    }

    private func resetAfterCommand() {
        pendingOperator = nil
        countBuffer = ""
        awaitingChar = nil
        gPending = false
    }

    private func resolveMotionOrOperator(_ motion: Motion, mode: VimMode) -> VimCommand {
        if let op = pendingOperator {
            return .operatorMotion(count: currentCount(), op, motion)
        }
        return .motion(count: currentCount(), motion)
    }

    private func applyCount(to cmd: VimCommand) -> VimCommand {
        // Count is already embedded in the command from resolveMotionOrOperator
        return cmd
    }
}
