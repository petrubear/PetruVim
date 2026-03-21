protocol ClipboardPort: AnyObject {
    func read() -> String?
    func write(_ string: String)
}
