import SwiftUI

@main
struct ScrollMyMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState()

    init() {
        // Note: setupServices and hotkeyManager.start are called in onAppear
        // because @State is not fully initialized until the view appears.
    }

    var body: some Scene {
        WindowGroup {
            SettingsView()
                .environment(appState)
                .onAppear {
                    appState.setupServices()
                    appState.hotkeyManager.start()
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
