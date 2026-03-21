import Cocoa
import SwiftUI

@MainActor
final class AppCoordinator {
    private let permissionsManager = PermissionsManager()
    private var menuBarController: MenuBarController?
    private var engine: VimEngine?
    private var settingsWindow: NSWindow?
    private var permissionsWindow: NSWindow?

    // Adapters must be stored here — local vars in startEngine() would be
    // deallocated immediately, leaving the CGEvent tap with a dangling pointer.
    private var textElementAdapter: AXTextElementAdapter?
    private var keyboardAdapter: CGEventKeyboardAdapter?
    private var clipboardAdapter: NSPasteboardAdapter?
    private var notificationsAdapter: DistributedNotifAdapter?

    func start() {
        menuBarController = MenuBarController(onSettingsTapped: { [weak self] in
            self?.showSettingsWindow()
        })
        menuBarController?.start()

        if permissionsManager.isAccessibilityGranted {
            startEngine()
        } else {
            // Trigger the system accessibility prompt immediately, then show our own window.
            permissionsManager.requestAccessibilityPermissions()
            showPermissionsWindow()
            permissionsManager.observePermissionChanges { @MainActor [weak self] granted in
                if granted {
                    self?.permissionsWindow?.close()
                    self?.permissionsWindow = nil
                    self?.startEngine()
                }
            }
        }
    }

    func stop() {
        engine?.stop()
    }

    private func startEngine() {
        let textElement = AXTextElementAdapter()
        let keyboard = CGEventKeyboardAdapter()
        let clipboard = NSPasteboardAdapter()
        let notifications = DistributedNotifAdapter()

        textElementAdapter = textElement
        keyboardAdapter = keyboard
        clipboardAdapter = clipboard
        notificationsAdapter = notifications

        engine = VimEngine(
            textElement: textElement,
            keyboard: keyboard,
            clipboard: clipboard,
            notifications: notifications
        )
        engine?.start()

        // Wrap the keyboard handler to enforce the app exclusion list.
        // VimEngine itself has no AppKit dependency; filtering happens here.
        let originalHandler = keyboard.onKeyEvent
        keyboard.onKeyEvent = { event in
            if let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
               ExcludedAppsStore.shared.isExcluded(bundleID) {
                return false
            }
            return originalHandler?(event) ?? false
        }
        menuBarController?.updateMode(.normal)

        // Observe mode changes to update menu bar
        DistributedNotificationCenter.default().addObserver(
            forName: DistributedNotifAdapter.modeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let modeString = notification.userInfo?[DistributedNotifAdapter.modeKey] as? String else { return }
            let mode: VimMode
            switch modeString {
            case "N": mode = .normal
            case "I": mode = .insert
            case "V": mode = .visual
            default: return
            }
            Task { @MainActor [weak self] in
                self?.menuBarController?.updateMode(mode)
            }
        }
    }

    func showSettingsWindow() {
        if let existing = settingsWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 390),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "PetruVim Settings"
        window.contentViewController = NSHostingController(rootView: SettingsView())
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    private func showPermissionsWindow() {
        let controller = PermissionsViewController()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "PetruVim Permissions"
        window.contentViewController = controller
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        permissionsWindow = window
    }
}
