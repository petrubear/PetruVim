import XCTest
@testable import PetruVim

// All test methods are async so XCTest runs them as proper @MainActor Tasks,
// which allows MainActor.assumeIsolated in VimEngine's key callback to work.
@MainActor
final class VimEngineTests: XCTestCase {

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

    private var text: String { textElement.buffer.text }
    private var cursor: Int { textElement.buffer.cursorOffset }

    // MARK: - Mode transitions

    func test_initialMode_isNormal() async {
        XCTAssertEqual(engine.mode, .normal)
    }

    func test_i_entersInsertMode() async {
        send("i")
        XCTAssertEqual(engine.mode, .insert)
    }

    func test_esc_inInsert_returnsToNormal() async {
        send("i")
        sendEsc()
        XCTAssertEqual(engine.mode, .normal)
    }

    func test_v_entersVisualMode() async {
        setBuffer("hello", cursor: 0)
        send("v")
        XCTAssertEqual(engine.mode, .visual)
    }

    func test_esc_inVisual_returnsToNormal() async {
        setBuffer("hello", cursor: 0)
        send("v")
        sendEsc()
        XCTAssertEqual(engine.mode, .normal)
    }

    func test_modeChange_notificationsPosted() async {
        setBuffer("hello", cursor: 0)
        send("i")
        XCTAssertEqual(notifications.postedModes.last, .insert)
        sendEsc()
        XCTAssertEqual(notifications.postedModes.last, .normal)
    }

    // MARK: - Insert passthrough

    func test_insertMode_passesKeysThrough() async {
        send("i")
        let result = keyboard.send("h")
        XCTAssertFalse(result)
    }

    // MARK: - Normal mode motions

    func test_h_movesLeft() async {
        setBuffer("hello", cursor: 2)
        send("h")
        XCTAssertEqual(cursor, 1)
    }

    func test_l_movesRight() async {
        setBuffer("hello", cursor: 0)
        send("l")
        XCTAssertEqual(cursor, 1)
    }

    func test_countPrefix_3l() async {
        setBuffer("hello", cursor: 0)
        send("3")
        send("l")
        XCTAssertEqual(cursor, 3)
    }

    // MARK: - Operators in normal mode

    func test_x_deletesCharUnderCursor() async {
        setBuffer("hello", cursor: 0)
        send("x")
        XCTAssertEqual(text, "ello")
    }

    func test_x_storesYankedText() async {
        setBuffer("hello", cursor: 0)
        send("x")
        XCTAssertEqual(clipboard.contents, "h")
    }

    func test_dd_deletesLine() async {
        setBuffer("hello\nworld", cursor: 0)
        send("d")
        send("d")
        XCTAssertEqual(text, "world")
    }

    func test_dw_deletesWord() async {
        setBuffer("hello world", cursor: 0)
        send("d")
        send("w")
        XCTAssertEqual(text, "world")
    }

    func test_yy_yanksLine() async {
        setBuffer("hello\nworld", cursor: 0)
        send("y")
        send("y")
        XCTAssertEqual(text, "hello\nworld")
        XCTAssertEqual(clipboard.contents, "hello\n")
    }

    // MARK: - Change operator enters insert

    func test_cc_changesLineAndEntersInsert() async {
        setBuffer("hello\nworld", cursor: 0)
        send("c")
        send("c")
        XCTAssertEqual(engine.mode, .insert)
    }

    func test_cw_entersInsertMode() async {
        setBuffer("hello world", cursor: 0)
        send("c")
        send("w")
        XCTAssertEqual(engine.mode, .insert)
    }

    // MARK: - Insert entry points

    func test_a_appendsAfterCursor() async {
        setBuffer("hello", cursor: 0)
        send("a")
        XCTAssertEqual(engine.mode, .insert)
        XCTAssertEqual(cursor, 1)
    }

    func test_A_appendsAtLineEnd() async {
        setBuffer("hello", cursor: 0)
        send("A")
        XCTAssertEqual(engine.mode, .insert)
        XCTAssertEqual(cursor, 5)
    }

    func test_o_opensLineBelow() async {
        setBuffer("hello", cursor: 0)
        send("o")
        XCTAssertEqual(engine.mode, .insert)
        XCTAssertTrue(text.contains("\n"))
    }

    func test_O_opensLineAbove() async {
        setBuffer("hello", cursor: 0)
        send("O")
        XCTAssertEqual(engine.mode, .insert)
        XCTAssertTrue(text.contains("\n"))
    }

    // MARK: - Undo / Redo

    func test_u_postsSyntheticCmdZ() async {
        send("u")
        XCTAssertEqual(keyboard.syntheticEvents.count, 1)
        let event = keyboard.syntheticEvents[0]
        XCTAssertEqual(event.keyCode, 6)
        XCTAssertTrue(event.modifiers.contains(.command))
    }

    // MARK: - Visual mode

    func test_visual_enterSetsInitialSelection() async {
        setBuffer("hello", cursor: 0)
        send("v")
        XCTAssertNotNil(textElement.lastWritten?.selectionRange)
    }

    func test_visual_motionExtendsSelection() async {
        setBuffer("hello", cursor: 0)
        send("v")
        send("l")  // move right — selection should cover "he" (2 chars)
        let sel = textElement.lastWritten?.selectionRange
        XCTAssertNotNil(sel)
        let selLen = textElement.buffer.text.distance(from: sel!.lowerBound, to: sel!.upperBound)
        XCTAssertGreaterThanOrEqual(selLen, 2)
    }

    func test_visual_d_deletesSelection() async {
        setBuffer("hello world", cursor: 0)
        send("v")
        send("e")  // select to end of word "hello"
        send("d")
        XCTAssertEqual(engine.mode, .normal)
        XCTAssertFalse(text.hasPrefix("hello"))
    }

    func test_visual_y_yanksSelection() async {
        setBuffer("hello world", cursor: 0)
        send("v")
        send("e")
        send("y")
        XCTAssertEqual(engine.mode, .normal)
        XCTAssertNotNil(clipboard.contents)
    }

    func test_visual_c_deletesAndEntersInsert() async {
        setBuffer("hello world", cursor: 0)
        send("v")
        send("e")
        send("c")
        XCTAssertEqual(engine.mode, .insert)
    }

    // MARK: - Cmd-modified passthrough

    func test_cmdModified_passesThrough() async {
        setBuffer("hello", cursor: 0)
        let event = KeyEvent(keyCode: 0, characters: "s", modifiers: .command)
        let consumed = keyboard.onKeyEvent?(event) ?? true
        XCTAssertFalse(consumed)
    }
}
