enum InsertEntryPoint: Equatable {
    case i  // insert before cursor
    case a  // append after cursor
    case I  // insert at line start
    case A  // append at line end
    case o  // open line below
    case O  // open line above
}

enum VimCommand: Equatable {
    case motion(count: Int, Motion)
    case operatorMotion(count: Int, VimOperator, Motion)
    case operatorLine(count: Int, VimOperator)     // dd / yy / cc
    case operatorVisual(VimOperator)                // d/c/y on visual selection
    case enterInsert(InsertEntryPoint)
    case enterVisual
    case exitToNormal
    case standalone(count: Int, VimOperator)        // x, p, P, u, Ctrl-R, .
}
