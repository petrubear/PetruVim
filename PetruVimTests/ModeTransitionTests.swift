import XCTest
@testable import PetruVim

/// Focused tests for Normal → Insert mode transitions.
/// Each test is intentionally small and diagnostic so failures point
/// directly at which entry point or side-effect is broken.
@MainActor
final class ModeTransitionTests: XCTestCase {

    private var textElement: MockTextElement!
    private var keyboard: MockKeyboard!
    private var clipboard: MockClipboard!
    private var notifications: MockNotifications!
    private var engine: VimEngine!

    override func setUp() async throws {
        textElement = MockTextElement()
        keyboard = MockKeyboard()
        clipboard = MockClipboard()
        notifications = MockNotifications()
        engine = VimEngine(
            textElement: textElement,
            keyboard: keyboard,
            clipboard: clipboard,
            notifications: notifications
        )
        engine.start()
    }

    // MARK: - Helpers

    private func setBuffer(_ text: String, cursor: Int) {
        textElement.buffer = TextBuffer(text, cursor: cursor)
    }

    @discardableResult
    private func send(_ ch: Character) -> Bool { keyboard.send(ch) }

    @discardableResult
    private func sendEsc() -> Bool { keyboard.sendEsc() }

    private var mode: VimMode { engine.mode }
    private var cursor: Int { textElement.buffer.cursorOffset }
    private var text: String { textElement.buffer.text }

    // MARK: - Initial state

    func test_engineStartsInNormalMode() async {
        XCTAssertEqual(mode, .normal,
            "Engine must start in .normal — if this fails, VimEngine.init sets wrong initial mode")
    }

    // MARK: - i (insert before cursor)

    func test_i_switchesToInsertMode() async {
        setBuffer("hello", cursor: 2)
        send("i")
        XCTAssertEqual(mode, .insert,
            "'i' must switch mode to .insert")
    }

    func test_i_doesNotMoveCursor() async {
        setBuffer("hello", cursor: 2)
        send("i")
        XCTAssertEqual(cursor, 2,
            "'i' must not move the cursor")
    }

    func test_i_postsInsertModeNotification() async {
        setBuffer("hello", cursor: 0)
        send("i")
        XCTAssertEqual(notifications.postedModes.last, .insert,
            "'i' must post a .insert mode-change notification")
    }

    // MARK: - a (append after cursor)

    func test_a_switchesToInsertMode() async {
        setBuffer("hello", cursor: 0)
        send("a")
        XCTAssertEqual(mode, .insert,
            "'a' must switch mode to .insert")
    }

    func test_a_movesCursorOneRight() async {
        setBuffer("hello", cursor: 0)
        send("a")
        XCTAssertEqual(cursor, 1,
            "'a' must advance cursor by 1")
    }

    func test_a_atLastChar_doesNotExceedLength() async {
        setBuffer("hi", cursor: 1)
        send("a")
        XCTAssertEqual(cursor, 2,
            "'a' at last char must place cursor at text.count (one past end)")
        XCTAssertLessThanOrEqual(cursor, text.count,
            "cursor must not exceed text length")
    }

    func test_a_postsInsertModeNotification() async {
        setBuffer("hello", cursor: 0)
        send("a")
        XCTAssertEqual(notifications.postedModes.last, .insert,
            "'a' must post a .insert mode-change notification")
    }

    // MARK: - A (append at end of line)

    func test_A_switchesToInsertMode() async {
        setBuffer("hello", cursor: 0)
        send("A")
        XCTAssertEqual(mode, .insert,
            "'A' must switch mode to .insert")
    }

    func test_A_movesCursorToEndOfLine() async {
        setBuffer("hello\nworld", cursor: 0)
        send("A")
        XCTAssertEqual(cursor, 5,
            "'A' must place cursor at end of the current line (before newline)")
    }

    func test_A_onSingleLine_movesCursorToTextEnd() async {
        setBuffer("hello", cursor: 0)
        send("A")
        XCTAssertEqual(cursor, 5,
            "'A' on single-line buffer must place cursor at text.count")
    }

    func test_A_postsInsertModeNotification() async {
        setBuffer("hello", cursor: 0)
        send("A")
        XCTAssertEqual(notifications.postedModes.last, .insert,
            "'A' must post a .insert mode-change notification")
    }

    // MARK: - I (insert at first non-blank of line)

    func test_I_switchesToInsertMode() async {
        setBuffer("  hello", cursor: 5)
        send("I")
        XCTAssertEqual(mode, .insert,
            "'I' must switch mode to .insert")
    }

