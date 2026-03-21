protocol TextElementPort: AnyObject {
    /// Reads the focused element, applies transform, and writes the result back
    /// to the **same** element — preventing races if focus changes between read and write.
    func updateFocusedElement(_ transform: (TextBuffer) throws -> TextBuffer) throws
}
