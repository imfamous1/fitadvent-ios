import SwiftUI

/// «Все / Друзья» — высота как у поля «Поиск» (`ProfileChrome.profileBarFixedHeight`); системный `UISegmentedControl` не даёт увеличить визуальную высоту сегментов на новых iOS.
struct CommunityScopeTabs: View {
    @Binding var filter: CommunityScopeFilter

    private let tabs = CommunityScopeFilter.allCases

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let count = CGFloat(tabs.count)
            let segmentW = w / max(count, 1)
            let idx = CGFloat(tabs.firstIndex(of: filter) ?? 0)
            let inset: CGFloat = 3
            let pillW = max(0, segmentW - inset * 2)
            let pillH = max(0, h - inset * 2)

            ZStack(alignment: .topLeading) {
                Capsule()
                    .fill(Color(uiColor: .tertiarySystemGroupedBackground))

                Capsule()
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    .frame(width: pillW, height: pillH)
                    .offset(x: inset + idx * segmentW, y: inset)
                    .animation(.spring(response: 0.32, dampingFraction: 0.84), value: filter)

                HStack(spacing: 0) {
                    ForEach(tabs) { tab in
                        Button {
                            filter = tab
                        } label: {
                            Text(tab.rawValue)
                                .font(.body.weight(filter == tab ? .semibold : .medium))
                                .foregroundStyle(filter == tab ? Color.primary : Color.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(height: ProfileChrome.profileBarFixedHeight)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Фильтр списка сообщества")
    }
}
