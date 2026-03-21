protocol TextElementPort: AnyObject {
    /// Returns the current text and cursor state of the focused text element.
    func readFocusedElement() throws -> TextBuffer
    /// Reads the focused element, applies transform, and writes the result back
    /// to the **same** element — preventing races if focus changes between read and write.
    /// If transform returns nil, no write is performed.
    func updateFocusedElement(_ transform: (TextBuffer) throws -> TextBuffer?) throws
}
