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
        statusItem?.button?.title = mode.statusBarLabel
    }

    @objc private func settingsTapped() {
        onSettingsTapped()
    }
}

private extension VimMode {
    var statusBarLabel: String {
        switch self {
        case .normal: return "N"
        case .insert: return "I"
        case .visual: return "V"
        }
    }
}
