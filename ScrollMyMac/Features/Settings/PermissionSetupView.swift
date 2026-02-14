import SwiftUI

struct PermissionSetupView: View {
    var permissionManager: PermissionManager

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "hand.raised.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Accessibility Permission Required")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Scroll My Mac needs Accessibility access to intercept mouse events and convert them to scroll events system-wide.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 320)

            VStack(alignment: .leading, spacing: 8) {
                Label("Open System Settings", systemImage: "1.circle")
                Label("Go to Privacy & Security > Accessibility", systemImage: "2.circle")
                Label("Enable Scroll My Mac", systemImage: "3.circle")
            }
            .padding()

            Button("Grant Permission") {
                permissionManager.requestPermission()
                permissionManager.startPolling()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button("Open System Settings") {
                permissionManager.openAccessibilitySettings()
                permissionManager.startPolling()
            }
            .buttonStyle(.bordered)

            Text("The app will detect permission automatically -- no restart needed.")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .padding(40)
        .frame(minWidth: 400, minHeight: 350)
        .onDisappear {
            permissionManager.stopPolling()
        }
    }
}
