enum VimOperator: Equatable {
    case delete          // d
    case change          // c
    case yank            // y
    case deleteChar      // x
    case paste(before: Bool)  // p (before=false) / P (before=true)
    case undo            // u
    case redo            // Ctrl-R
    case repeatLast      // .
}
