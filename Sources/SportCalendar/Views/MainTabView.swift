import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView {
            CalendarTabView()
                .tabItem { tabItemLabel("Тренировки", systemImage: "figure.strengthtraining.traditional", imageScale: .small) }
            NutritionTabView()
                .tabItem { tabItemLabel("Питание", systemImage: "fork.knife", imageScale: .small) }
            CommunityTabView()
                .tabItem { tabItemLabel("Сообщество", systemImage: "person.2", imageScale: .small) }
            ProfileTabView()
                .tabItem { tabItemLabel("Профиль", systemImage: "person.crop.circle", imageScale: .medium) }
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

    /// Единый рендер вкладок: у SF Symbols разная «оптическая» масса; `imageScale` и более компактный символ для сообщества выравнивают таббар.
    private func tabItemLabel(_ title: String, systemImage: String, imageScale: Image.Scale) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
                .imageScale(imageScale)
        }
    }
}
