import SwiftUI

@main
struct ScrollMyMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState()

    var body: some Scene {
        Window("Scroll My Mac", id: "settings") {
            SettingsView()
                .environment(appState)
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
