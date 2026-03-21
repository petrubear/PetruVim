struct TextBuffer: Equatable {
    var text: String
    var cursorIndex: String.Index
    var selectionRange: Range<String.Index>?

    init(text: String, cursorIndex: String.Index, selectionRange: Range<String.Index>? = nil) {
        self.text = text
        self.cursorIndex = cursorIndex
        self.selectionRange = selectionRange
    }

    /// Convenience initialiser using integer offsets (useful in tests)
    init(_ text: String, cursor: Int, selection: Range<Int>? = nil) {
        self.text = text
        let clampedCursor = min(max(cursor, 0), text.count)
        self.cursorIndex = text.index(text.startIndex, offsetBy: clampedCursor)
        if let sel = selection {
            let lo = text.index(text.startIndex, offsetBy: min(sel.lowerBound, text.count))
            let hi = text.index(text.startIndex, offsetBy: min(sel.upperBound, text.count))
            self.selectionRange = lo..<hi
        } else {
            self.selectionRange = nil
        }
    }

    var cursorOffset: Int {
        text.distance(from: text.startIndex, to: cursorIndex)
    }

    var currentChar: Character? {
        guard cursorIndex < text.endIndex else { return nil }
        return text[cursorIndex]
    }

    var currentLine: Substring {
        let lineStart = text[..<cursorIndex].lastIndex(of: "\n").map {
            text.index(after: $0)
        } ?? text.startIndex
        let lineEnd = text[cursorIndex...].firstIndex(of: "\n") ?? text.endIndex
        return text[lineStart..<lineEnd]
    }

    var lineStartIndex: String.Index {
        text[..<cursorIndex].lastIndex(of: "\n").map { text.index(after: $0) } ?? text.startIndex
    }

    var lineEndIndex: String.Index {
        text[cursorIndex...].firstIndex(of: "\n") ?? text.endIndex
    }
}
