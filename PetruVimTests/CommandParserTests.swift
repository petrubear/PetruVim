import XCTest
@testable import PetruVim

final class CommandParserTests: XCTestCase {

    private var parser: CommandParser!

    override func setUp() {
        super.setUp()
        parser = CommandParser()
    }

    private func feed(_ ch: Character, mode: VimMode = .normal) -> VimCommand? {
        parser.feed(.char(ch), mode: mode)
    }

    private func feedEsc(mode: VimMode = .normal) -> VimCommand? {
        parser.feed(.esc, mode: mode)
    }

    // MARK: - Motions

    func test_h_returnsMotionLeft() {
        XCTAssertEqual(feed("h"), .motion(count: 1, .left))
    }

    func test_l_returnsMotionRight() {
        XCTAssertEqual(feed("l"), .motion(count: 1, .right))
    }

    func test_j_returnsMotionDown() {
        XCTAssertEqual(feed("j"), .motion(count: 1, .down))
    }

    func test_k_returnsMotionUp() {
        XCTAssertEqual(feed("k"), .motion(count: 1, .up))
    }

    func test_w_returnsWordForward() {
        XCTAssertEqual(feed("w"), .motion(count: 1, .wordForward))
    }

    func test_b_returnsWordBackward() {
        XCTAssertEqual(feed("b"), .motion(count: 1, .wordBackward))
    }

    func test_e_returnsWordEnd() {
        XCTAssertEqual(feed("e"), .motion(count: 1, .wordEnd))
    }

    func test_G_returnsFileEnd() {
        XCTAssertEqual(feed("G"), .motion(count: 1, .fileEnd))
    }

    func test_dollarSign_returnsLineEnd() {
        XCTAssertEqual(feed("$"), .motion(count: 1, .lineEnd))
    }

    func test_zero_returnsLineStart() {
        XCTAssertEqual(feed("0"), .motion(count: 1, .lineStart))
    }

    func test_caret_returnsLineFirstNonBlank() {
        XCTAssertEqual(feed("^"), .motion(count: 1, .lineFirstNonBlank))
    }

    func test_gg_returnsFileStart() {
        XCTAssertNil(feed("g"))
        XCTAssertEqual(feed("g"), .motion(count: 1, .fileStart))
    }

    // MARK: - Count prefix

    func test_count_3l() {
        XCTAssertNil(feed("3"))
        XCTAssertEqual(feed("l"), .motion(count: 3, .right))
    }

    func test_count_12h() {
        XCTAssertNil(feed("1"))
        XCTAssertNil(feed("2"))
        XCTAssertEqual(feed("h"), .motion(count: 12, .left))
    }

    // MARK: - Operators

    func test_dw_returnsDeleteWordForward() {
        XCTAssertNil(feed("d"))
        XCTAssertEqual(feed("w"), .operatorMotion(count: 1, .delete, .wordForward))
    }

    func test_cw_returnsChangeWordForward() {
        XCTAssertNil(feed("c"))
        XCTAssertEqual(feed("w"), .operatorMotion(count: 1, .change, .wordForward))
    }

    func test_yw_returnsYankWordForward() {
        XCTAssertNil(feed("y"))
        XCTAssertEqual(feed("w"), .operatorMotion(count: 1, .yank, .wordForward))
    }

    func test_dd_returnsDeleteLine() {
        XCTAssertNil(feed("d"))
        XCTAssertEqual(feed("d"), .operatorLine(count: 1, .delete))
    }

    func test_cc_returnsChangeLine() {
        XCTAssertNil(feed("c"))
        XCTAssertEqual(feed("c"), .operatorLine(count: 1, .change))
    }

    func test_yy_returnsYankLine() {
        XCTAssertNil(feed("y"))
        XCTAssertEqual(feed("y"), .operatorLine(count: 1, .yank))
    }

    func test_count_2dd() {
        XCTAssertNil(feed("2"))
        XCTAssertNil(feed("d"))
        XCTAssertEqual(feed("d"), .operatorLine(count: 2, .delete))
    }

    func test_3dw_returnsDeleteWithCount() {
        XCTAssertNil(feed("3"))
        XCTAssertNil(feed("d"))
        XCTAssertEqual(feed("w"), .operatorMotion(count: 3, .delete, .wordForward))
    }

