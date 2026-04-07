import SwiftUI

@main
struct SportCalendarApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(appState)
        }
    }
}
