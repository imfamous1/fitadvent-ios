import SwiftUI

struct CalendarTabView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @State private var showWordsGame = false
    @State private var selectedCalendarId: String = ""
    @State private var dayDetail: DayDetail?
    @State private var saving = false
    @State private var banner: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    TabMegaHeader(
                        title: MoscowCalendar.monthTitle(calendarId: calendarIdForTitle),
                        subtitle: "Отмечай свои тренировки"
                    )
                    .padding(.top, 8)
                    .padding(.bottom, 20)

                    if let banner {
                        Text(banner)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.bottom, 8)
                    }

                    streakBanner
                    monthGrid
                    gamesSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear { syncCalendarIfNeeded() }
            .refreshable { await appState.refreshBootstrap() }
            .sheet(item: $dayDetail) { det in
                daySheetContent(day: det.day)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showWordsGame) {
                WordsGameTabView()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var calendarIdForTitle: String {
        selectedCalendarId.isEmpty ? MoscowCalendar.defaultCalendarId(keys: []) : selectedCalendarId
    }

    private struct DayDetail: Identifiable {
        var id: Int { day }
        var day: Int
    }

    private func syncCalendarIfNeeded() {
        selectedCalendarId = MoscowCalendar.defaultCalendarId(keys: [])
    }

    @ViewBuilder
    private var streakBanner: some View {
        if let b = appState.bootstrap {
            let streak = monthStreakStats(for: calendarIdForTitle, in: b)
            let ringTrack = colorScheme == .dark ? Color.green.opacity(0.32) : Color.green.opacity(0.24)
            let ringProgress = colorScheme == .dark ? Color(red: 0.26, green: 0.95, blue: 0.47) : Color(red: 0.10, green: 0.72, blue: 0.31)
            let flameColor = colorScheme == .dark ? Color(red: 0.35, green: 0.98, blue: 0.53) : Color(red: 0.07, green: 0.66, blue: 0.29)
            let titleColor = colorScheme == .dark ? Color(red: 0.83, green: 0.97, blue: 0.86) : Color(red: 0.08, green: 0.32, blue: 0.18)
            let badgeFill = colorScheme == .dark ? Color(red: 0.12, green: 0.32, blue: 0.18) : Color.green.opacity(0.18)
            let borderColor = colorScheme == .dark ? Color(red: 0.22, green: 0.58, blue: 0.34).opacity(0.8) : Color.green.opacity(0.22)
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .trim(from: 0, to: 0.8)
                        .stroke(ringTrack, style: StrokeStyle(lineWidth: 5.25, lineCap: .round))
                        .rotationEffect(.degrees(126))
                    Circle()
                        .trim(from: 0, to: 0.8 * streak.ringRatio)
                        .stroke(ringProgress, style: StrokeStyle(lineWidth: 5.25, lineCap: .round))
                        .rotationEffect(.degrees(126))
                    VStack(spacing: 1) {
                        Text("\(streak.current)")
                            .font(.system(size: 19, weight: .heavy, design: .rounded))
                            .foregroundStyle(titleColor)
                        Text(dayWord(streak.current))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(flameColor)
                        .offset(y: 30)
                }
                .frame(width: 72, height: 72)

                VStack(alignment: .leading, spacing: 4) {
                    Text(streak.current > 0 ? "Так держать" : "Серия тренировок")
                        .font(.system(size: 15, weight: .heavy))
                    Text(streak.subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        Text("Рекорд серии")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text("\(streak.longest) \(dayWord(streak.longest))")
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(badgeFill)
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(borderColor, lineWidth: 1)
                            )
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: colorScheme == .dark
                                ? [Color(red: 0.09, green: 0.19, blue: 0.13), Color(red: 0.13, green: 0.27, blue: 0.18)]
                                : [Color(red: 0.95, green: 0.99, blue: 0.96), Color(red: 0.88, green: 0.97, blue: 0.91)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .padding(.bottom, 12)
        }
    }

    private func monthStreakStats(for calId: String, in b: BootstrapResponse) -> (current: Int, longest: Int, ringRatio: CGFloat, subtitle: String) {
        let days = b.progress[calId]?.days ?? [:]
        let dim = MoscowCalendar.daysInMonth(calendarId: calId)
        let sorted = (1 ... dim).map { days[String($0)]?.done == true }

        var longest = 0
        var running = 0
        for done in sorted {
            if done {
                running += 1
                longest = max(longest, running)
            } else {
                running = 0
            }
        }

        let current = sorted.reversed().prefix { $0 }.count
        let ratio = dim > 0 ? min(1, max(0, CGFloat(current) / CGFloat(dim))) : 0
        let subtitle: String
        if current >= 7 {
            subtitle = "Уже целую неделю подряд отмечаешь тренировки в этом месяце."
        } else if current >= 2 {
            subtitle = "Отмечай дни подряд - серия будет расти."
        } else if current == 1 {
            subtitle = "Зайди завтра, чтобы не обнулить счётчик."
        } else {
            subtitle = "Отметь тренировку - начнём считать дни подряд."
        }
        return (current, longest, ratio, subtitle)
    }

    private func dayWord(_ n: Int) -> String {
        let x = abs(n) % 100
        if (11 ... 14).contains(x) { return "дней" }
        switch abs(n) % 10 {
        case 1: return "день"
        case 2 ... 4: return "дня"
        default: return "дней"
        }
    }

    private var monthGrid: some View {
        let calId = calendarIdForTitle
        let dim = MoscowCalendar.daysInMonth(calendarId: calId)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Moscow") ?? .current
        let parts = calId.split(separator: "-")
        let y = Int(parts[0]) ?? 2026
        let m = Int(parts[1]) ?? 1
        var c = DateComponents()
        c.year = y
        c.month = m
        c.day = 1
        let firstDate = cal.date(from: c) ?? Date()
        let weekday = cal.component(.weekday, from: firstDate)
        let leading = (weekday + 5) % 7
        let prevMonthDate = cal.date(byAdding: .month, value: -1, to: firstDate) ?? firstDate
        let prevMonthDim = cal.range(of: .day, in: .month, for: prevMonthDate)?.count ?? 30
        let trailing = (7 - ((leading + dim) % 7)) % 7

        let rows = appState.bootstrap?.progress[calId]?.days ?? [:]

        return VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                ForEach(["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"], id: \.self) { w in
                    Text(w)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(0 ..< leading, id: \.self) { i in
                    let dayNum = prevMonthDim - leading + i + 1
                    dayCell(
                        day: dayNum,
                        visual: .outside,
                        action: nil
                    )
                }

                ForEach(1 ... dim, id: \.self) { day in
                    let done = rows[String(day)]?.done == true
                    dayCell(
                        day: day,
                        visual: dayVisualState(year: y, month: m, day: day, done: done),
                        action: { dayDetail = DayDetail(day: day) }
                    )
                }

                ForEach(0 ..< trailing, id: \.self) { i in
                    dayCell(
                        day: i + 1,
                        visual: .outside,
                        action: nil
                    )
                }
            }
        }
        .padding(.bottom, 20)
    }

    private enum DayVisualState {
        case done
        case missed
        case today
        case future
        case outside
    }

    private func dayVisualState(year: Int, month: Int, day: Int, done: Bool) -> DayVisualState {
        if done { return .done }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Moscow") ?? .current
        let today = cal.startOfDay(for: Date())
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        let date = cal.date(from: comps) ?? today
        let cmp = cal.compare(cal.startOfDay(for: date), to: today, toGranularity: .day)
        if cmp == .orderedSame { return .today }
        if cmp == .orderedDescending { return .future }
        return .missed
    }

    private func dayCell(day: Int, visual: DayVisualState, action: (() -> Void)?) -> some View {
        let background = Color(uiColor: .secondarySystemGroupedBackground)
        let iconBackground: Color
        let iconName: String
        let iconColor: Color
        let iconWeight: Font.Weight
        let iconFilled: Bool

        switch visual {
        case .done:
            iconBackground = Color(red: 0.18, green: 0.64, blue: 0.35).opacity(0.18)
            iconName = "checkmark"
            iconColor = Color(red: 0.18, green: 0.64, blue: 0.35)
            iconWeight = .bold
            iconFilled = false
        case .missed:
            iconBackground = Color.red.opacity(0.16)
            iconName = "xmark"
            iconColor = .red
            iconWeight = .bold
            iconFilled = false
        case .today:
            iconBackground = Color(uiColor: .tertiarySystemGroupedBackground)
            iconName = "flame.fill"
            iconColor = .green
            iconWeight = .semibold
            iconFilled = true
        case .future:
            iconBackground = Color(uiColor: .tertiarySystemGroupedBackground)
            iconName = "flame"
            iconColor = .secondary
            iconWeight = .regular
            iconFilled = false
        case .outside:
            iconBackground = Color(uiColor: .tertiarySystemGroupedBackground)
            iconName = "flame"
            iconColor = .secondary.opacity(0.75)
            iconWeight = .regular
            iconFilled = false
        }

        let content = VStack(spacing: 7) {
            Text("\(day)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(visual == .outside ? Color.secondary.opacity(0.7) : Color.secondary)
            ZStack {
                Circle()
                    .fill(iconBackground)
                    .frame(width: 26, height: 26)
                Image(systemName: iconName)
                    .font(.system(size: iconFilled ? 15 : 12, weight: iconWeight))
                    .foregroundStyle(iconColor)
            }
            .opacity(visual == .outside ? 0.88 : 1)
        }
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .center)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(visual == .today ? Color.green.opacity(0.42) : .clear, lineWidth: 1.5)
        )

        if let action, visual != .outside {
            return AnyView(
                Button(action: action) {
                    content
                }
                .buttonStyle(.plain)
            )
        }
        return AnyView(content)
    }

    private var gamesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Игры")
                    .font(.title3.weight(.bold))
                Text("Короткие задания для ума")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, ProfileChrome.exerciseSectionTitleLeading)
            Button {
                showWordsGame = true
            } label: {
                HStack {
                    Image(systemName: "book.fill")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Слова")
                            .font(.body.weight(.semibold))
                        Text("5 букв")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: ProfileChrome.radiusXl, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 16)
    }

    @ViewBuilder
    private func daySheetContent(day: Int) -> some View {
        NavigationStack {
            VStack(spacing: 16) {
                let calId = calendarIdForTitle
                let done = appState.bootstrap?.progress[calId]?.days[String(day)]?.done == true
                Text("День \(day)")
                    .font(.title2.weight(.bold))
                Text(done ? "Тренировка отмечена" : "Не отмечено")
                    .foregroundStyle(.secondary)
                Button {
                    Task { await toggleDay(day: day, markDone: !done) }
                } label: {
                    Text(done ? "Снять отметку" : "Отметить тренировку")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: ProfileChrome.radiusLg, style: .continuous)
                                .fill(Color(red: ProfileChrome.primary.red, green: ProfileChrome.primary.green, blue: ProfileChrome.primary.blue))
                        )
                        .foregroundStyle(.white)
                }
                .disabled(saving)
                if saving { ProgressView() }
                Spacer()
            }
            .padding()
            .navigationTitle("День")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func toggleDay(day: Int, markDone: Bool) async {
        guard let b = appState.bootstrap else { return }
        let calId = calendarIdForTitle
        var merged = b.progress[calId]?.days ?? [:]
        let key = String(day)
        if markDone {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            var s = f.string(from: Date())
            if s.isEmpty { f.formatOptions = [.withInternetDateTime]; s = f.string(from: Date()) }
            merged[key] = ProgressDay(done: true, doneAt: s, proofUrl: merged[key]?.proofUrl, proofType: merged[key]?.proofType, proofCaption: merged[key]?.proofCaption, tasksDone: merged[key]?.tasksDone, completedExerciseAmounts: merged[key]?.completedExerciseAmounts)
        } else {
            merged[key] = nil
        }

        var payload: [String: ProgressDayPayload] = [:]
        for (k, v) in merged {
            guard let d = Int(k), (1 ... 31).contains(d) else { continue }
            if v.done == true || (v.tasksDone?.contains(true) == true) || (v.completedExerciseAmounts?.isEmpty == false) {
                payload[k] = ProgressDayPayload(
                    done: v.done,
                    doneAt: v.doneAt,
                    proofUrl: v.proofUrl,
                    proofType: v.proofType,
                    proofCaption: v.proofCaption,
                    tasksDone: v.tasksDone,
                    completedExerciseAmounts: v.completedExerciseAmounts
                )
            }
        }

        saving = true
        banner = nil
        defer { saving = false }
        do {
            try await APIClient.shared.putProgress(calendarId: calId, days: payload)
            await appState.refreshBootstrap()
            dayDetail = nil
        } catch let e as APIClientError {
            banner = e.message
        } catch {
            banner = error.localizedDescription
        }
    }
}