    // MARK: - f / F / t / T

    func test_f_awaitsChar() {
        XCTAssertNil(feed("f"))
        XCTAssertEqual(feed("x"), .motion(count: 1, .findForward("x")))
    }

    func test_F_awaitsChar() {
        XCTAssertNil(feed("F"))
        XCTAssertEqual(feed("a"), .motion(count: 1, .findBackward("a")))
    }

    func test_t_awaitsChar() {
        XCTAssertNil(feed("t"))
        XCTAssertEqual(feed("e"), .motion(count: 1, .tillForward("e")))
    }

    func test_df_awaitsChar() {
        XCTAssertNil(feed("d"))
        XCTAssertNil(feed("f"))
        XCTAssertEqual(feed("x"), .operatorMotion(count: 1, .delete, .findForward("x")))
    }

    // MARK: - Insert entry points

    func test_i_returnsEnterInsert() {
        XCTAssertEqual(feed("i"), .enterInsert(.i))
    }

    func test_a_returnsAppend() {
        XCTAssertEqual(feed("a"), .enterInsert(.a))
    }

    func test_o_returnsOpenBelow() {
        XCTAssertEqual(feed("o"), .enterInsert(.o))
    }

    func test_O_returnsOpenAbove() {
        XCTAssertEqual(feed("O"), .enterInsert(.O))
    }

    // MARK: - Standalone

    func test_x_returnsDeleteChar() {
        XCTAssertEqual(feed("x"), .standalone(count: 1, .deleteChar))
    }

    func test_count_3x_returnsDeleteThreeChars() {
        XCTAssertNil(feed("3"))
        XCTAssertEqual(feed("x"), .standalone(count: 3, .deleteChar))
    }

    func test_p_returnsPasteAfter() {
        XCTAssertEqual(feed("p"), .standalone(count: 1, .paste(before: false)))
    }

    func test_P_returnsPasteBefore() {
        XCTAssertEqual(feed("P"), .standalone(count: 1, .paste(before: true)))
    }

    func test_u_returnsUndo() {
        XCTAssertEqual(feed("u"), .standalone(count: 1, .undo))
    }

    func test_v_returnsEnterVisual() {
        XCTAssertEqual(feed("v"), .enterVisual)
    }

    func test_dot_returnsRepeatLast() {
        XCTAssertEqual(feed("."), .standalone(count: 1, .repeatLast))
    }

    // MARK: - ESC

    func test_esc_returnsExitToNormal() {
        XCTAssertEqual(feedEsc(), .exitToNormal)
    }

    func test_esc_resetsCount() {
        XCTAssertNil(feed("3"))
        XCTAssertEqual(feedEsc(), .exitToNormal)
        // After reset, next command has count 1
        XCTAssertEqual(feed("h"), .motion(count: 1, .left))
    }

    func test_esc_resetsPendingOperator() {
        XCTAssertNil(feed("d"))
        XCTAssertEqual(feedEsc(), .exitToNormal)
        // After reset, d starts fresh
        XCTAssertNil(feed("d"))
        XCTAssertEqual(feed("d"), .operatorLine(count: 1, .delete))
    }

    // MARK: - Visual mode

    func test_visual_h_returnsMotion() {
        XCTAssertEqual(feed("h", mode: .visual), .motion(count: 1, .left))
    }

    func test_visual_d_returnsOperatorVisual() {
        XCTAssertEqual(feed("d", mode: .visual), .operatorVisual(.delete))
    }

    func test_visual_c_returnsOperatorVisual() {
        XCTAssertEqual(feed("c", mode: .visual), .operatorVisual(.change))
    }

    func test_visual_y_returnsOperatorVisual() {
        XCTAssertEqual(feed("y", mode: .visual), .operatorVisual(.yank))
    }

    func test_visual_G_returnsFileEnd() {
        XCTAssertEqual(feed("G", mode: .visual), .motion(count: 1, .fileEnd))
    }

    func test_visual_f_awaitsChar() {
        XCTAssertNil(feed("f", mode: .visual))
        XCTAssertEqual(feed("x", mode: .visual), .motion(count: 1, .findForward("x")))
    }
}
