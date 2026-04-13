import SwiftUI

/// «Все / Друзья» — системный сегментированный `Picker` + плотнее, чем «голый» glass у контрола, фон ближе по ощущению к таббару.
struct CommunityScopeTabs: View {
    @Binding var filter: CommunityScopeFilter

    var body: some View {
        Picker("Фильтр списка сообщества", selection: $filter) {
            ForEach(CommunityScopeFilter.allCases) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .accessibilityLabel("Фильтр списка сообщества")
        .padding(3)
        .background {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Material.thickMaterial)
        }
    }
}
