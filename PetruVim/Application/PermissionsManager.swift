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

    /// Poll for permission changes. Calls `onChange` on the main actor whenever status changes.
    /// Keeps running indefinitely so revocation is also detected.
    func observePermissionChanges(onChange: @escaping @MainActor (Bool) -> Void) {
        Task { @MainActor in
            var current = isAccessibilityGranted
            while true {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                let granted = AXIsProcessTrusted()
                if granted != current {
                    current = granted
                    onChange(granted)
                }
            }
        }
    }
}
