import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var appState: AppState
    /// Пустая строка — как в системе; иначе явно `light` / `dark` (из настроек).
    @AppStorage("appearanceOverride") private var appearanceOverride: String = ""

    private var preferredColorSchemeOverride: ColorScheme? {
        switch appearanceOverride {
        case "dark": return .dark
        case "light": return .light
        default: return nil
        }
    }

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
        .preferredColorScheme(preferredColorSchemeOverride)
    }
}