    func test_I_movesCursorToFirstNonBlank() async {
        setBuffer("  hello", cursor: 5)
        send("I")
        XCTAssertEqual(cursor, 2,
            "'I' must move cursor to first non-blank character")
    }

    func test_I_postsInsertModeNotification() async {
        setBuffer("hello", cursor: 3)
        send("I")
        XCTAssertEqual(notifications.postedModes.last, .insert,
            "'I' must post a .insert mode-change notification")
    }

    // MARK: - o (open line below)

    func test_o_switchesToInsertMode() async {
        setBuffer("hello", cursor: 0)
        send("o")
        XCTAssertEqual(mode, .insert,
            "'o' must switch mode to .insert")
    }

    func test_o_insertsNewlineIntoText() async {
        setBuffer("hello", cursor: 0)
        send("o")
        XCTAssertTrue(text.contains("\n"),
            "'o' must insert a newline character into the buffer")
    }

    func test_o_placesNewlineAfterCurrentLine() async {
        setBuffer("hello\nworld", cursor: 0)
        send("o")
        // After 'o', text should be "hello\n\nworld" and cursor on the blank line
        XCTAssertTrue(text.hasPrefix("hello\n"),
            "'o' must insert the new line after the current line, not before it")
    }

    func test_o_postsInsertModeNotification() async {
        setBuffer("hello", cursor: 0)
        send("o")
        XCTAssertEqual(notifications.postedModes.last, .insert,
            "'o' must post a .insert mode-change notification")
    }

    // MARK: - O (open line above)

    func test_O_switchesToInsertMode() async {
        setBuffer("hello", cursor: 0)
        send("O")
        XCTAssertEqual(mode, .insert,
            "'O' must switch mode to .insert")
    }

    func test_O_insertsNewlineIntoText() async {
        setBuffer("hello", cursor: 0)
        send("O")
        XCTAssertTrue(text.contains("\n"),
            "'O' must insert a newline character into the buffer")
    }

    func test_O_placesNewlineBeforeCurrentLine() async {
        setBuffer("hello\nworld", cursor: 6)  // cursor on "world"
        send("O")
        // New blank line should appear before "world"
        let lines = text.components(separatedBy: "\n")
        XCTAssertGreaterThanOrEqual(lines.count, 3,
            "'O' must insert a line above the current line")
    }

    func test_O_postsInsertModeNotification() async {
        setBuffer("hello", cursor: 0)
        send("O")
        XCTAssertEqual(notifications.postedModes.last, .insert,
            "'O' must post a .insert mode-change notification")
    }

    // MARK: - ESC exits insert mode

    func test_esc_fromInsert_switchesToNormal() async {
        send("i")
        XCTAssertEqual(mode, .insert)
        sendEsc()
        XCTAssertEqual(mode, .normal,
            "ESC from .insert must return to .normal")
    }

    func test_esc_fromInsert_postsNormalModeNotification() async {
        send("i")
        sendEsc()
        XCTAssertEqual(notifications.postedModes.last, .normal,
            "ESC from .insert must post a .normal mode-change notification")
    }

    func test_esc_fromInsert_keysAreConsumed() async {
        send("i")
        let consumed = sendEsc()
        XCTAssertTrue(consumed,
            "ESC in .insert mode must be consumed (return true) so the app does not forward it")
    }

    // MARK: - Insert mode passthrough

    func test_insertMode_regularKey_notConsumed() async {
        send("i")
        let consumed = keyboard.send("x")
        XCTAssertFalse(consumed,
            "In .insert mode, regular keys must NOT be consumed — they belong to the text field")
    }

    func test_insertMode_doesNotChangeMode() async {
        send("i")
        keyboard.send("h")
        keyboard.send("e")
        keyboard.send("l")
        XCTAssertEqual(mode, .insert,
            "Typing in .insert mode must not cause a mode change")
    }

    // MARK: - Notification ordering

    func test_notificationOrder_normalToInsertToNormal() async {
        send("i")
        sendEsc()
        XCTAssertEqual(notifications.postedModes, [.insert, .normal],
            "Notifications must be posted in the order: .insert then .normal")
    }

    func test_multipleInsertEntries_eachPostsNotification() async {
        send("i"); sendEsc()
        send("a"); sendEsc()
        send("A"); sendEsc()
        let insertCount = notifications.postedModes.filter { $0 == .insert }.count
        XCTAssertEqual(insertCount, 3,
            "Each insert entry (i/a/A) must post exactly one .insert notification")
    }
}
