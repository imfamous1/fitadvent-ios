import SwiftUI

struct CalendarTabView: View {
    @EnvironmentObject private var appState: AppState
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
                    .padding(.bottom, 16)

                    calendarPicker
                    if let banner {
                        Text(banner)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.bottom, 8)
                    }

                    gamificationCard
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
        let keys = appState.bootstrap.map { Array($0.progress.keys) } ?? []
        if selectedCalendarId.isEmpty {
            selectedCalendarId = MoscowCalendar.defaultCalendarId(keys: keys)
        }
    }

    private var calendarPicker: some View {
        let keys = (appState.bootstrap.map { Array($0.progress.keys) } ?? []).sorted()
        var options = Set(keys)
        options.insert(MoscowCalendar.defaultCalendarId(keys: []))
        options.insert(selectedCalendarId)
        let sorted = options.sorted()

        return VStack(alignment: .leading, spacing: 8) {
            Text("Календарь")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Picker("Календарь", selection: $selectedCalendarId) {
                ForEach(sorted, id: \.self) { id in
                    Text(id).tag(id)
                }
            }
            .pickerStyle(.menu)
            HStack(spacing: 8) {
                Button {
                    selectedCalendarId = MoscowCalendar.shiftMonth(calendarId: calendarIdForTitle, delta: -1)
                } label: {
                    Label("Предыдущий", systemImage: "chevron.left")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(Color(red: ProfileChrome.primary.red, green: ProfileChrome.primary.green, blue: ProfileChrome.primary.blue))

                Button {
                    selectedCalendarId = MoscowCalendar.shiftMonth(calendarId: calendarIdForTitle, delta: 1)
                } label: {
                    Label("Следующий", systemImage: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(Color(red: ProfileChrome.primary.red, green: ProfileChrome.primary.green, blue: ProfileChrome.primary.blue))

                Spacer()
                Button("Сегодня") {
                    selectedCalendarId = MoscowCalendar.defaultCalendarId(keys: [])
                }
                .buttonStyle(.bordered)
                .disabled(selectedCalendarId == MoscowCalendar.defaultCalendarId(keys: []))
            }
        }
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private var gamificationCard: some View {
        if let b = appState.bootstrap {
            let doneThisMonth = daysDoneCount(for: selectedCalendarId, in: b)
            VStack(alignment: .leading, spacing: 8) {
                Text("Прогресс")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Уровень \(b.gamification.level ?? 1)")
                            .font(.title3.weight(.bold))
                        Text("Тренировок всего: \(b.gamification.totalWorkouts ?? 0)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("В этом месяце: \(doneThisMonth)")
                            .font(.subheadline)
                            .foregroundStyle(Color(red: ProfileChrome.accentBlue.red, green: ProfileChrome.accentBlue.green, blue: ProfileChrome.accentBlue.blue))
                    }
                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                )
            }
            .padding(.bottom, 16)
        }
    }

    private func daysDoneCount(for calId: String, in b: BootstrapResponse) -> Int {
        guard let days = b.progress[calId]?.days else { return 0 }
        return days.values.filter { $0.done == true }.count
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

        let rows = appState.bootstrap?.progress[calId]?.days ?? [:]

        return VStack(alignment: .leading, spacing: 10) {
            Text("Месяц")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"], id: \.self) { w in
                    Text(w)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                ForEach(0 ..< leading, id: \.self) { _ in
                    Color.clear.frame(width: 36, height: 36)
                }
                ForEach(1 ... dim, id: \.self) { day in
                    let done = rows[String(day)]?.done == true
                    Button {
                        dayDetail = DayDetail(day: day)
                    } label: {
                        Text("\(day)")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(done
                                        ? Color(red: ProfileChrome.primary.red, green: ProfileChrome.primary.green, blue: ProfileChrome.primary.blue).opacity(0.9)
                                        : Color(uiColor: .tertiarySystemGroupedBackground))
                            )
                            .foregroundStyle(done ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.bottom, 20)
    }

    private var gamesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Игры")
                .font(.title3.weight(.bold))
            Text("Короткие задания для ума")
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                )
            }
            .buttonStyle(.plain)
        }
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
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
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
