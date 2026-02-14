import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) var appState
    @State private var permissionManager = PermissionManager()

    var body: some View {
        Group {
            if appState.isAccessibilityGranted || appState.hasCompletedOnboarding {
                MainSettingsView()
            } else {
                PermissionSetupView(permissionManager: permissionManager)
            }
        }
        .onAppear {
            syncPermissionState()
        }
        .onChange(of: permissionManager.isAccessibilityGranted) { _, granted in
            appState.isAccessibilityGranted = granted
            if granted {
                appState.hasCompletedOnboarding = true
            }
        }
    }

    private func syncPermissionState() {
        appState.isAccessibilityGranted = permissionManager.isAccessibilityGranted
    }
}

struct MainSettingsView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        @Bindable var appState = appState

        Form {
            Section("Scroll Mode") {
                Toggle("Enable Scroll Mode", isOn: $appState.isScrollModeActive)
            }

            Section("Safety") {
                Toggle("Safety timeout (auto-deactivate after 10s of no movement)",
                       isOn: Binding(
                        get: { appState.isSafetyModeEnabled },
                        set: { appState.isSafetyModeEnabled = $0 }
                       ))
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 400, minHeight: 300)
    }
}
