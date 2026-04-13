import SwiftUI

struct NutritionTabView: View {
    @EnvironmentObject private var appState: AppState
    @State private var day = MoscowCalendar.todayYmd()
    @State private var data: NutritionDayResponse?
    @State private var loading = false
    @State private var errorText: String?
    @State private var mealType = "breakfast"
    @State private var titleInput = ""
    @State private var kcalInput = ""
    private let meals: [(String, String)] = [
        ("breakfast", "Завтрак"),
        ("lunch", "Обед"),
        ("dinner", "Ужин"),
        ("snack", "Перекус"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    TabMegaHeader(title: "Питание", subtitle: "Следи за своим питанием")
                        .padding(.bottom, 16)

                    if let p = appState.bootstrap?.user.profile, vipActive(p) {
                        dayNav
                        if let err = errorText {
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding(.bottom, 8)
                        }
                        summaryCard
                        addMealBlock
                        entriesList
                    } else if appState.bootstrap != nil {
                        premiumGate
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .task { await load() }
            .onChange(of: day) { _, _ in Task { await load() } }
            .refreshable { await load() }
        }
    }

    private var premiumGate: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Доступно в Премиуме")
                .font(.title3.weight(.bold))
            Text("Журнал питания и учёт калорий по дням доступны по подписке Премиум.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ProfileChrome.radiusXl, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }

    private var dayNav: some View {
        let today = MoscowCalendar.todayYmd()
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dayLabel(day, today: today))
                        .font(.headline)
                    Text(day == today ? "Сегодня по Москве" : "Московский календарный день")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 8) {
                    if day != today {
                        Button("Сегодня") { day = today }
                            .buttonStyle(.bordered)
                    }
                    Button {
                        shiftDay(-1)
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.bordered)
                    Button {
                        shiftDay(1)
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(.bottom, 14)
    }

    private func dayLabel(_ ymd: String, today: String) -> String {
        let parts = ymd.split(separator: "-")
        guard parts.count == 3,
              let d = Int(parts[2]),
              let m = Int(parts[1]), m >= 1, m <= 12 else { return ymd }
        let names = [
            "января", "февраля", "марта", "апреля", "мая", "июня",
            "июля", "августа", "сентября", "октября", "ноября", "декабря",
        ]
        if ymd == today { return "Сегодня, \(d) \(names[m - 1])" }
        return "\(d) \(names[m - 1])"
    }

    private func shiftDay(_ delta: Int) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Moscow") ?? .current
        let f = DateFormatter()
        f.calendar = cal
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: day) else { return }
        guard let next = cal.date(byAdding: .day, value: delta, to: date) else { return }
        day = f.string(from: next)
    }

    @ViewBuilder
    private var summaryCard: some View {
        if let d = data {
            VStack(alignment: .leading, spacing: 10) {
                Text("За день")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("\(d.totalKcal) ккал")
                    .font(.title.weight(.heavy))
                    .foregroundStyle(Color(red: ProfileChrome.primary.red, green: ProfileChrome.primary.green, blue: ProfileChrome.primary.blue))
                if let goal = appState.bootstrap?.user.profile.dailyKcalGoal, goal > 0 {
                    let pct = min(1.0, Double(d.totalKcal) / Double(goal))
                    ProgressView(value: pct) {
                        Text("Цель \(goal) ккал")
                    }
                    .tint(Color(red: ProfileChrome.primary.red, green: ProfileChrome.primary.green, blue: ProfileChrome.primary.blue))
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: ProfileChrome.radiusXl, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
            .padding(.bottom, 16)
        }
    }

    private var addMealBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Добавить приём пищи")
                .font(.headline)
            Picker("Тип", selection: $mealType) {
                ForEach(meals, id: \.0) { t in
                    Text(t.1).tag(t.0)
                }
            }
            .pickerStyle(.segmented)
            TextField("Название (необязательно)", text: $titleInput)
            TextField("Ккал", text: $kcalInput)
            #if os(iOS)
                .keyboardType(.numberPad)
            #endif
            if let errorText {
                Text(errorText).font(.caption).foregroundStyle(.red)
            }
            Button {
                Task { await addMeal() }
            } label: {
                Text("Добавить")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: ProfileChrome.radiusLg, style: .continuous)
                            .fill(Color(red: ProfileChrome.primary.red, green: ProfileChrome.primary.green, blue: ProfileChrome.primary.blue))
                    )
                    .foregroundStyle(.white)
            }
            .disabled(loading || Int(kcalInput.trimmingCharacters(in: .whitespaces)) == nil)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: ProfileChrome.radiusXl, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private var entriesList: some View {
        if let d = data, !d.entries.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("Записи")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
                ForEach(d.entries) { e in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(mealLabel(e.mealType))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(e.title.isEmpty ? "—" : e.title)
                                .font(.body.weight(.medium))
                            Text("\(e.kcal) ккал")
                                .font(.subheadline)
                                .foregroundStyle(Color(red: ProfileChrome.accentBlue.red, green: ProfileChrome.accentBlue.green, blue: ProfileChrome.accentBlue.blue))
                        }
                        Spacer()
                        Button(role: .destructive) {
                            Task { await deleteEntry(id: e.id) }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .disabled(loading)
                    }
                    .padding(.vertical, 8)
                    if e.id != d.entries.last?.id {
                        Divider()
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: ProfileChrome.radiusXl, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
        } else if loading {
            ProgressView().frame(maxWidth: .infinity)
        } else {
            Text("Нет записей за день — добавьте приём пищи.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func mealLabel(_ key: String) -> String {
        meals.first { $0.0 == key }?.1 ?? key
    }

    private func load() async {
        loading = true
        errorText = nil
        defer { loading = false }
        do {
            let r = try await APIClient.shared.getNutritionDecoded(day: day)
            data = r
        } catch let e as APIClientError {
            if e.statusCode == 403 {
                errorText = e.message
                data = nil
            } else {
                errorText = e.message
            }
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func addMeal() async {
        guard let k = Int(kcalInput.trimmingCharacters(in: .whitespaces)), k > 0 else {
            errorText = "Укажите калории"
            return
        }
        loading = true
        errorText = nil
        defer { loading = false }
        do {
            let t = titleInput.trimmingCharacters(in: .whitespaces)
            _ = try await APIClient.shared.postNutrition(NutritionPostBody(
                day: day,
                mealType: mealType,
                title: t.isEmpty ? nil : t,
                kcal: k
            ))
            kcalInput = ""
            titleInput = ""
            await appState.refreshBootstrap()
            await load()
        } catch let e as APIClientError {
            errorText = e.message
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func deleteEntry(id: Int) async {
        loading = true
        defer { loading = false }
        do {
            try await APIClient.shared.deleteNutrition(id: id)
            await appState.refreshBootstrap()
            await load()
        } catch let e as APIClientError {
            errorText = e.message
        } catch {
            errorText = error.localizedDescription
        }
    }
}
