import SwiftUI
import Cocoa

struct PermissionsView: View {
    @State private var isGranted = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "keyboard")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("Accessibility Access Required")
                .font(.headline)

            Text("PetruVim needs Accessibility access to provide system-wide Vim keybindings. Please grant access in System Settings.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("Open System Settings") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(30)
        .frame(width: 380, height: 280)
    }
}

final class PermissionsViewController: NSViewController {
    override func loadView() {
        let hostingView = NSHostingView(rootView: PermissionsView())
        self.view = hostingView
    }
}
