import Foundation

struct OperatorResult {
    var buffer: TextBuffer
    var yankedText: String? = nil
}

enum OperatorResolver {

    static func apply(
        _ op: VimOperator,
        motion: Motion,
        count: Int,
        buffer: TextBuffer,
        register: String?,
        lastChange: VimCommand?
    ) -> OperatorResult {
        switch op {
        case .delete:
            return deleteWithMotion(motion: motion, count: count, buffer: buffer)

        case .change:
            return changeWithMotion(motion: motion, count: count, buffer: buffer)

        case .yank:
            return yankWithMotion(motion: motion, count: count, buffer: buffer)

        case .deleteChar:
            return deleteChar(buffer: buffer, count: count)

        case .paste(let before):
            return paste(register: register, before: before, count: count, buffer: buffer)

        case .undo, .redo, .repeatLast:
            return OperatorResult(buffer: buffer, yankedText: nil)
        }
    }

    static func applyToLine(
        _ op: VimOperator,
        count: Int,
        buffer: TextBuffer
    ) -> OperatorResult {
        let text = buffer.text
        guard !text.isEmpty else { return OperatorResult(buffer: buffer) }

        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        var currentLine = 0
        var offset = 0
        let cursorOffset = buffer.cursorOffset

        for (i, line) in lines.enumerated() {
            if offset + line.count >= cursorOffset {
                currentLine = i
                break
            }
            offset += line.count + 1
            if i == lines.count - 1 { currentLine = i }
        }

        let startLine = currentLine
        let endLine = min(currentLine + max(count, 1) - 1, lines.count - 1)

        // Calculate the range to remove
        var rangeStart = 0
        for i in 0..<startLine {
            rangeStart += lines[i].count + 1
        }
        var rangeEnd = rangeStart
        for i in startLine...endLine {
            rangeEnd += lines[i].count
            if i < lines.count - 1 {
                rangeEnd += 1 // newline
            }
        }
        // Include trailing newline if present
        if rangeEnd < text.count {
            let idx = text.index(text.startIndex, offsetBy: rangeEnd)
            if idx < text.endIndex && text[idx] == "\n" {
                rangeEnd += 1
            }
        }
        // When deleting the last line and there's a preceding line, also remove
        // the newline that precedes this line so we don't leave a trailing \n.
        // Compute cursorBase before decrementing so newCursor lands on the
        // first character of the now-last line, not on the preceding \n.
        let cursorBase = rangeStart
        if endLine == lines.count - 1 && startLine > 0 && rangeStart > 0 {
            rangeStart -= 1
        }

        let startIdx = text.index(text.startIndex, offsetBy: min(rangeStart, text.count))
        let endIdx = text.index(text.startIndex, offsetBy: min(rangeEnd, text.count))
        let yanked = String(text[startIdx..<endIdx])

        switch op {
        case .delete:
            var newText = text
            newText.removeSubrange(startIdx..<endIdx)
            let newCursor = min(cursorBase, max(newText.count - 1, 0))
            let result = TextBuffer(newText, cursor: newCursor)
            return OperatorResult(buffer: result, yankedText: yanked)

        case .yank:
            return OperatorResult(buffer: buffer, yankedText: yanked)

        case .change:
            var newText = text
            newText.removeSubrange(startIdx..<endIdx)
            // Insert empty line
            if rangeStart > 0 && (rangeStart >= newText.count || newText.isEmpty) {
                // At end, add newline before
                if !newText.isEmpty && !newText.hasSuffix("\n") {
                    newText.append("\n")
                }
                let newCursor = newText.count
                let result = TextBuffer(newText, cursor: newCursor)
                return OperatorResult(buffer: result, yankedText: yanked)
            } else {
                newText.insert("\n", at: newText.index(newText.startIndex, offsetBy: min(rangeStart, newText.count)))
                let result = TextBuffer(newText, cursor: rangeStart)
                return OperatorResult(buffer: result, yankedText: yanked)
            }

        default:
            return OperatorResult(buffer: buffer)
        }
    }

    static func applyToVisualSelection(
        _ op: VimOperator,
        buffer: TextBuffer
    ) -> OperatorResult {
        guard let selection = buffer.selectionRange else {
            return OperatorResult(buffer: buffer)
        }

        let text = buffer.text
        let yanked = String(text[selection])

        switch op {
        case .delete:
            var newText = text
            newText.removeSubrange(selection)
            let cursorOffset = text.distance(from: text.startIndex, to: selection.lowerBound)
            let clampedCursor = min(cursorOffset, max(newText.count - 1, 0))
            let result = TextBuffer(newText, cursor: clampedCursor)
            return OperatorResult(buffer: result, yankedText: yanked)

        case .yank:
            return OperatorResult(buffer: buffer, yankedText: yanked)

        case .change:
            var newText = text
            newText.removeSubrange(selection)
            let cursorOffset = text.distance(from: text.startIndex, to: selection.lowerBound)
            let clampedCursor = min(cursorOffset, max(newText.count, 0))
            let result = TextBuffer(newText, cursor: clampedCursor)
            return OperatorResult(buffer: result, yankedText: yanked)

        default:
            return OperatorResult(buffer: buffer)
        }
    }

