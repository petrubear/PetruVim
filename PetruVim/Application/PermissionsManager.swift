import Cocoa
@preconcurrency import ApplicationServices

@MainActor
final class PermissionsManager {
    var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    /// Request accessibility permissions. Shows system prompt if needed.
    func requestAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    /// Poll for permission changes. Calls `onChange` on the main actor when status changes.
    func observePermissionChanges(onChange: @escaping @MainActor (Bool) -> Void) {
        let current = isAccessibilityGranted
        Task { @MainActor in
            while true {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                let granted = AXIsProcessTrusted()
                if granted != current {
                    onChange(granted)
                    if granted { return }
                }
            }
        }
    }
}
