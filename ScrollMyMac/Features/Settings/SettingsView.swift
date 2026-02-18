import SwiftUI
import ServiceManagement
import UniformTypeIdentifiers

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
    @State private var selectedExcludedApp: String?

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
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Toggle("Click-through", isOn: $appState.isClickThroughEnabled)
                    Text("When enabled, clicks without dragging pass through as normal clicks. When disabled, all mouse events become scrolls.")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Toggle("Hold-to-passthrough", isOn: $appState.isHoldToPassthroughEnabled)
                    Text("Hold the mouse still within the click dead zone to pass through the click for normal drag operations (text selection, window resize).")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    HStack {
                        Text("Hold delay")
                        Spacer()
                        Text("\(appState.holdToPassthroughDelay, specifier: "%.2f")s")
                            .monospacedDigit()
                            .foregroundStyle(appState.isHoldToPassthroughEnabled ? .primary : .secondary)
                        Stepper("Hold delay", value: $appState.holdToPassthroughDelay, in: 0.25...5.0, step: 0.25)
                            .labelsHidden()
                    }
                    .disabled(!appState.isHoldToPassthroughEnabled)
                    Text("How long to hold still before the click passes through (0.25s \u{2013} 5s).")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                // MARK: - Hotkey
                Section("Hotkey") {
                    HotkeyRecorderView(keyCode: $appState.hotkeyKeyCode, modifiers: $appState.hotkeyModifiers)
                    Text("Click the field and press a key to set your hotkey. Function keys work alone; other keys need a modifier (Cmd, Ctrl, Option, Shift).")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                // MARK: - Safety
                Section("Safety") {
                    Toggle("Safety timeout", isOn: $appState.isSafetyModeEnabled)
                    Text("Automatically deactivates scroll mode after 10 seconds of no mouse movement.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                // MARK: - General
                Section("General") {
                    Toggle("Show menu bar icon", isOn: $appState.isMenuBarIconEnabled)
                    Text("Display a status icon in the menu bar for quick scroll mode toggling.")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Toggle("Launch at login", isOn: $launchAtLogin)
                    Text("Start Scroll My Mac automatically when you log in. The app launches in the background.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                // MARK: - Reset
                Section {
                    Button("Reset to Defaults", role: .destructive) {
                        appState.resetToDefaults()
                    }
                }

                // MARK: - Excluded Apps
                Section("Excluded Apps") {
                    if appState.excludedAppBundleIDs.isEmpty {
                        Text("No excluded apps")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(appState.excludedAppBundleIDs, id: \.self) { bundleID in
                            HStack(spacing: 8) {
                                Image(nsImage: iconForBundleID(bundleID))
                                    .resizable()
                                    .frame(width: 20, height: 20)
                                Text(displayNameForBundleID(bundleID))
                                Spacer()
                            }
                            .padding(.vertical, 2)
                            .contentShape(Rectangle())
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(selectedExcludedApp == bundleID ? Color.accentColor.opacity(0.2) : Color.clear)
                            )
                            .onTapGesture {
                                selectedExcludedApp = bundleID
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        Button {
                            addExcludedAppViaPanel()
                        } label: {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.borderless)

                        Button {
                            if let selected = selectedExcludedApp {
                                appState.removeExcludedApp(bundleID: selected)
                                selectedExcludedApp = nil
                            }
                        } label: {
                            Image(systemName: "minus")
                        }
                        .buttonStyle(.borderless)
                        .disabled(selectedExcludedApp == nil)

                        Spacer()
                    }

                    Text("Apps where scroll mode is automatically bypassed. Scroll mode stays on but clicks pass through normally.")
                        .font(.callout)
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
        .frame(minWidth: 450, idealWidth: 450, minHeight: 400)
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

    // MARK: - Excluded App Helpers

    private func iconForBundleID(_ bundleID: String) -> NSImage {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSWorkspace.shared.icon(for: .applicationBundle)
    }

    private func displayNameForBundleID(_ bundleID: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
           let bundle = Bundle(url: url) {
            if let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String {
                return displayName
            }
            if let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String {
                return name
            }
        }
        return bundleID
    }

    private func addExcludedAppViaPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message = "Select an app to exclude from scroll mode"

        if panel.runModal() == .OK, let selectedURL = panel.url {
            if let bundleID = Bundle(url: selectedURL)?.bundleIdentifier {
                appState.addExcludedApp(bundleID: bundleID)
            }
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
