import Foundation

enum MotionResolver {

    static func apply(_ motion: Motion, count: Int, to buffer: TextBuffer, visualAnchor: Int? = nil) -> TextBuffer {
        var result = buffer
        let text = buffer.text

        guard !text.isEmpty else { return result }

        for _ in 0..<max(count, 1) {
            result = applySingle(motion, to: result)
        }

        if let anchorOffset = visualAnchor {
            let t = result.text
            let anchor = t.index(t.startIndex, offsetBy: min(anchorOffset, t.count))
            let lower = min(anchor, result.cursorIndex)
            let upper = max(anchor, result.cursorIndex)
            let selStart = t.distance(from: t.startIndex, to: lower)
            let upperAfter = upper < t.endIndex ? t.index(after: upper) : t.endIndex
            let selEnd = t.distance(from: t.startIndex, to: upperAfter)
            result = TextBuffer(result.text, cursor: result.cursorOffset, selection: selStart..<selEnd)
        } else {
            result = TextBuffer(result.text, cursor: result.cursorOffset)
        }

        return result
    }

    // MARK: - Single application

    private static func applySingle(_ motion: Motion, to buffer: TextBuffer) -> TextBuffer {
        let text = buffer.text
        let cursor = buffer.cursorIndex

        guard !text.isEmpty else { return buffer }

        let newIndex: String.Index

        switch motion {
        case .left:
            let lineStart = buffer.lineStartIndex
            if cursor > lineStart {
                newIndex = text.index(before: cursor)
            } else {
                newIndex = cursor
            }

        case .right:
            let lineEnd = buffer.lineEndIndex
            let nextIdx = cursor < text.endIndex ? text.index(after: cursor) : cursor
            if nextIdx <= lineEnd && cursor < lineEnd {
                // Don't move onto a newline
                let ch = text[cursor]
                if ch == "\n" {
                    newIndex = cursor
                } else if nextIdx < text.endIndex && text[nextIdx] == "\n" {
                    // Stop before newline
                    newIndex = cursor
                } else if nextIdx < text.endIndex {
                    newIndex = nextIdx
                } else {
                    newIndex = cursor
                }
            } else {
                newIndex = cursor
            }

        case .up:
            newIndex = moveVertical(by: -1, cursor: cursor, in: text)

        case .down:
            newIndex = moveVertical(by: 1, cursor: cursor, in: text)

        case .wordForward:
            newIndex = findWordForward(cursor: cursor, in: text, bigWord: false)

        case .wordBackward:
            newIndex = findWordBackward(cursor: cursor, in: text, bigWord: false)

        case .wordEnd:
            newIndex = findWordEnd(cursor: cursor, in: text, bigWord: false)

        case .wordForwardBig:
            newIndex = findWordForward(cursor: cursor, in: text, bigWord: true)

        case .wordBackwardBig:
            newIndex = findWordBackward(cursor: cursor, in: text, bigWord: true)

        case .wordEndBig:
            newIndex = findWordEnd(cursor: cursor, in: text, bigWord: true)

        case .lineStart:
            newIndex = buffer.lineStartIndex

        case .lineEnd:
            let end = buffer.lineEndIndex
            if end > buffer.lineStartIndex {
                // Place cursor on last char before newline/end
                let candidate = text.index(before: end)
                if candidate >= buffer.lineStartIndex && text[candidate] == "\n" && candidate > buffer.lineStartIndex {
                    newIndex = text.index(before: candidate)
                } else if text[candidate] == "\n" {
                    newIndex = buffer.lineStartIndex
                } else {
                    newIndex = candidate
                }
            } else {
                newIndex = buffer.lineStartIndex
            }

        case .lineFirstNonBlank:
            newIndex = firstNonBlank(lineStart: buffer.lineStartIndex, lineEnd: buffer.lineEndIndex, in: text)

        case .lineDown:
            newIndex = firstNonBlank(lineStart: buffer.lineStartIndex, lineEnd: buffer.lineEndIndex, in: text)

        case .fileStart:
            newIndex = text.startIndex

        case .fileEnd:
            newIndex = startOfLastLine(in: text)

        case .findForward(let ch):
            newIndex = findCharForward(ch, cursor: cursor, in: text, lineEnd: buffer.lineEndIndex) ?? cursor

        case .findBackward(let ch):
            newIndex = findCharBackward(ch, cursor: cursor, in: text, lineStart: buffer.lineStartIndex) ?? cursor

        case .tillForward(let ch):
            if let found = findCharForward(ch, cursor: cursor, in: text, lineEnd: buffer.lineEndIndex), found > cursor {
                newIndex = text.index(before: found)
            } else {
                newIndex = cursor
            }

        case .tillBackward(let ch):
            if let found = findCharBackward(ch, cursor: cursor, in: text, lineStart: buffer.lineStartIndex), found < cursor {
                newIndex = text.index(after: found)
            } else {
                newIndex = cursor
            }
        }

        let clampedIndex = min(newIndex, text.endIndex)
        let offset = text.distance(from: text.startIndex, to: clampedIndex)
        return TextBuffer(text, cursor: offset)
    }

