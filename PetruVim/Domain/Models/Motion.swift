enum Motion: Equatable {
    case left
    case right
    case up
    case down
    case wordForward          // w
    case wordBackward         // b
    case wordEnd              // e
    case wordForwardBig       // W
    case wordBackwardBig      // B
    case wordEndBig           // E
    case lineStart            // 0
    case lineEnd              // $
    case lineFirstNonBlank    // ^
    case lineDown             // _
    case fileStart            // gg
    case fileEnd              // G
    case findForward(Character)   // f{char}
    case findBackward(Character)  // F{char}
    case tillForward(Character)   // t{char}
    case tillBackward(Character)  // T{char}
}
