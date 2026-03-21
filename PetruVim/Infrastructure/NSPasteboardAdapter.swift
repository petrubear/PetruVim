import Cocoa

final class NSPasteboardAdapter: ClipboardPort {
    func read() -> String? {
        NSPasteboard.general.string(forType: .string)
    }

    func write(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
}
