import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if appState.isLoggedIn {
                MainTabView()
            } else {
                AuthView()
            }
        }
        .task {
            if appState.isLoggedIn {
                await appState.refreshBootstrap()
            }
        }
        .preferredColorScheme(colorScheme)
    }
}
