import Cocoa

@MainActor
final class MenuBarController {
    private var statusItem: NSStatusItem?
    private let onSettingsTapped: () -> Void

    init(onSettingsTapped: @escaping () -> Void) {
        self.onSettingsTapped = onSettingsTapped
    }

    func start() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateMode(.normal)

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "PetruVim", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(settingsTapped), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    func updateMode(_ mode: VimMode) {
        guard let button = statusItem?.button else { return }
        button.image = mode.statusBarImage
        button.title = ""
    }

    @objc private func settingsTapped() {
        onSettingsTapped()
    }
}

private extension VimMode {
    var statusBarImage: NSImage {
        let ptW: CGFloat = 26
        let ptH: CGFloat = 18
        let image = NSImage(size: NSSize(width: ptW, height: ptH), flipped: false) { bounds in
            // Rounded-rect border
            let borderRect = bounds.insetBy(dx: 1.0, dy: 1.0)
            let path = NSBezierPath(roundedRect: borderRect, xRadius: 3.5, yRadius: 3.5)
            path.lineWidth = 1.5
            self.modeColor.setStroke()
            path.stroke()

            // Mode letter centered
            let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: self.modeColor]
            let str = NSAttributedString(string: self.modeChar, attributes: attrs)
            let sz = str.size()
            str.draw(at: NSPoint(
                x: (bounds.width - sz.width) / 2,
                y: (bounds.height - sz.height) / 2 + 0.5
            ))
            return true
        }
        image.isTemplate = false
        return image
    }

    var modeChar: String {
        switch self {
        case .normal: return "N"
        case .insert: return "I"
        case .visual: return "V"
        }
    }

    var modeColor: NSColor {
        switch self {
        case .normal: return .labelColor                                                      // adapts light/dark
        case .insert: return NSColor(calibratedRed: 0.95, green: 0.65, blue: 0.10, alpha: 1) // amber
        case .visual: return NSColor(calibratedRed: 0.35, green: 0.65, blue: 1.00, alpha: 1) // blue
        }
    }
}
