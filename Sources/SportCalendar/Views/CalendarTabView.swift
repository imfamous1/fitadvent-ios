import PhotosUI
import SwiftUI

struct CalendarTabView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @State private var showWordsGame = false
    @State private var selectedCalendarId: String = ""
    @State private var dayDetail: DayDetail?
    @State private var saving = false
    @State private var banner: String?
    @State private var dayProofPickerItem: PhotosPickerItem?
    @State private var dayPickedProofData: Data?
    @State private var dayPickedProofPreview: Image?
    @State private var dayRemoveProof = false
    @State private var dayProofCaption = ""
    @State private var dayOpenTemplate = true
    @State private var dayOpenIndividual = false
    @State private var dayTemplateChecks: [Bool] = []
    @State private var dayIndividualChecks: [Bool] = []
    @State private var daySelectedPlanMode: DayPlanMode = .template

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
                    .presentationDetents([.medium, .large])
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
            iconName = "checkmark.circle.fill"
            iconColor = Color(red: 0.18, green: 0.64, blue: 0.35)
            iconWeight = .semibold
            iconFilled = false
        case .missed:
            iconBackground = Color.red.opacity(0.16)
            iconName = "xmark.circle.fill"
            iconColor = .red
            iconWeight = .semibold
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
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                let calId = calendarIdForTitle
                let dayEntry = appState.bootstrap?.progress[calId]?.days[String(day)]
                let done = dayEntry?.done == true
                let template = planRows(day: day, calendarId: calId, mode: .template)
                let individual = planRows(day: day, calendarId: calId, mode: .individual)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(daySheetTitle(day: day, calendarId: calId))
                            .font(.title3.weight(.bold))
                        Text("Задания рассчитаны на весь день. Не обязательно выполнять всё сразу — достаточно отметить хотя бы одно упражнение.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.leading, ProfileChrome.exerciseSectionTitleLeading)

                    dayPlanCard(
                        template: template,
                        individual: individual
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Отчёт  необязательно")
                            .font(.subheadline.weight(.semibold))
                            .padding(.leading, ProfileChrome.exerciseSectionTitleLeading)
                        VStack(alignment: .leading, spacing: 10) {
                            PhotosPicker(selection: $dayProofPickerItem, matching: .images) {
                                HStack(spacing: 10) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                    Text((dayPickedProofData != nil || dayEntry?.proofUrl?.isEmpty == false) ? "Заменить фото" : "Загрузите фото")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 16)
                                .frame(minHeight: ProfileChrome.profileBarFixedHeight, maxHeight: ProfileChrome.profileBarFixedHeight)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                                )
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)

                            if let picked = dayPickedProofPreview {
                                picked
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 160)
                                    .frame(maxWidth: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: ProfileChrome.radiusLg, style: .continuous))
                            } else if let s = dayEntry?.proofUrl, let u = URL(string: s) {
                                AsyncImage(url: u) { phase in
                                    switch phase {
                                    case .success(let img):
                                        img.resizable().scaledToFill()
                                    case .failure:
                                        Color(uiColor: .tertiarySystemGroupedBackground)
                                    case .empty:
                                        ProgressView()
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                            .background(Color(uiColor: .tertiarySystemGroupedBackground))
                                    @unknown default:
                                        Color(uiColor: .tertiarySystemGroupedBackground)
                                    }
                                }
                                .frame(height: 160)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: ProfileChrome.radiusLg, style: .continuous))
                            }

                            if dayPickedProofData != nil || dayEntry?.proofUrl?.isEmpty == false {
                                Button {
                                    dayPickedProofData = nil
                                    dayPickedProofPreview = nil
                                    dayRemoveProof = true
                                } label: {
                                    Text("Удалить отчёт")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: ProfileChrome.radiusXl, style: .continuous)
                                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                        )
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Комментарий")
                            .font(.subheadline.weight(.semibold))
                            .padding(.leading, ProfileChrome.exerciseSectionTitleLeading)
                        TextField("Подпись к фото", text: $dayProofCaption)
                            .textInputAutocapitalization(.sentences)
                            .padding(.horizontal, 16)
                            .frame(minHeight: ProfileChrome.profileBarFixedHeight, maxHeight: ProfileChrome.profileBarFixedHeight)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                            )
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: ProfileChrome.radiusXl, style: .continuous)
                                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                        )
                    }

                    Button {
                        Task {
                            await saveDay(
                                day: day,
                                markDone: !done,
                                pickedProofData: dayPickedProofData,
                                removeProof: dayRemoveProof,
                                tasksDone: daySelectedPlanMode == .template ? dayTemplateChecks : dayIndividualChecks
                            )
                        }
                    } label: {
                        Label(done ? "Снять отметку" : "Выполнено", systemImage: "checkmark.circle.fill")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: ProfileChrome.profileBarFixedHeight)
                            .background(
                                Capsule()
                                    .fill(Color(
                                        red: ProfileChrome.accentBlue.red,
                                        green: ProfileChrome.accentBlue.green,
                                        blue: ProfileChrome.accentBlue.blue
                                    ))
                            )
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(saving)
                    if saving { ProgressView().frame(maxWidth: .infinity) }
                }
                .padding(16)
            }
            .navigationTitle("День")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                let dayEntry = appState.bootstrap?.progress[calendarIdForTitle]?.days[String(day)]
                let template = planRows(day: day, calendarId: calendarIdForTitle, mode: .template)
                let individual = planRows(day: day, calendarId: calendarIdForTitle, mode: .individual)
                dayProofCaption = dayEntry?.proofCaption ?? ""
                dayRemoveProof = false
                dayPickedProofData = nil
                dayPickedProofPreview = nil
                hydrateDaySheetState(
                    dayEntry: dayEntry,
                    templateCount: template.items.count,
                    individualCount: individual.items.count
                )
            }
            .onChange(of: dayProofPickerItem) { _, newItem in
                Task { await loadPickedProof(item: newItem) }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dayDetail = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Закрыть")
                }
            }
        }
    }

    private func saveDay(day: Int, markDone: Bool, pickedProofData: Data?, removeProof: Bool, tasksDone: [Bool]) async {
        guard let b = appState.bootstrap else { return }
        let calId = calendarIdForTitle
        var merged = b.progress[calId]?.days ?? [:]
        let key = String(day)
        if markDone {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            var s = f.string(from: Date())
            if s.isEmpty { f.formatOptions = [.withInternetDateTime]; s = f.string(from: Date()) }
            var proofUrl = merged[key]?.proofUrl
            var proofType = merged[key]?.proofType
            var proofCaption: String? = dayProofCaption.trimmingCharacters(in: .whitespacesAndNewlines)
            if proofCaption?.isEmpty == true { proofCaption = nil }

            if removeProof {
                proofUrl = nil
                proofType = nil
                proofCaption = nil
            } else if let pickedProofData {
                do {
                    let uploaded = try await APIClient.shared.uploadMedia(
                        imageData: pickedProofData,
                        calendarId: calId,
                        day: day,
                        filename: "proof-\(calId)-\(day).jpg"
                    )
                    if let dict = uploaded.value as? [String: Any] {
                        proofUrl = dict["url"] as? String
                        proofType = dict["proofType"] as? String ?? "image"
                    }
                } catch let e as APIClientError {
                    banner = e.message
                    return
                } catch {
                    banner = error.localizedDescription
                    return
                }
            }
            if proofUrl == nil {
                proofCaption = nil
            }
            merged[key] = ProgressDay(done: true, doneAt: s, proofUrl: proofUrl, proofType: proofType, proofCaption: proofCaption, tasksDone: tasksDone.isEmpty ? nil : tasksDone, completedExerciseAmounts: merged[key]?.completedExerciseAmounts)
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
            dayProofPickerItem = nil
            dayPickedProofData = nil
            dayPickedProofPreview = nil
            dayRemoveProof = false
            dayProofCaption = ""
        } catch let e as APIClientError {
            banner = e.message
        } catch {
            banner = error.localizedDescription
        }
    }

    private func loadPickedProof(item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            dayPickedProofData = data
            if let ui = UIImage(data: data) {
                dayPickedProofPreview = Image(uiImage: ui)
            } else {
                dayPickedProofPreview = nil
            }
            dayRemoveProof = false
        } catch {
            banner = error.localizedDescription
        }
    }

    private func daySheetTitle(day: Int, calendarId: String) -> String {
        let parts = calendarId.split(separator: "-")
        guard parts.count >= 2, let year = Int(parts[0]), let month = Int(parts[1]) else { return "День \(day)" }
        let names = ["января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября", "ноября", "декабря"]
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Moscow") ?? .current
        let date = cal.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
        let wd = cal.component(.weekday, from: date)
        let weekdays = ["воскресенье", "понедельник", "вторник", "среда", "четверг", "пятница", "суббота"]
        return "\(day) \(names[max(0, min(11, month - 1))]), \(weekdays[max(1, min(7, wd)) - 1])"
    }

    @ViewBuilder
    private func dayPlanCard(template: DayPlanPayload, individual: DayPlanPayload) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            dayPlanSection(
                title: "Общий",
                icon: "calendar",
                mode: .template,
                rows: template.items,
                checks: $dayTemplateChecks,
                isOpen: $dayOpenTemplate,
                gate: template.gate
            )
            Divider().padding(.leading, ProfileChrome.exerciseRowPaddingH)
            dayPlanSection(
                title: "Индивидуальный",
                icon: "person",
                mode: .individual,
                rows: individual.items,
                checks: $dayIndividualChecks,
                isOpen: $dayOpenIndividual,
                gate: individual.gate
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: ProfileChrome.radiusXl, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }

    private func dayPlanSection(
        title: String,
        icon: String,
        mode: DayPlanMode,
        rows: [DayPlanItem],
        checks: Binding<[Bool]>,
        isOpen: Binding<Bool>,
        gate: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.88, blendDuration: 0.12)) {
                    isOpen.wrappedValue.toggle()
                    if isOpen.wrappedValue {
                        daySelectedPlanMode = mode
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .foregroundStyle(.secondary)
                        .frame(width: ProfileChrome.exerciseRowIconColumnWidth, alignment: .center)
                    Text(title).font(.headline)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isOpen.wrappedValue ? 180 : 0))
                }
            }
            .buttonStyle(.plain)

            if isOpen.wrappedValue {
                if let gate {
                    Text(gate)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                        .padding(.leading, ProfileChrome.exerciseSectionTitleLeading)
                } else if rows.isEmpty {
                    Text("В этот день нет упражнений.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                        .padding(.leading, ProfileChrome.exerciseSectionTitleLeading)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                            if idx > 0 { Divider().padding(.leading, ProfileChrome.exercisePlanDividerLeading) }
                            Button {
                                guard checks.wrappedValue.indices.contains(idx) else { return }
                                checks.wrappedValue[idx].toggle()
                                daySelectedPlanMode = mode
                            } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: checks.wrappedValue.indices.contains(idx) && checks.wrappedValue[idx] ? "checkmark.square.fill" : "square")
                                        .font(.title3)
                                        .foregroundStyle(checks.wrappedValue.indices.contains(idx) && checks.wrappedValue[idx] ? Color.accentColor : .secondary)
                                        .padding(.top, 2)
                                        .frame(width: ProfileChrome.exerciseRowIconColumnWidth, alignment: .center)
                                    Text(row.title)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)
                                    Spacer(minLength: 8)
                                    Text(row.amount)
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                        .frame(minWidth: 44, alignment: .trailing)
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, ProfileChrome.exerciseRowPaddingH)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 2)
                }
            }
        }
        .contentShape(Rectangle())
        .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)), removal: .opacity))
        .animation(.spring(response: 0.32, dampingFraction: 0.88, blendDuration: 0.12), value: isOpen.wrappedValue)
    }

    private enum DayPlanMode { case template, individual }

    private struct DayPlanItem: Identifiable {
        var id: String
        var title: String
        var amount: String
    }

    private struct DayPlanPayload {
        var items: [DayPlanItem]
        var gate: String?
    }

    private func planRows(day: Int, calendarId: String, mode: DayPlanMode) -> DayPlanPayload {
        guard let b = appState.bootstrap else { return DayPlanPayload(items: [], gate: nil) }
        let vote = b.programVotes[calendarId]
        let isIndividual = isIndividualVote(vote)
        if mode == .individual {
            if !vipActive(b.user.profile) {
                return DayPlanPayload(items: [], gate: "Индивидуальный план доступен в Премиуме.")
            }
            if !isIndividual {
                return DayPlanPayload(items: [], gate: "Создайте индивидуальную программу в профиле.")
            }
        }
        let effectiveVote: ProgramVoteRecord? = {
            switch mode {
            case .template:
                if isIndividual {
                    return ProgramVoteRecord(exerciseIds: ["squat", "crunch", "plank", "pushup"], level: "intermediate", updatedAt: vote?.updatedAt ?? "", startAmounts: [:], dowOverrides: nil, customExercises: nil)
                }
                return vote ?? ProgramVoteRecord(exerciseIds: ["squat", "crunch", "plank", "pushup"], level: "intermediate", updatedAt: "", startAmounts: [:], dowOverrides: nil, customExercises: nil)
            case .individual:
                return vote
            }
        }()
        guard let effectiveVote else { return DayPlanPayload(items: [], gate: nil) }
        let weekday = isoWeekday(day: day, calendarId: calendarId)
        let baseIds = effectiveVote.exerciseIds
        let ids: [String]
        if let dow = effectiveVote.dowOverrides, let dayIds = dow[weekday] {
            let allowed = Set(baseIds)
            ids = dayIds.filter { allowed.contains($0) }
        } else {
            ids = baseIds
        }
        let dim = max(1, MoscowCalendar.daysInMonth(calendarId: calendarId))
        let lv = effectiveVote.level
        let ratio: Double = lv == "advanced" ? 2.75 : (lv == "beginner" ? 1.18 : 1.85)
        let rows = ids.compactMap { id -> DayPlanItem? in
            if id.hasPrefix("u_") {
                let custom = effectiveVote.customExercises?[id] ?? b.customExerciseLibrary[id]
                guard let custom else { return nil }
                let w1 = Double(effectiveVote.startAmounts?[id] ?? 1)
                let amount = max(1, Int(round(interpolateAmount(day: day, daysInMonth: dim, w1: w1, w4: w1 * ratio))))
                return DayPlanItem(id: id, title: custom.label, amount: formatAmount(amount: amount, unit: custom.unit))
            }
            guard let ex = baseExerciseById[id] else { return nil }
            let w1 = Double(baseValue(level: lv, ex: ex))
            let amount = max(1, Int(round(interpolateAmount(day: day, daysInMonth: dim, w1: w1, w4: w1 * ratio))))
            return DayPlanItem(id: id, title: ex.label, amount: formatAmount(amount: amount, unit: ex.unit))
        }
        return DayPlanPayload(items: rows, gate: nil)
    }

    private func hydrateDaySheetState(dayEntry: ProgressDay?, templateCount: Int, individualCount: Int) {
        let saved = dayEntry?.tasksDone ?? []
        dayTemplateChecks = Array(repeating: false, count: templateCount)
        dayIndividualChecks = Array(repeating: false, count: individualCount)
        for i in 0 ..< min(saved.count, templateCount) {
            dayTemplateChecks[i] = saved[i]
        }
        for i in 0 ..< min(saved.count, individualCount) {
            dayIndividualChecks[i] = saved[i]
        }
        dayOpenTemplate = true
        dayOpenIndividual = false
        daySelectedPlanMode = .template
    }

    private func isIndividualVote(_ vote: ProgramVoteRecord?) -> Bool {
        guard let ids = vote?.exerciseIds, !ids.isEmpty else { return false }
        return ids.allSatisfy { $0.hasPrefix("u_") }
    }

    private func isoWeekday(day: Int, calendarId: String) -> String {
        let parts = calendarId.split(separator: "-")
        guard parts.count >= 2, let y = Int(parts[0]), let m = Int(parts[1]) else { return "1" }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Moscow") ?? .current
        let wd = cal.component(.weekday, from: cal.date(from: DateComponents(year: y, month: m, day: day)) ?? Date())
        return String(wd == 1 ? 7 : wd - 1)
    }

    private struct BaseExercise {
        var label: String
        var unit: String
        var beginner: Int
        var intermediate: Int
        var advanced: Int
    }

    private var baseExerciseById: [String: BaseExercise] {
        [
            "pushup": .init(label: "Отжимания", unit: "reps", beginner: 8, intermediate: 16, advanced: 28),
            "pullup": .init(label: "Подтягивания", unit: "reps", beginner: 4, intermediate: 8, advanced: 12),
            "squat": .init(label: "Приседания", unit: "reps", beginner: 15, intermediate: 30, advanced: 45),
            "plank": .init(label: "Планка", unit: "sec", beginner: 30, intermediate: 50, advanced: 70),
            "crunch": .init(label: "Скручивания", unit: "reps", beginner: 10, intermediate: 16, advanced: 24),
            "lunge": .init(label: "Выпады", unit: "reps", beginner: 8, intermediate: 14, advanced: 20),
            "glute_bridge": .init(label: "Ягодичный мостик", unit: "reps", beginner: 12, intermediate: 18, advanced: 26),
            "side_plank": .init(label: "Боковая планка", unit: "sec", beginner: 20, intermediate: 35, advanced: 50),
            "burpee": .init(label: "Берпи", unit: "reps", beginner: 5, intermediate: 10, advanced: 15),
            "leg_raise": .init(label: "Подъём ног лёжа", unit: "reps", beginner: 8, intermediate: 14, advanced: 20),
            "dip_bars": .init(label: "Отжимания на брусьях", unit: "reps", beginner: 4, intermediate: 10, advanced: 16),
            "run": .init(label: "Бег", unit: "min", beginner: 10, intermediate: 20, advanced: 35),
        ]
    }

    private func baseValue(level: String, ex: BaseExercise) -> Int {
        switch level {
        case "beginner": return ex.beginner
        case "advanced": return ex.advanced
        default: return ex.intermediate
        }
    }

    private func interpolateAmount(day: Int, daysInMonth: Int, w1: Double, w4: Double) -> Double {
        let dim = max(1, daysInMonth)
        let t = dim <= 1 ? 0 : Double(day - 1) / Double(dim - 1)
        return w1 + (w4 - w1) * t
    }

    private func formatAmount(amount: Int, unit: String) -> String {
        switch unit {
        case "sec": return "\(amount) с"
        case "min": return "\(amount) мин"
        case "km":
            let km = Double(amount) / 10.0
            return String(format: "%.1f км", km)
        default: return "\(amount)"
        }
    }
}
