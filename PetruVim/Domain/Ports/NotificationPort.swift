protocol NotificationPort: AnyObject {
    func postModeChange(_ mode: VimMode)
}
