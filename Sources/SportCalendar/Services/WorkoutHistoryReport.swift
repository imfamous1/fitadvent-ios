import Foundation

// MARK: - Публичные модели (как `buildWorkoutHistoryReport` + `buildWorkoutStatsModalBody` на вебе)

struct WorkoutHistoryReport: Sendable {
    /// Как `countTotalWorkouts` в `progress.js`: день засчитан при `done`, частичных задачах или объёмах.
    var totalWorkoutsAllCalendars: Int
    var sections: [WorkoutHistoryMonthSection]
}

struct WorkoutHistoryMonthSection: Identifiable, Sendable {
    var id: String { calendarId }
    var calendarId: String
    var sortKey: Int
    var title: String
    var workouts: Int
    var exerciseRows: [WorkoutHistoryExerciseRow]
}

struct WorkoutHistoryExerciseRow: Identifiable, Sendable {
    var id: String { exerciseKey }
    var exerciseKey: String
    var label: String
    var valueDisplay: String
}

enum WorkoutHistoryReportBuilder {
    private static let xpPerWorkout = 15
    private static let xpScale = 50.0
    private static let stretchMinutes = [10, 15, 20, 25]

    private static let defaultExerciseIds = ["squat", "crunch", "plank", "pushup"]
    private static let monthEndRatio: [String: Double] = [
        "beginner": 1.18, "intermediate": 1.85, "advanced": 2.75,
    ]
    private static let amountCaps: [String: Double] = [
        "pushup": 100, "pullup": 35, "squat": 120, "plank": 180, "crunch": 60,
        "lunge": 50, "glute_bridge": 60, "side_plank": 120, "burpee": 40,
        "leg_raise": 40, "dip_bars": 35, "run": 90,
    ]
    private static let customCaps: [String: Double] = [
        "reps": 1000, "sec": 10000, "min": 720, "km": 100,
    ]

    private struct CatalogExercise: Sendable {
        var id: String
        var label: String
        var unit: String
        var baseBeginner: Double
        var baseIntermediate: Double
        var baseAdvanced: Double
    }

    private static let catalog: [CatalogExercise] = [
        CatalogExercise(id: "pushup", label: "Отжимания", unit: "reps", baseBeginner: 8, baseIntermediate: 16, baseAdvanced: 28),
        CatalogExercise(id: "pullup", label: "Подтягивания", unit: "reps", baseBeginner: 4, baseIntermediate: 8, baseAdvanced: 12),
        CatalogExercise(id: "squat", label: "Приседания", unit: "reps", baseBeginner: 15, baseIntermediate: 30, baseAdvanced: 45),
        CatalogExercise(id: "plank", label: "Планка", unit: "sec", baseBeginner: 30, baseIntermediate: 50, baseAdvanced: 70),
        CatalogExercise(id: "crunch", label: "Скручивания", unit: "reps", baseBeginner: 10, baseIntermediate: 16, baseAdvanced: 24),
        CatalogExercise(id: "lunge", label: "Выпады", unit: "reps", baseBeginner: 8, baseIntermediate: 14, baseAdvanced: 20),
        CatalogExercise(id: "glute_bridge", label: "Ягодичный мостик", unit: "reps", baseBeginner: 12, baseIntermediate: 18, baseAdvanced: 26),
        CatalogExercise(id: "side_plank", label: "Боковая планка", unit: "sec", baseBeginner: 20, baseIntermediate: 35, baseAdvanced: 50),
        CatalogExercise(id: "burpee", label: "Берпи", unit: "reps", baseBeginner: 5, baseIntermediate: 10, baseAdvanced: 15),
        CatalogExercise(id: "leg_raise", label: "Подъём ног лёжа", unit: "reps", baseBeginner: 8, baseIntermediate: 14, baseAdvanced: 20),
        CatalogExercise(id: "dip_bars", label: "Отжимания на брусьях", unit: "reps", baseBeginner: 4, baseIntermediate: 10, baseAdvanced: 16),
        CatalogExercise(id: "run", label: "Бег", unit: "min", baseBeginner: 10, baseIntermediate: 20, baseAdvanced: 35),
    ]

