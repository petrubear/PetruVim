protocol TextElementPort: AnyObject {
    /// Returns the current text and cursor state of the focused text element.
    func readFocusedElement() throws -> TextBuffer
    /// Writes updated text and cursor state back to the focused text element.
    func writeFocusedElement(_ buffer: TextBuffer) throws
}