    // MARK: - Vertical movement

    private static func moveVertical(by lines: Int, cursor: String.Index, in text: String) -> String.Index {
        let allLines = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard !allLines.isEmpty else { return text.startIndex }

        // Find current line number and column
        var currentLine = 0
        var lineStartOffset = 0
        let cursorOffset = text.distance(from: text.startIndex, to: cursor)

        for (i, line) in allLines.enumerated() {
            let lineLength = line.count
            let lineEndOffset = lineStartOffset + lineLength
            if cursorOffset <= lineEndOffset {
                currentLine = i
                break
            }
            lineStartOffset += lineLength + 1 // +1 for newline
            if i == allLines.count - 1 {
                currentLine = i
            }
        }

        let column = cursorOffset - lineStartOffset

        let targetLine = max(0, min(allLines.count - 1, currentLine + lines))

        // Calculate offset of target line start
        var targetLineStart = 0
        for i in 0..<targetLine {
            targetLineStart += allLines[i].count + 1
        }

        let targetLineLength = allLines[targetLine].count
        let targetColumn = min(column, max(targetLineLength - 1, 0))
        let targetOffset = targetLineStart + targetColumn

        let clampedOffset = max(0, min(targetOffset, text.count > 0 ? text.count - 1 : 0))
        return text.index(text.startIndex, offsetBy: clampedOffset)
    }

    // MARK: - Word motions

    private static func isWordChar(_ c: Character) -> Bool {
        c.isLetter || c.isNumber || c == "_"
    }

    private static func findWordForward(cursor: String.Index, in text: String, bigWord: Bool) -> String.Index {
        guard cursor < text.endIndex else { return cursor }

        var idx = cursor

        if bigWord {
            // Skip current non-whitespace
            while idx < text.endIndex && !text[idx].isWhitespace {
                idx = text.index(after: idx)
            }
            // Skip whitespace
            while idx < text.endIndex && text[idx].isWhitespace {
                idx = text.index(after: idx)
            }
        } else {
            let startChar = text[idx]
            if isWordChar(startChar) {
                // Skip word chars
                while idx < text.endIndex && isWordChar(text[idx]) {
                    idx = text.index(after: idx)
                }
            } else if !startChar.isWhitespace {
                // Skip punctuation
                while idx < text.endIndex && !isWordChar(text[idx]) && !text[idx].isWhitespace {
                    idx = text.index(after: idx)
                }
            }
            // Skip whitespace
            while idx < text.endIndex && text[idx].isWhitespace {
                idx = text.index(after: idx)
            }
        }

        if idx >= text.endIndex && !text.isEmpty {
            return text.index(before: text.endIndex)
        }
        return idx
    }