    // MARK: - Private helpers

    private static func deleteWithMotion(motion: Motion, count: Int, buffer: TextBuffer) -> OperatorResult {
        let dest = MotionResolver.apply(motion, count: count, to: buffer)
        let text = buffer.text
        let from = buffer.cursorIndex
        let to = dest.cursorIndex

        let start = min(from, to)
        let end = max(from, to)

        guard start < text.endIndex && start != end else {
            return OperatorResult(buffer: buffer)
        }

        // For inclusive motions (lineEnd, findForward, etc.), include the end character
        let deleteEnd: String.Index
        switch motion {
        case .lineEnd, .findForward, .findBackward, .tillForward, .tillBackward, .wordEnd, .wordEndBig:
            deleteEnd = end < text.endIndex ? text.index(after: end) : end
        default:
            deleteEnd = end
        }

        let clampedEnd = min(deleteEnd, text.endIndex)
        let yanked = String(text[start..<clampedEnd])

        var newText = text
        newText.removeSubrange(start..<clampedEnd)

        let cursorOffset = text.distance(from: text.startIndex, to: start)
        let clampedCursor = min(cursorOffset, max(newText.count - 1, 0))
        let result = TextBuffer(newText, cursor: clampedCursor)
        return OperatorResult(buffer: result, yankedText: yanked)
    }

    private static func changeWithMotion(motion: Motion, count: Int, buffer: TextBuffer) -> OperatorResult {
        let deleteResult = deleteWithMotion(motion: motion, count: count, buffer: buffer)
        // Change leaves cursor at deletion point (ready for insert)
        return deleteResult
    }

    private static func yankWithMotion(motion: Motion, count: Int, buffer: TextBuffer) -> OperatorResult {
        let dest = MotionResolver.apply(motion, count: count, to: buffer)
        let text = buffer.text
        let from = buffer.cursorIndex
        let to = dest.cursorIndex

        let start = min(from, to)
        let end = max(from, to)

        guard start < text.endIndex && start != end else {
            return OperatorResult(buffer: buffer)
        }

        let yankEnd: String.Index
        switch motion {
        case .lineEnd, .findForward, .findBackward, .tillForward, .tillBackward, .wordEnd, .wordEndBig:
            yankEnd = end < text.endIndex ? text.index(after: end) : end
        default:
            yankEnd = end
        }

        let clampedEnd = min(yankEnd, text.endIndex)
        let yanked = String(text[start..<clampedEnd])
        return OperatorResult(buffer: buffer, yankedText: yanked)
    }

    private static func deleteChar(buffer: TextBuffer, count: Int) -> OperatorResult {
        let text = buffer.text
        let cursor = buffer.cursorIndex

        guard cursor < text.endIndex else {
            return OperatorResult(buffer: buffer)
        }

        var end = cursor
        for _ in 0..<max(count, 1) {
            if end < text.endIndex && text[end] != "\n" {
                end = text.index(after: end)
            }
        }

        let yanked = String(text[cursor..<end])
        var newText = text
        newText.removeSubrange(cursor..<end)

        let cursorOffset = buffer.cursorOffset
        let clampedCursor = min(cursorOffset, max(newText.count - 1, 0))
        let result = TextBuffer(newText, cursor: clampedCursor)
        return OperatorResult(buffer: result, yankedText: yanked)
    }

    private static func paste(register: String?, before: Bool, count: Int, buffer: TextBuffer) -> OperatorResult {
        guard let content = register, !content.isEmpty else {
            return OperatorResult(buffer: buffer)
        }

        let repeated = String(repeating: content, count: max(count, 1))
        var text = buffer.text
        let cursor = buffer.cursorIndex

        let insertAt: String.Index
        if before {
            insertAt = cursor
        } else {
            insertAt = cursor < text.endIndex ? text.index(after: cursor) : text.endIndex
        }

        text.insert(contentsOf: repeated, at: insertAt)

        let newCursorOffset = text.distance(from: text.startIndex, to: insertAt) + repeated.count - 1
        let clampedCursor = max(0, min(newCursorOffset, text.count - 1))
        let result = TextBuffer(text, cursor: clampedCursor)
        return OperatorResult(buffer: result)
    }
}
