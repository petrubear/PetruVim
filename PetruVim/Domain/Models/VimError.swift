enum VimError: Error, Equatable {
    case noFocusedElement
    case unsupportedElementRole
    case accessibilityReadFailed
    case accessibilityWriteFailed
    case noTextToOperate
}