    private static func findWordBackward(cursor: String.Index, in text: String, bigWord: Bool) -> String.Index {
        guard cursor > text.startIndex else { return cursor }

        var idx = text.index(before: cursor)

        // Skip whitespace backward
        while idx > text.startIndex && text[idx].isWhitespace {
            idx = text.index(before: idx)
        }

        if bigWord {
            // Skip non-whitespace backward
            while idx > text.startIndex && !text[text.index(before: idx)].isWhitespace {
                idx = text.index(before: idx)
            }
        } else {
            let ch = text[idx]
            if isWordChar(ch) {
                while idx > text.startIndex && isWordChar(text[text.index(before: idx)]) {
                    idx = text.index(before: idx)
                }
            } else if !ch.isWhitespace {
                while idx > text.startIndex {
                    let prev = text[text.index(before: idx)]
                    if !isWordChar(prev) && !prev.isWhitespace {
                        idx = text.index(before: idx)
                    } else {
                        break
                    }
                }
            }
        }

        return idx
    }

    private static func findWordEnd(cursor: String.Index, in text: String, bigWord: Bool) -> String.Index {
        guard cursor < text.endIndex else { return cursor }

        var idx = cursor
        // Move at least one character forward
        if idx < text.endIndex {
            idx = text.index(after: idx)
        }
        guard idx < text.endIndex else {
            return text.isEmpty ? text.startIndex : text.index(before: text.endIndex)
        }

        // Skip whitespace
        while idx < text.endIndex && text[idx].isWhitespace {
            idx = text.index(after: idx)
        }

        guard idx < text.endIndex else {
            return text.index(before: text.endIndex)
        }

        if bigWord {
            while idx < text.endIndex {
                let next = text.index(after: idx)
                if next >= text.endIndex || text[next].isWhitespace {
                    break
                }
                idx = next
            }
        } else {
            let ch = text[idx]
            if isWordChar(ch) {
                while idx < text.endIndex {
                    let next = text.index(after: idx)
                    if next >= text.endIndex || !isWordChar(text[next]) {
                        break
                    }
                    idx = next
                }
            } else if !ch.isWhitespace {
                while idx < text.endIndex {
                    let next = text.index(after: idx)
                    if next >= text.endIndex || isWordChar(text[next]) || text[next].isWhitespace {
                        break
                    }
                    idx = next
                }
            }
        }

        return idx
    }

    // MARK: - Line helpers

    private static func firstNonBlank(lineStart: String.Index, lineEnd: String.Index, in text: String) -> String.Index {
        var idx = lineStart
        while idx < lineEnd {
            let ch = text[idx]
            if ch != " " && ch != "\t" {
                return idx
            }
            idx = text.index(after: idx)
        }
        return lineStart
    }

    private static func startOfLastLine(in text: String) -> String.Index {
        guard !text.isEmpty else { return text.startIndex }
        var idx = text.index(before: text.endIndex)
        // Skip trailing newline
        if text[idx] == "\n" && idx > text.startIndex {
            idx = text.index(before: idx)
        }
        while idx > text.startIndex {
            if text[text.index(before: idx)] == "\n" {
                return idx
            }
            idx = text.index(before: idx)
        }
        return text.startIndex
    }

    // MARK: - Find char on line

    private static func findCharForward(_ ch: Character, cursor: String.Index, in text: String, lineEnd: String.Index) -> String.Index? {
        guard cursor < text.endIndex else { return nil }
        var idx = text.index(after: cursor)
        while idx < lineEnd && idx < text.endIndex {
            if text[idx] == ch {
                return idx
            }
            idx = text.index(after: idx)
        }
        return nil
    }

    private static func findCharBackward(_ ch: Character, cursor: String.Index, in text: String, lineStart: String.Index) -> String.Index? {
        guard cursor > lineStart else { return nil }
        var idx = text.index(before: cursor)
        while idx >= lineStart {
            if text[idx] == ch {
                return idx
            }
            if idx == lineStart { break }
            idx = text.index(before: idx)
        }
        return nil
    }
}
