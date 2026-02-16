import SwiftUI

@main
struct ScrollMyMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            SettingsView()
                .environment(appState)
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
