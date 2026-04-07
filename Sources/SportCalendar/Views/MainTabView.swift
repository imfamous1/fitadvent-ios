import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView {
            CalendarTabView()
                .tabItem { Label("Тренировки", systemImage: "figure.strengthtraining.traditional") }
            NutritionTabView()
                .tabItem { Label("Питание", systemImage: "fork.knife") }
            CommunityTabView()
                .tabItem { Label("Сообщество", systemImage: "person.3") }
            ProfileTabView()
                .tabItem { Label("Профиль", systemImage: "person.crop.circle") }
        }
        .overlay(alignment: .top) {
            if appState.isLoading {
                ProgressView()
                    .padding(8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 8)
            }
        }
    }
}