    private static let catalogOrder: [String] = catalog.map(\.id)
    private static let legacyOrder = ["squats", "abs", "plank", "pushups"]
    private static let legacyLabels: [String: String] = [
        "squats": "Приседания", "abs": "Пресс", "plank": "Планка", "pushups": "Отжимания",
    ]

    // MARK: - API

    static func build(from bootstrap: BootstrapResponse) -> WorkoutHistoryReport {
        let totalAll = countTotalWorkoutsLikeWeb(progress: bootstrap.progress)
        var sections: [WorkoutHistoryMonthSection] = []

        for calendarId in bootstrap.progress.keys {
            guard let prog = bootstrap.progress[calendarId] else { continue }
            let days = prog.days
            guard let cal = makeGeneratedCalendar(calendarId: calendarId) else { continue }
            let displayVotes = programVotesForWorkoutDisplay(bootstrap.programVotes, calendar: cal)
            let progression = progressionCtx(gamification: bootstrap.gamification, daysInMonth: cal.daysInMonth)

            var workouts = 0
            for d in 1 ... cal.daysInMonth {
                let st = days[String(d)] ?? ProgressDay()
                if dayCountsAsWorkoutForDisplayedProgram(cal: cal, day: d, st: st, displayVotes: displayVotes, progression: progression) {
                    workouts += 1
                }
            }
            if workouts == 0 { continue }

            let totals = sumMonthExercises(
                cal: cal, progressDays: days, displayVotes: displayVotes, progression: progression
            )
            let keys = monthStatsDisplayKeys(totals: totals)
            let vk = voteKey(calendar: cal)
            let voteSlice = vk.flatMap { displayVotes[$0] }

            let rows: [WorkoutHistoryExerciseRow] = keys.map { k in
                WorkoutHistoryExerciseRow(
                    exerciseKey: k,
                    label: exerciseKeyLabel(k, vote: voteSlice),
                    valueDisplay: formatExerciseStatValue(k, totals[k] ?? 0, vote: voteSlice)
                )
            }

            sections.append(
                WorkoutHistoryMonthSection(
                    calendarId: calendarId,
                    sortKey: cal.year * 12 + cal.month,
                    title: cal.title,
                    workouts: workouts,
                    exerciseRows: rows
                )
            )
        }

        sections.sort { $0.sortKey > $1.sortKey }
        return WorkoutHistoryReport(totalWorkoutsAllCalendars: totalAll, sections: sections)
    }

    // MARK: - Прогресс / тренировки

    static func countTotalWorkoutsLikeWeb(progress: [String: ProgressCalendar]) -> Int {
        var n = 0
        for cal in progress.values {
            for d in cal.days.values where dayCountsAsWorkout(d) {
                n += 1
            }
        }
        return n
    }

    private static func dayCountsAsWorkout(_ d: ProgressDay) -> Bool {
        if d.done == true { return true }
        if d.tasksDone?.contains(true) == true { return true }
        if let snap = d.completedExerciseAmounts {
            for v in snap.values {
                if v.isFinite, v > 0 { return true }
            }
        }
        return false
    }

    // MARK: - Календарь месяца (как `calendarMonthGenerator.js`)

    private struct GenCal: Sendable {
        var id: String
        var title: String
        var year: Int
        var month: Int
        var daysInMonth: Int
        var days: [GenDay]
    }

    private struct GenDay: Sendable {
        var day: Int
        var type: String
        var blocks: [ProgBlock]
    }

    private struct ProgBlock: Sendable {
        var exerciseId: String?
        var amount: Double?
        var unit: String?
        var text: String?
    }

    private static func makeGeneratedCalendar(calendarId: String) -> GenCal? {
        guard let parsed = parseYm(calendarId) else { return nil }
        let y = parsed.year
        let m = parsed.month
        let dim = daysInMonth(year: y, month: m)
        var days: [GenDay] = []
        for d in 1 ... dim {
            if d % 7 == 0 {
                let si = min(d / 7 - 1, stretchMinutes.count - 1)
                let minVal = stretchMinutes[si]
                days.append(GenDay(day: d, type: "stretch", blocks: [ProgBlock(exerciseId: nil, amount: nil, unit: nil, text: "\(minVal) минут растяжки")]))
            } else {
                days.append(GenDay(day: d, type: "workout", blocks: []))
            }
        }
        let title = MoscowCalendar.monthTitle(calendarId: String(format: "%04d-%02d", y, m))
        return GenCal(id: String(format: "%04d-%02d", y, m), title: title, year: y, month: m, daysInMonth: dim, days: days)
    }

