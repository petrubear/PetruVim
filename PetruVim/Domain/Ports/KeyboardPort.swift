struct KeyEvent: Equatable {
    let keyCode: UInt16
    let characters: String?
    let modifiers: Modifiers

    struct Modifiers: OptionSet, Equatable {
        let rawValue: UInt32
        static let shift   = Modifiers(rawValue: 1 << 0)
        static let control = Modifiers(rawValue: 1 << 1)
        static let option  = Modifiers(rawValue: 1 << 2)
        static let command = Modifiers(rawValue: 1 << 3)
    }

    var isCommandModified: Bool { modifiers.contains(.command) }
    var isOptionModified:  Bool { modifiers.contains(.option) }
}

protocol KeyboardPort: AnyObject {
    /// Called by the adapter when a key-down event is received.
    /// Return `true` to suppress the event, `false` to pass it through.
    var onKeyEvent: ((KeyEvent) -> Bool)? { get set }

    func startListening()
    func stopListening()

    /// Post a synthetic key event (used for undo/redo via Cmd-Z).
    func postSyntheticEvent(_ event: KeyEvent)
}
