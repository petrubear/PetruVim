import XCTest
@testable import PetruVim

final class OperatorResolverTests: XCTestCase {

    private func buf(_ text: String, cursor: Int) -> TextBuffer {
        TextBuffer(text, cursor: cursor)
    }

    // MARK: - Delete with motion

    func test_delete_right_removesChar() {
        let result = OperatorResolver.apply(.delete, motion: .right, count: 1,
                                           buffer: buf("hello", cursor: 0),
                                           register: nil, lastChange: nil)
        XCTAssertEqual(result.buffer.text, "ello")
        XCTAssertEqual(result.buffer.cursorOffset, 0)
        XCTAssertEqual(result.yankedText, "h")
    }

    func test_delete_word_removesWord() {
        let result = OperatorResolver.apply(.delete, motion: .wordForward, count: 1,
                                           buffer: buf("hello world", cursor: 0),
                                           register: nil, lastChange: nil)
        XCTAssertEqual(result.buffer.text, "world")
        XCTAssertNotNil(result.yankedText)
    }

    func test_delete_toLineEnd() {
        let result = OperatorResolver.apply(.delete, motion: .lineEnd, count: 1,
                                           buffer: buf("hello", cursor: 0),
                                           register: nil, lastChange: nil)
        XCTAssertEqual(result.buffer.text, "")
        XCTAssertEqual(result.yankedText, "hello")
    }

    // MARK: - Yank with motion

    func test_yank_doesNotModifyText() {
        let b = buf("hello world", cursor: 0)
        let result = OperatorResolver.apply(.yank, motion: .wordForward, count: 1,
                                           buffer: b, register: nil, lastChange: nil)
        XCTAssertEqual(result.buffer.text, "hello world")
        XCTAssertEqual(result.buffer.cursorOffset, 0)
        XCTAssertNotNil(result.yankedText)
    }

    // MARK: - Delete line

    func test_deleteLine_singleLine() {
        let result = OperatorResolver.applyToLine(.delete, count: 1, buffer: buf("hello\nworld", cursor: 0))
        XCTAssertEqual(result.buffer.text, "world")
        XCTAssertEqual(result.yankedText, "hello\n")
    }

    func test_deleteLine_lastLine() {
        let result = OperatorResolver.applyToLine(.delete, count: 1, buffer: buf("hello\nworld", cursor: 6))
        XCTAssertEqual(result.buffer.text, "hello")
        XCTAssertNotNil(result.yankedText)
    }

    func test_deleteLine_count2() {
        let result = OperatorResolver.applyToLine(.delete, count: 2,
                                                  buffer: buf("line1\nline2\nline3", cursor: 0))
        XCTAssertEqual(result.buffer.text, "line3")
    }

    // MARK: - Yank line

    func test_yankLine_doesNotModifyText() {
        let b = buf("hello\nworld", cursor: 0)
        let result = OperatorResolver.applyToLine(.yank, count: 1, buffer: b)
        XCTAssertEqual(result.buffer.text, b.text)
        XCTAssertEqual(result.yankedText, "hello\n")
    }

    // MARK: - Delete visual selection

    func test_deleteVisual_removesSelection() {
        let b = TextBuffer("hello world", cursor: 0, selection: 0..<5)
        let result = OperatorResolver.applyToVisualSelection(.delete, buffer: b)
        XCTAssertEqual(result.buffer.text, " world")
        XCTAssertEqual(result.yankedText, "hello")
        XCTAssertEqual(result.buffer.cursorOffset, 0)
    }

    func test_yankVisual_doesNotModifyText() {
        let b = TextBuffer("hello world", cursor: 6, selection: 6..<11)
        let result = OperatorResolver.applyToVisualSelection(.yank, buffer: b)
        XCTAssertEqual(result.buffer.text, "hello world")
        XCTAssertEqual(result.yankedText, "world")
    }

    func test_changeVisual_removesSelection() {
        let b = TextBuffer("hello world", cursor: 0, selection: 0..<5)
        let result = OperatorResolver.applyToVisualSelection(.change, buffer: b)
        XCTAssertEqual(result.buffer.text, " world")
        XCTAssertEqual(result.yankedText, "hello")
    }

    // MARK: - deleteChar (x)

    func test_deleteChar_removesCurrentChar() {
        let result = OperatorResolver.apply(.deleteChar, motion: .right, count: 1,
                                           buffer: buf("hello", cursor: 0),
                                           register: nil, lastChange: nil)
        XCTAssertEqual(result.buffer.text, "ello")
        XCTAssertEqual(result.yankedText, "h")
    }

    func test_deleteChar_doesNotCrossNewline() {
        // cursor at end of first line — x should not delete the newline
        let result = OperatorResolver.apply(.deleteChar, motion: .right, count: 1,
                                           buffer: buf("ab\ncd", cursor: 1),
                                           register: nil, lastChange: nil)
        XCTAssertEqual(result.buffer.text, "a\ncd")
    }
}