    private static func parseYm(_ calendarId: String) -> (year: Int, month: Int)? {
        let parts = calendarId.split(separator: "-")
        guard parts.count == 2,
              let y = Int(parts[0]), let mo = Int(parts[1]),
              calendarId.range(of: #"^\d{4}-\d{2}$"#, options: .regularExpression) != nil,
              mo >= 1, mo <= 12 else { return nil }
        return (y, mo)
    }

    private static func daysInMonth(year: Int, month: Int) -> Int {
        var c = DateComponents()
        c.year = year
        c.month = month + 1
        c.day = 0
        let cal = Calendar(identifier: .gregorian)
        guard let date = cal.date(from: c) else { return 30 }
        return cal.range(of: .day, in: .month, for: date)?.count ?? 30
    }

    private static func dayByNumber(cal: GenCal, _ n: Int) -> GenDay? {
        cal.days.first { $0.day == n }
    }

    // MARK: - Голосование за программу

    private static func voteKey(calendar: GenCal) -> String? {
        String(format: "%04d-%02d", calendar.year, calendar.month)
    }

    /// iOS не хранит вкладку «общий / индив.»; как на вебе по умолчанию — для чисто индивидуальной программы показываем общий шаблон.
    private static func programVotesForWorkoutDisplay(
        _ base: [String: ProgramVoteRecord],
        calendar: GenCal
    ) -> [String: ProgramVoteRecord] {
        var out = base
        guard let vk = voteKey(calendar: calendar), let vote = base[vk] else { return out }
        if isIndividualProgramVoteSlice(vote) {
            out[vk] = defaultTemplateRecord()
        }
        return out
    }

    private static func defaultTemplateRecord() -> ProgramVoteRecord {
        ProgramVoteRecord(
            exerciseIds: defaultExerciseIds,
            level: "intermediate",
            updatedAt: "",
            startAmounts: [:],
            dowOverrides: nil,
            customExercises: nil
        )
    }

    private static func isCustomProgramVoteId(_ id: String) -> Bool {
        id.range(of: #"^u_[a-z0-9_]{1,32}$"#, options: .regularExpression) != nil
    }

    private static func isIndividualProgramVoteSlice(_ vote: ProgramVoteRecord) -> Bool {
        !vote.exerciseIds.isEmpty && vote.exerciseIds.allSatisfy { isCustomProgramVoteId($0) }
    }

    private static func monthProgramExerciseKeys(calendar: GenCal, displayVotes: [String: ProgramVoteRecord]) -> [String] {
        let vk = voteKey(calendar: calendar)
        if let k = vk, let vote = displayVotes[k], !vote.exerciseIds.isEmpty {
            return sortStatKeys(Array(Set(vote.exerciseIds.map { String($0) })))
        }
        return sortStatKeys(defaultExerciseIds)
    }

    private static func sortStatKeys(_ keys: [String]) -> [String] {
        func idx(_ k: String) -> Int {
            if let i = catalogOrder.firstIndex(of: k) { return i }
            if let j = legacyOrder.firstIndex(of: k) { return 200 + j }
            return 500
        }
        return keys.sorted { idx($0) < idx($1) }
    }

    private static func monthStatsDisplayKeys(totals: [String: Double]) -> [String] {
        let positive = totals.filter { $0.value.isFinite && $0.value > 0 }.map(\.key)
        return sortStatKeys(positive)
    }

    // MARK: - Москва ISO день недели

    private static func moscowIsoWeekday(year: Int, month: Int, day: Int) -> Int {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        var comp = DateComponents()
        comp.year = year
        comp.month = month
        comp.day = day
        comp.hour = 9
        comp.minute = 0
        comp.second = 0
        guard let date = c.date(from: comp) else { return 1 }
        let js = c.component(.weekday, from: date)
        return js == 1 ? 7 : js - 1
    }

    private static func effectiveExerciseIdsForIsoDow(vote: ProgramVoteRecord, isoDow: Int) -> [String] {
        let base = vote.exerciseIds.map { String($0) }
        guard !base.isEmpty else { return base }
        guard let o = vote.dowOverrides, !o.isEmpty else { return base }
        let key = String(isoDow)
        guard let sub = o[key] else { return base }
        let pool = Set(base)
        return sub.map { String($0) }.filter { pool.contains($0) }
    }

    // MARK: - Прогрессия объёмов

    private static func progressionCtx(gamification: Gamification, daysInMonth: Int) -> Int {
        let baseXp = Double(
            gamification.xpTotal ?? ((gamification.totalWorkouts ?? 0) * xpPerWorkout + (gamification.bonusXp ?? 0))
        )
        let dim = max(1, daysInMonth)
        let projected = baseXp + Double(dim * xpPerWorkout)
        return levelFromTotalXp(projected)
    }

    private static func levelFromTotalXp(_ xpTotal: Double) -> Int {
        let x = max(0, xpTotal)
        let lvl = Int(floor(sqrt(x / xpScale))) + 1
        return max(1, lvl)
    }

    private static func xpLevelMult(_ L: Int) -> Double {
        min(0.18, 0.01 * Double(max(1, L) - 1)) + 1
    }

    private static func xpCapMult(_ L: Int) -> Double {
        min(0.1, 0.005 * Double(max(1, L) - 1)) + 1
    }

    private static func programVoteMonthEndRatio(_ level: String) -> Double {
        monthEndRatio[level] ?? monthEndRatio["intermediate"]!
    }

    private static func catalogExercise(_ id: String) -> CatalogExercise? {
        catalog.first { $0.id == id }
    }

    private static func resolveCatalogW1W4(exerciseId: String, programLevel: String, userLevel: Int) -> (w1: Double, w4: Double, unit: String, label: String)? {
        guard let ex = catalogExercise(exerciseId) else { return nil }
        let base: Double = {
            switch programLevel {
            case "beginner": return ex.baseBeginner
            case "advanced": return ex.baseAdvanced
            default: return ex.baseIntermediate
            }
        }()
        let capBase = amountCaps[exerciseId] ?? (ex.unit == "sec" ? 300 : ex.unit == "min" ? 120 : 150)
        let cap = max(1, (capBase * xpCapMult(userLevel)).rounded())
        let ratio = programVoteMonthEndRatio(programLevel)
        let xpMult = xpLevelMult(userLevel)

        let catalogRounded: Double = {
            if ex.unit == "sec" || ex.unit == "min" { return base.rounded() }
            if ex.unit == "km" { return max(0.1, (base * 10).rounded() / 10) }
            return max(1, base.rounded())
        }()

        var w1 = max(1, (catalogRounded * xpMult).rounded())
        w1 = min(w1, cap)
        var w4 = (w1 * ratio).rounded()
        w4 = min(max(w4, w1), cap)
        if ex.unit == "sec" || ex.unit == "min" {
            w1 = max(1, w1.rounded())
            w4 = max(1, w4.rounded())
        } else if ex.unit == "km" {
            w1 = max(0.1, (w1 * 10).rounded() / 10)
            w4 = max(w1, (w4 * 10).rounded() / 10)
        } else {
            w1 = max(1, w1.rounded())
            w4 = max(w1, w4.rounded())
        }
        return (w1, w4, ex.unit, ex.label)
    }

    private static func resolveCustomW1W4(exerciseId: String, vote: ProgramVoteRecord, programLevel: String, userLevel: Int) -> (w1: Double, w4: Double, unit: String, label: String)? {
        guard let def = vote.customExercises?[exerciseId], !def.label.isEmpty, !def.unit.isEmpty else { return nil }
        let ratioRaw = def.monthEndMultiplier
        let ratio: Double = {
            if let r = ratioRaw, r.isFinite { return min(3.5, max(1, r)) }
            return programVoteMonthEndRatio(programLevel)
        }()
        let individual = isIndividualProgramVoteSlice(vote)
        let userLevelN = individual ? 1 : max(1, userLevel)
        let unit = def.unit
        guard customCaps[unit] != nil else { return nil }
        let capBase = customCaps[unit]!
        let cap = max(1, (capBase * xpCapMult(userLevelN)).rounded())
        let xpM = xpLevelMult(userLevelN)

        let catalogRounded: Double = {
            if let b = def.base {
                switch programLevel {
                case "beginner": return b.beginner ?? 0
                case "advanced": return b.advanced ?? 0
                default: return b.intermediate ?? 0
                }
            }
            if let s = vote.startAmounts?[exerciseId] { return Double(s) }
            return 0
        }()
        guard catalogRounded > 0 else { return nil }
        let cr = max(1, catalogRounded)

        var w1 = max(1, (cr * xpM).rounded())
        w1 = min(w1, cap)
        var w4 = (w1 * ratio).rounded()
        w4 = min(max(w4, w1), cap)
        if unit == "sec" || unit == "min" {
            w1 = max(1, w1.rounded())
            w4 = max(1, w4.rounded())
        } else if unit == "km" {
            w1 = max(1, (w1 * 10).rounded() / 10)
            w4 = max(w1, (w4 * 10).rounded() / 10)
        } else {
            w1 = max(1, w1.rounded())
            w4 = max(w1, w4.rounded())
        }
        return (w1, w4, unit, def.label)
    }

    private static func resolveProgramExerciseW1W4(exerciseId: String, vote: ProgramVoteRecord, programLevel: String, userLevel: Int) -> (w1: Double, w4: Double, unit: String, label: String)? {
        if isCustomProgramVoteId(exerciseId) {
            return resolveCustomW1W4(exerciseId: exerciseId, vote: vote, programLevel: programLevel, userLevel: userLevel)
        }
        return resolveCatalogW1W4(exerciseId: exerciseId, programLevel: programLevel, userLevel: userLevel)
    }

    private static func interpolateDayAmount(dayNum: Int, daysInMonth: Int, unit: String, w1: Double, w4: Double) -> Double {
        let dim = max(1, daysInMonth)
        let t = dim <= 1 ? 0 : Double(dayNum - 1) / Double(dim - 1)
        let raw = w1 + t * (w4 - w1)
        if unit == "sec" { return max(1, raw.rounded()) }
        if unit == "min" { return max(1, raw.rounded()) }
        if unit == "km" { return max(0.1, (raw * 10).rounded() / 10) }
        return max(1, raw.rounded())
    }

    private static func buildBlocksFromProgramVote(dayMeta: GenDay, dayNum: Int, daysInMonth: Int, vote: ProgramVoteRecord, userLevel: Int) -> [ProgBlock]? {
        guard !vote.level.isEmpty else { return nil }
        if dayMeta.type == "stretch" { return nil }
        if vote.exerciseIds.isEmpty { return [] }
        let lv = String(vote.level)
        var blocks: [ProgBlock] = []
        for exerciseId in vote.exerciseIds {
            guard let am = resolveProgramExerciseW1W4(exerciseId: exerciseId, vote: vote, programLevel: lv, userLevel: userLevel) else { continue }
            let amount = interpolateDayAmount(dayNum: dayNum, daysInMonth: daysInMonth, unit: am.unit, w1: am.w1, w4: am.w4)
            blocks.append(ProgBlock(exerciseId: exerciseId, amount: amount, unit: am.unit, text: nil))
        }
        return blocks.isEmpty ? nil : blocks
    }

    private static func calendarStretchOverridesProgramVote(cal: GenCal, displayVotes: [String: ProgramVoteRecord], dayNum: Int) -> Bool {
        guard let dm = dayByNumber(cal: cal, dayNum), dm.type == "stretch" else { return false }
        guard let vk = voteKey(calendar: cal) else { return false }
        var vote = displayVotes[vk]
        if vote == nil || (vote!.exerciseIds.isEmpty) {
            vote = defaultTemplateRecord()
        }
        guard let v = vote else { return false }
        return !isIndividualProgramVoteSlice(v)
    }

    private static func getEffectiveBlocksForDay(cal: GenCal, displayVotes: [String: ProgramVoteRecord], dayNum: Int, userLevel: Int) -> [ProgBlock] {
        guard let dm = dayByNumber(cal: cal, dayNum) else { return [] }
        var vote = voteKey(calendar: cal).flatMap { displayVotes[$0] }
        if vote == nil || (vote?.exerciseIds.isEmpty ?? true) || (vote?.level.isEmpty ?? true) {
            vote = defaultTemplateRecord()
        }
        guard let v = vote else { return [] }

        if dm.type == "stretch", !isIndividualProgramVoteSlice(v) {
            return dm.blocks
        }

        let dim = cal.daysInMonth > 0 ? cal.daysInMonth : 30
        var voteForDay = v
        let hasDow = v.dowOverrides?.isEmpty == false
        if hasDow, cal.year > 0, cal.month >= 1, cal.month <= 12 {
            let iso = moscowIsoWeekday(year: cal.year, month: cal.month, day: dayNum)
            let ids = effectiveExerciseIdsForIsoDow(vote: v, isoDow: iso)
            voteForDay = ProgramVoteRecord(
                exerciseIds: ids,
                level: v.level,
                updatedAt: v.updatedAt,
                startAmounts: v.startAmounts,
                dowOverrides: v.dowOverrides,
                customExercises: v.customExercises
            )
        }

        let dmForVote: GenDay = {
            if dm.type == "stretch", isIndividualProgramVoteSlice(v) {
                GenDay(day: dm.day, type: "workout", blocks: [])
            } else {
                dm
            }
        }()

        let builtOpt = buildBlocksFromProgramVote(dayMeta: dmForVote, dayNum: dayNum, daysInMonth: dim, vote: voteForDay, userLevel: userLevel)
        if builtOpt != nil { return builtOpt! }
        return dm.blocks
    }

    // MARK: - Снимки и маски

    private static func completedSnapshot(_ st: ProgressDay) -> [String: Double]? {
        guard let raw = st.completedExerciseAmounts, !raw.isEmpty else { return nil }
        var out: [String: Double] = [:]
        for (k, v) in raw where v.isFinite && v > 0 {
            out[String(k)] = v
        }
        return out.isEmpty ? nil : out
    }

    private static func parseBlockForStats(_ block: ProgBlock) -> (key: String, n: Double)? {
        if let id = block.exerciseId, let a = block.amount, a.isFinite {
            return (String(id), a)
        }
        if let t = block.text { return parseLegacyExerciseFromBlock(t) }
        return nil
    }

    private static func parseLegacyExerciseFromBlock(_ text: String) -> (key: String, n: Double)? {
        let t = text.trimmingCharacters(in: .whitespaces)
        if let n = regexFirstDouble(pattern: #"^(\d+)\s+приседани"#, text: t, group: 1) { return ("squats", n) }
        if let n = regexFirstDouble(pattern: #"^(\d+)\s+пресс$"#, text: t, group: 1) { return ("abs", n) }
        if let n = regexFirstDouble(pattern: #"планка\s+(\d+)\s*сек"#, text: t, group: 1) { return ("plank", n) }
        if let n = regexFirstDouble(pattern: #"^(\d+)\s+отжимани"#, text: t, group: 1) { return ("pushups", n) }
        return nil
    }

    private static func regexFirstDouble(pattern: String, text: String, group: Int) -> Double? {
        guard let r = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let m = r.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              group < m.numberOfRanges,
              let rng = Range(m.range(at: group), in: text) else { return nil }
        return Double(text[rng])
    }

    private static func tasksDoneMask(st: ProgressDay, blockCount: Int, blocks: [ProgBlock]) -> [Bool] {
        guard blockCount > 0 else { return [] }
        if let snap = completedSnapshot(st), blocks.count == blockCount {
            return blocks.map { b in
                guard let p = parseBlockForStats(b) else { return false }
                guard let n = snap[p.key] else { return false }
                return n.isFinite && n > 0
            }
        }
        if let td = st.tasksDone, td.count == blockCount { return td.map { $0 } }
        if let td = st.tasksDone, td.count != blockCount {
            return (0 ..< blockCount).map { i in i < td.count ? td[i] : false }
        }
        if st.done == true { return Array(repeating: true, count: blockCount) }
        return Array(repeating: false, count: blockCount)
    }

    private static func tasksDoneMaskAny(st: ProgressDay, blocks: [ProgBlock]) -> Bool {
        tasksDoneMask(st: st, blockCount: blocks.count, blocks: blocks).contains(true)
    }

    private static func dayCountsAsWorkoutForDisplayedProgram(
        cal: GenCal,
        day: Int,
        st: ProgressDay,
        displayVotes: [String: ProgramVoteRecord],
        progression: Int
    ) -> Bool {
        guard let dm = dayByNumber(cal: cal, day) else { return false }
        let blocks = getEffectiveBlocksForDay(cal: cal, displayVotes: displayVotes, dayNum: day, userLevel: progression)
        if dm.type == "stretch" {
            if blocks.isEmpty { return dayCountsAsWorkout(st) }
            return tasksDoneMaskAny(st: st, blocks: blocks)
        }
        if blocks.isEmpty {
            let snap = completedSnapshot(st)
            let allowed = Set(monthProgramExerciseKeys(calendar: cal, displayVotes: displayVotes).map { String($0) })
            if let snap {
                return snap.keys.contains { allowed.contains($0) && (snap[$0] ?? 0) > 0 }
            }
            return st.done == true
        }
        return tasksDoneMaskAny(st: st, blocks: blocks)
    }

    private static func sumMonthExercises(
        cal: GenCal,
        progressDays: [String: ProgressDay],
        displayVotes: [String: ProgramVoteRecord],
        progression: Int
    ) -> [String: Double] {
        var totals: [String: Double] = [:]
        let programKeySet = Set(monthProgramExerciseKeys(calendar: cal, displayVotes: displayVotes).map { String($0) })
        let n = cal.daysInMonth
        for d in 1 ... n {
            let st = progressDays[String(d)] ?? ProgressDay()
            guard dayCountsAsWorkoutForDisplayedProgram(cal: cal, day: d, st: st, displayVotes: displayVotes, progression: progression) else { continue }
            guard dayByNumber(cal: cal, d) != nil, !calendarStretchOverridesProgramVote(cal: cal, displayVotes: displayVotes, dayNum: d) else { continue }

            if let snap = completedSnapshot(st) {
                for (key, val) in snap where programKeySet.contains(key) && val.isFinite && val > 0 {
                    totals[key, default: 0] += val
                }
                continue
            }
            let blocks = getEffectiveBlocksForDay(cal: cal, displayVotes: displayVotes, dayNum: d, userLevel: progression)
            let mask = tasksDoneMask(st: st, blockCount: blocks.count, blocks: blocks)
            for i in blocks.indices where i < mask.count && mask[i] {
                if let p = parseBlockForStats(blocks[i]) {
                    totals[p.key, default: 0] += p.n
                }
            }
        }
        return totals
    }

    // MARK: - Подписи и формат

    private static func exerciseKeyLabel(_ key: String, vote: ProgramVoteRecord?) -> String {
        if let l = legacyLabels[key] { return l }
        if let ex = catalogExercise(key) { return ex.label }
        if let c = vote?.customExercises?[key]?.label, !c.trimmingCharacters(in: .whitespaces).isEmpty {
            return c.trimmingCharacters(in: .whitespaces)
        }
        return key
    }

    private static func formatExerciseStatValue(_ key: String, _ n: Double, vote: ProgramVoteRecord?) -> String {
        let safe = n.isFinite ? n : 0
        let ru = Locale(identifier: "ru_RU")
        if key == "plank" { return "\(Int(safe.rounded()).formatted(.number.locale(ru))) с" }
        if let ex = catalogExercise(key) {
            if ex.unit == "sec" { return "\(Int(safe.rounded()).formatted(.number.locale(ru))) с" }
            if ex.unit == "min" { return "\(Int(safe.rounded()).formatted(.number.locale(ru))) мин" }
            if ex.unit == "km" {
                let fmt = safe.formatted(.number.precision(.fractionLength(0 ... 1)).locale(ru))
                return "\(fmt) км"
            }
        }
        if let u = vote?.customExercises?[key]?.unit {
            if u == "sec" { return "\(Int(safe.rounded()).formatted(.number.locale(ru))) с" }
            if u == "min" { return "\(Int(safe.rounded()).formatted(.number.locale(ru))) мин" }
            if u == "km" {
                let fmt = safe.formatted(.number.precision(.fractionLength(0 ... 1)).locale(ru))
                return "\(fmt) км"
            }
        }
        return Int(safe.rounded()).formatted(.number.locale(ru))
    }
}
