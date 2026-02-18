import SwiftUI
import ServiceManagement

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
            // If onboarding is complete but permission was revoked, poll for re-grant.
            if appState.hasCompletedOnboarding && !appState.isAccessibilityGranted {
                permissionManager.startPolling()
            }
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
    @State private var launchAtLogin: Bool = false

    var body: some View {
        @Bindable var appState = appState

        ZStack {
            Form {
                // MARK: - Permission Warning
                if !appState.isAccessibilityGranted {
                    Section {
                        Label("Accessibility permission required. Re-grant in System Settings > Privacy & Security > Accessibility.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.callout)
                        Button("Open Accessibility Settings") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }

                // MARK: - Scroll Mode
                Section("Scroll Mode") {
                    Toggle("Enable Scroll Mode", isOn: $appState.isScrollModeActive)
                        .disabled(!appState.isAccessibilityGranted)
                    Text(scrollModeHelpText)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Toggle("Click-through", isOn: $appState.isClickThroughEnabled)
                    Text("When enabled, clicks without dragging pass through as normal clicks. When disabled, all mouse events become scrolls.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // MARK: - Hotkey
                Section("Hotkey") {
                    HotkeyRecorderView(keyCode: $appState.hotkeyKeyCode, modifiers: $appState.hotkeyModifiers)
                    Text("Click the field and press a key to set your hotkey. Function keys work alone; other keys need a modifier (Cmd, Ctrl, Option, Shift).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // MARK: - Safety
                Section("Safety") {
                    Toggle("Safety timeout", isOn: $appState.isSafetyModeEnabled)
                    Text("Automatically deactivates scroll mode after 10 seconds of no mouse movement.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // MARK: - General
                Section("General") {
                    Toggle("Show menu bar icon", isOn: $appState.isMenuBarIconEnabled)
                    Text("Display a status icon in the menu bar for quick scroll mode toggling.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Toggle("Launch at login", isOn: $launchAtLogin)
                    Text("Start Scroll My Mac automatically when you log in. The app launches in the background.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // MARK: - Reset
                Section {
                    Button("Reset to Defaults", role: .destructive) {
                        appState.resetToDefaults()
                    }
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
        .frame(minWidth: 450, idealWidth: 450, minHeight: 300)
        .navigationTitle("Scroll My Mac")
        .onAppear {
            configureSafetyTimeout()
            launchAtLogin = SMAppService.mainApp.status == .enabled
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
        .onChange(of: launchAtLogin) { _, enabled in
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("[Settings] Launch at login error: \(error)")
                // Revert the toggle on failure
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }
    }

    // MARK: - Dynamic Help Text

    private var scrollModeHelpText: String {
        if appState.hotkeyKeyCode >= 0 {
            let hotkeyName = HotkeyDisplayHelper.displayString(
                keyCode: appState.hotkeyKeyCode,
                modifiers: appState.hotkeyModifiers
            )
            return "Press \(hotkeyName) or use this toggle to activate scroll mode."
        } else {
            return "Use this toggle to activate scroll mode."
        }
    }

    // MARK: - Safety Timeout

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
