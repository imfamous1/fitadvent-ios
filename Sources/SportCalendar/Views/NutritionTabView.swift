import SwiftUI

struct NutritionTabView: View {
    @EnvironmentObject private var appState: AppState
    @State private var day = MoscowCalendar.todayYmd()
    @State private var data: NutritionDayResponse?
    @State private var loading = false
    @State private var errorText: String?
    @State private var mealType = "breakfast"
    @State private var titleInput = ""
    @State private var gramsInput = ""
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
                        .padding(.top, 8)
                        .padding(.bottom, 20)

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
        let lead = dayLead(day, today: today)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(lead.title)
                        .font(.title3.weight(.bold))
                    if !lead.subtitle.isEmpty {
                        Text(lead.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.leading, ProfileChrome.exerciseSectionTitleLeading)
                Spacer()
                HStack(spacing: 10) {
                    if day != today {
                        Button("Сегодня") { day = today }
                            .buttonStyle(.bordered)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    Button {
                        shiftDay(-1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(ProfileChrome.groupedContentSurface))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Предыдущий день")
                    Button {
                        shiftDay(1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(ProfileChrome.groupedContentSurface))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Следующий день")
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

    private func dayLead(_ ymd: String, today: String) -> (title: String, subtitle: String) {
        let formatted = dayLabel(ymd, today: today).replacingOccurrences(of: "Сегодня, ", with: "")
        if ymd == today {
            return ("Сегодня", formatted)
        }
        return (weekdayTitle(ymd), formatted)
    }

    private func weekdayTitle(_ ymd: String) -> String {
        let parts = ymd.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else { return ymd }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Moscow") ?? .current
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        guard let date = calendar.date(from: comps) else { return ymd }
        let weekday = calendar.component(.weekday, from: date)
        let names = [
            "Воскресенье", "Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота",
        ]
        return names[max(1, min(7, weekday)) - 1]
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
            let meta = nutritionGoalMeta()
            VStack(alignment: .leading, spacing: 10) {
                Text("За день")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("\(d.totalKcal) ккал")
                    .font(.title.weight(.heavy))
                    .foregroundStyle(.primary)
                if let recommendation = meta.recommendation {
                    Text(recommendation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if meta.goal > 0 {
                    let goal = meta.goal
                    let pct = min(1.0, Double(d.totalKcal) / Double(goal))
                    ProgressView(value: pct)
                    .tint(Color(red: ProfileChrome.primary.red, green: ProfileChrome.primary.green, blue: ProfileChrome.primary.blue))
                    Text("\(d.totalKcal) из \(goal)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
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
        VStack(alignment: .leading, spacing: 10) {
            Text("Добавить приём пищи")
                .font(.title3.weight(.bold))
                .padding(.leading, ProfileChrome.exerciseSectionTitleLeading)
            Picker("Тип", selection: $mealType) {
                ForEach(meals, id: \.0) { t in
                    Text(t.1).tag(t.0)
                }
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 12)

            VStack(alignment: .leading, spacing: 4) {
                nutritionInputLabel(title: "Блюдо", optional: true)
                nutritionInputField("гречка", text: $titleInput)
            }

            VStack(alignment: .leading, spacing: 4) {
                nutritionInputLabel(title: "Граммы", optional: true)
                nutritionInputField("100", text: $gramsInput, keyboard: .numberPad)
            }

            VStack(alignment: .leading, spacing: 4) {
                nutritionInputLabel(title: "ККАЛ", optional: false)
                nutritionInputField("342", text: $kcalInput, keyboard: .decimalPad)
            }

            Text("Всего: \(calculatedInputKcal()) ккал")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, ProfileChrome.exerciseSectionTitleLeading)

            if let errorText {
                Text(errorText).font(.caption).foregroundStyle(.red)
            }

            Button {
                Task { await addMeal() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                    Text("Добавить")
                        .font(.body.weight(.semibold))
                }
                .frame(maxWidth: .infinity, minHeight: ProfileChrome.profileBarFixedHeight, maxHeight: ProfileChrome.profileBarFixedHeight, alignment: .center)
                .background(
                    Capsule()
                        .fill(Color(red: ProfileChrome.accentBlue.red, green: ProfileChrome.accentBlue.green, blue: ProfileChrome.accentBlue.blue))
                )
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(loading || calculatedInputKcal() <= 0)
        }
        .padding(.bottom, 16)
    }

    private func nutritionInputLabel(title: String, optional: Bool) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            if optional {
                Text("необязательно")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.leading, ProfileChrome.exerciseSectionTitleLeading)
    }

    private func nutritionInputField(_ placeholder: String, text: Binding<String>, keyboard: UIKeyboardType? = nil) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .padding(.horizontal, 16)
            .frame(minHeight: ProfileChrome.profileBarFixedHeight, maxHeight: ProfileChrome.profileBarFixedHeight)
            .background(
                Capsule()
                    .fill(ProfileChrome.groupedContentSurface)
            )
#if os(iOS)
            .keyboardType(keyboard ?? .default)
#endif
    }

    private func calculatedInputKcal() -> Int {
        let kcalRaw = kcalInput.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        let gramsRaw = gramsInput.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        let grams = Double(gramsRaw)
        let kcalNumber = Double(kcalRaw)
        if let grams, grams > 0, let kcalNumber, kcalNumber > 0 {
            return min(10_000, Int((grams * kcalNumber / 100).rounded()))
        }
        if let kcalNumber, kcalNumber > 0 {
            return min(10_000, Int(kcalNumber.rounded()))
        }
        return 0
    }

    private func nutritionGoalMeta() -> (goal: Int, recommendation: String?) {
        guard let profile = appState.bootstrap?.user.profile else {
            return (0, nil)
        }
        let manualGoal = max(0, profile.dailyKcalGoal ?? 0)
        let normsPack = computeTdeeAndKcalNorms(profile)
        let recommended = normsPack.norms.maintenance
        let resolvedGoal = manualGoal > 0 ? manualGoal : max(0, recommended ?? 0)
        if let recommended, recommended > 0 {
            if let bmi = normsPack.bmi {
                let bmiText = String(format: "%.1f", bmi).replacingOccurrences(of: ".", with: ",")
                return (resolvedGoal, "Рекомендуемо ~\(recommended) ккал · ИМТ \(bmiText)")
            }
            return (resolvedGoal, "Рекомендуемо ~\(recommended) ккал")
        }
        return (resolvedGoal, "Рекомендуемо: укажи рост и вес в профиле")
    }

    @ViewBuilder
    private var entriesList: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Записи")
                .font(.title3.weight(.bold))
            Text("Уже в журнале за выбранный день")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.leading, ProfileChrome.exerciseSectionTitleLeading)
        .padding(.bottom, 8)

        VStack(alignment: .leading, spacing: 4) {
            if let d = data, !d.entries.isEmpty {
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
            } else if loading {
                ProgressView().frame(maxWidth: .infinity)
            } else {
                Text("За этот день записей пока нет.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, ProfileChrome.exerciseSectionTitleLeading)
                    .padding(.top, 2)
                    .padding(.bottom, 4)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ProfileChrome.radiusXl, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
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
        let k = calculatedInputKcal()
        guard k > 0 else {
            errorText = "С граммами укажите ккал на 100 г, либо введите всего ккал порции."
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
            gramsInput = ""
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
