import XCTest
@testable import PetruVim

final class MotionResolverTests: XCTestCase {

    private func buf(_ text: String, cursor: Int) -> TextBuffer {
        TextBuffer(text, cursor: cursor)
    }

    private func apply(_ motion: Motion, to text: String, cursor: Int, count: Int = 1) -> Int {
        MotionResolver.apply(motion, count: count, to: buf(text, cursor: cursor)).cursorOffset
    }

    // MARK: - h / l

    func test_h_movesLeft() {
        XCTAssertEqual(apply(.left, to: "hello", cursor: 2), 1)
    }

    func test_h_stopsAtLineStart() {
        XCTAssertEqual(apply(.left, to: "hello", cursor: 0), 0)
    }

    func test_h_doesNotCrossNewline() {
        // cursor at start of second line — should not move to newline char
        XCTAssertEqual(apply(.left, to: "ab\ncd", cursor: 3), 3)
    }

    func test_l_movesRight() {
        XCTAssertEqual(apply(.right, to: "hello", cursor: 0), 1)
    }

    func test_l_stopsBeforeNewline() {
        // "ab\ncd" — cursor at 1 ('b'), l should not move to \n
        XCTAssertEqual(apply(.right, to: "ab\ncd", cursor: 1), 1)
    }

    func test_l_stopsAtLineEnd() {
        XCTAssertEqual(apply(.right, to: "hello", cursor: 4), 4)
    }

    // MARK: - j / k

    func test_j_movesDown() {
        // "ab\ncd" — cursor at 0 ('a'), j → offset 3 ('c')
        XCTAssertEqual(apply(.down, to: "ab\ncd", cursor: 0), 3)
    }

    func test_k_movesUp() {
        // "ab\ncd" — cursor at 3 ('c'), k → offset 0 ('a')
        XCTAssertEqual(apply(.up, to: "ab\ncd", cursor: 3), 0)
    }

    func test_j_preservesColumn() {
        // "abc\nde" — cursor at col 2 ('c'), next line "de" only has cols 0-1, clamp to 'e' = offset 5
        XCTAssertEqual(apply(.down, to: "abc\nde", cursor: 2), 5)
    }

    func test_j_clampsToLastLine() {
        XCTAssertEqual(apply(.down, to: "hello", cursor: 2), 2)
    }

    func test_k_clampsToFirstLine() {
        XCTAssertEqual(apply(.up, to: "hello", cursor: 2), 2)
    }

    // MARK: - w / b / e

    func test_w_jumpsToNextWord() {
        XCTAssertEqual(apply(.wordForward, to: "hello world", cursor: 0), 6)
    }

    func test_w_skipsWhitespace() {
        XCTAssertEqual(apply(.wordForward, to: "hello   world", cursor: 0), 8)
    }

    func test_b_jumpsToWordStart() {
        XCTAssertEqual(apply(.wordBackward, to: "hello world", cursor: 6), 0)
    }

    func test_e_jumpsToWordEnd() {
        XCTAssertEqual(apply(.wordEnd, to: "hello world", cursor: 0), 4)
    }

    // MARK: - 0 / $ / ^ / _

    func test_lineStart() {
        XCTAssertEqual(apply(.lineStart, to: "hello", cursor: 3), 0)
    }

    func test_lineEnd() {
        // "hello" — $ puts cursor on last char 'o' at offset 4
        XCTAssertEqual(apply(.lineEnd, to: "hello", cursor: 0), 4)
    }

    func test_lineEnd_multiLine() {
        // "ab\ncd" — cursor on first line, $ → offset 1 ('b')
        XCTAssertEqual(apply(.lineEnd, to: "ab\ncd", cursor: 0), 1)
    }

    func test_lineFirstNonBlank() {
        XCTAssertEqual(apply(.lineFirstNonBlank, to: "  hello", cursor: 6), 2)
    }

    func test_lineDown_count1_staysOnCurrentLine() {
        // _ count=1: first non-blank of current line
        XCTAssertEqual(apply(.lineDown, to: "  hello\n  world", cursor: 6), 2)
    }

    func test_lineDown_count2_advancesOneLine() {
        // 2_ : first non-blank of next line
        // "  hello\n  world" — 'w' is at offset 9
        XCTAssertEqual(apply(.lineDown, to: "  hello\n  world", cursor: 0, count: 2), 9)
    }

    func test_lineDown_count3_advances2Lines() {
        // 3_ : first non-blank 2 lines below
        // "a\n  b\n  c" — 'c' is at offset 7
        XCTAssertEqual(apply(.lineDown, to: "a\n  b\n  c", cursor: 0, count: 3), 7)
    }

    // MARK: - gg / G

    func test_fileStart() {
        XCTAssertEqual(apply(.fileStart, to: "abc\ndef", cursor: 5), 0)
    }

    func test_fileEnd() {
        // G goes to start of last line
        XCTAssertEqual(apply(.fileEnd, to: "abc\ndef", cursor: 0), 4)
    }

    // MARK: - f / F / t / T

    func test_findForward() {
        XCTAssertEqual(apply(.findForward("o"), to: "hello", cursor: 0), 4)
    }

    func test_findForward_noMatch() {
        XCTAssertEqual(apply(.findForward("z"), to: "hello", cursor: 0), 0)
    }

    func test_findBackward() {
        XCTAssertEqual(apply(.findBackward("h"), to: "hello", cursor: 4), 0)
    }

    func test_tillForward() {
        XCTAssertEqual(apply(.tillForward("o"), to: "hello", cursor: 0), 3)
    }

    func test_tillBackward() {
        XCTAssertEqual(apply(.tillBackward("h"), to: "hello", cursor: 4), 1)
    }

    // MARK: - Count prefix

    func test_count_l() {
        XCTAssertEqual(apply(.right, to: "hello", cursor: 0, count: 3), 3)
    }

    func test_count_w() {
        // a(0) b(2) c(4) d(6): 3×w from 0 → a→b→c→d = offset 6
        XCTAssertEqual(apply(.wordForward, to: "a b c d", cursor: 0, count: 3), 6)
    }

    func test_count_clampsAtEnd() {
        XCTAssertEqual(apply(.right, to: "hi", cursor: 0, count: 10), 1)
    }

    // MARK: - Empty text

    func test_emptyText_returnsUnchanged() {
        let result = MotionResolver.apply(.right, count: 1, to: buf("", cursor: 0))
        XCTAssertEqual(result.cursorOffset, 0)
    }
}
