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
    @State private var safetyTimeoutManager = SafetyTimeoutManager()
    @State private var showSafetyNotification = false

    var body: some View {
        @Bindable var appState = appState

        ZStack {
            Form {
                Section("Scroll Mode") {
                    Toggle("Enable Scroll Mode", isOn: $appState.isScrollModeActive)
                        .disabled(true)
                    Text("Toggle will be activated in a future update.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Safety") {
                    Toggle("Safety timeout", isOn: $appState.isSafetyModeEnabled)
                    Text("Automatically deactivates scroll mode after 10 seconds of no mouse movement.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            if showSafetyNotification {
                VStack {
                    Spacer()
                    Text("Scroll mode deactivated (safety timeout)")
                        .font(.callout)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                        .padding(.bottom, 16)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .allowsHitTesting(false)
            }
        }
        .frame(minWidth: 450, idealWidth: 450, minHeight: 250)
        .navigationTitle("Scroll My Mac")
        .onAppear {
            configureSafetyTimeout()
        }
        .onChange(of: appState.isScrollModeActive) { _, isActive in
            if isActive && appState.isSafetyModeEnabled {
                safetyTimeoutManager.startMonitoring()
            } else {
                safetyTimeoutManager.stopMonitoring()
            }
        }
        .onChange(of: appState.isSafetyModeEnabled) { _, isEnabled in
            if isEnabled && appState.isScrollModeActive {
                safetyTimeoutManager.startMonitoring()
            } else if !isEnabled {
                safetyTimeoutManager.stopMonitoring()
            }
        }
    }

    private func configureSafetyTimeout() {
        safetyTimeoutManager.onSafetyTimeout = { [weak appState] in
            guard let appState else { return }
            appState.isScrollModeActive = false
            withAnimation {
                showSafetyNotification = true
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                withAnimation {
                    showSafetyNotification = false
                }
            }
        }
    }
}
