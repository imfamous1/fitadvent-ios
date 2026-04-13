import Foundation

// MARK: - Стилистика (согласовано с sport-calendar-web)

enum ProfileChrome {
    /// Светлая тема: `--color-primary` `#e85d04` (`variables.css`)
    static let primary = (red: 232.0 / 255.0, green: 93.0 / 255.0, blue: 4.0 / 255.0)
    /// `--ui-blue` / `--btn-action-bg` `#008bff`
    static let accentBlue = (red: 0.0, green: 139.0 / 255.0, blue: 1.0)
    /// Светлая тема: `--color-error` `#d94828` (текст «Выйти» как на вебе)
    static let error = (red: 217.0 / 255.0, green: 72.0 / 255.0, blue: 40.0 / 255.0)
    /// `--btn-activity-surface` `#feffff` (фон кнопки выхода)
    static let activitySurface = (red: 254.0 / 255.0, green: 255.0 / 255.0, blue: 255.0 / 255.0)

    /// `--radius-lg` / `.btn`
    static let radiusLg: CGFloat = 16
    /// `--radius-xl` (карточки, панели)
    static let radiusXl: CGFloat = 24

    /// «Выйти»: только вертикальный padding (капсула по содержимому)
    static let profileBarVerticalPadding: CGFloat = 14
    /// «Редактировать анкету» и stat-pill: одна высота (как `.profile-account-btn` min-height 52px на вебе)
    static let profileBarFixedHeight: CGFloat = 52

    /// Горизонтальный отступ строк плана (`--space-4` у `.day-plan-mode-btn`)
    static let exerciseRowPaddingH: CGFloat = 16
    /// Ширина колонки иконки в строке упражнений
    static let exerciseRowIconColumnWidth: CGFloat = 28
    /// `HStack` spacing между иконкой и текстом
    static let exerciseRowIconSpacing: CGFloat = 12
    /// Заголовок / подзаголовок блока «Упражнения»: как `.nutrition-records-card__title` — `margin-inline-start: var(--space-4)` (внутренняя зона карточки после скругления)
    static let exerciseSectionTitleLeading: CGFloat = exerciseRowPaddingH
    /// Разделитель между строками: как `.day-workout-plan-card__divider`
    static var exercisePlanDividerLeading: CGFloat {
        exerciseRowPaddingH + exerciseRowIconColumnWidth + exerciseRowIconSpacing
    }

    static let chipAthlete = (red: 0.78, green: 0.22, blue: 0.22)
    static let chipVip = (red: 0.95, green: 0.52, blue: 0.12)
    static let chipTelegram = (red: 0.20, green: 0.55, blue: 0.92)
}

// MARK: - Даты и VIP

private let monthsGenRu = [
    "января", "февраля", "марта", "апреля", "мая", "июня",
    "июля", "августа", "сентября", "октября", "ноября", "декабря",
]

/// Как `formatAthleteSince` в `dateRu.js` (UTC).
func formatAthleteSince(_ iso: String?) -> String {
    guard let iso, !iso.isEmpty else { return "" }
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    var d = f.date(from: iso)
    if d == nil {
        f.formatOptions = [.withInternetDateTime]
        d = f.date(from: iso)
    }
    guard let date = d else { return "" }
    let cal = Calendar(identifier: .gregorian)
    let y = cal.component(.year, from: date)
    let m = cal.component(.month, from: date)
    guard m >= 1, m <= 12 else { return "" }
    return "Атлет с \(monthsGenRu[m - 1]) \(y) г."
}

func formatVipUntilDisplay(_ iso: String?) -> String {
    guard let raw = iso?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return "" }
    let t = Date.parseISO8601Like(raw)
    guard let t else { return "" }
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = .current
    let d = cal.component(.day, from: t)
    let m = cal.component(.month, from: t)
    let y = cal.component(.year, from: t)
    return String(format: "%02d.%02d.%04d", d, m, y)
}

func vipActive(_ p: UserProfile) -> Bool {
    if let a = p.vipActive { return a }
    guard let u = p.vipUntil, !u.isEmpty else { return false }
    let t = Date.parseISO8601Like(u)
    guard let t else { return false }
    return t > Date()
}

// MARK: - Тренировки по месяцам (все календари)

struct WorkoutMonthStat: Identifiable {
    var id: String { monthKey }
    var monthKey: String
    var label: String
    var count: Int
}

/// Считает отмеченные дни `done == true` по всем календарям, группирует по YYYY-MM.
func workoutStatsByMonth(progress: [String: ProgressCalendar]) -> [WorkoutMonthStat] {
    var byMonth: [String: Int] = [:]
    for (_, cal) in progress {
        for (dayKey, day) in cal.days where day.done == true {
            let prefix = String(dayKey.prefix(7))
            if prefix.count == 7 {
                byMonth[prefix, default: 0] += 1
            }
        }
    }
    let sortedKeys = byMonth.keys.sorted()
    return sortedKeys.map { key in
        WorkoutMonthStat(monthKey: key, label: monthTitleRu(ym: key), count: byMonth[key] ?? 0)
    }
}

func totalWorkoutDays(progress: [String: ProgressCalendar]) -> Int {
    progress.values.reduce(0) { partial, cal in
        partial + cal.days.values.filter { $0.done == true }.count
    }
}

private func monthTitleRu(ym: String) -> String {
    let parts = ym.split(separator: "-")
    guard parts.count == 2,
          let y = Int(parts[0]),
          let m = Int(parts[1]), m >= 1, m <= 12 else { return ym }
    let cap = monthsGenRu[m - 1].capitalized
    return "\(cap) \(y)"
}

// MARK: - Москва: баннер голосования за программу (последние 7 дней месяца)

func moscowYmdNow() -> (year: Int, month: Int, day: Int) {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "Europe/Moscow") ?? .current
    let now = Date()
    let y = cal.component(.year, from: now)
    let m = cal.component(.month, from: now)
    let d = cal.component(.day, from: now)
    return (y, m, d)
}

func lastDayOfMonth(year: Int, month: Int) -> Int {
    var c = DateComponents()
    c.year = year
    c.month = month + 1
    c.day = 0
    let cal = Calendar(identifier: .gregorian)
    guard let date = cal.date(from: c) else { return 30 }
    return cal.component(.day, from: date)
}

/// Последние 7 дней месяца по Москве — показываем кнопку «Следующий».
func isProgramVoteBannerDayNow() -> Bool {
    let (y, m, d) = moscowYmdNow()
    let last = lastDayOfMonth(year: y, month: m)
    let bannerDays = 7
    let start = last - (bannerDays - 1)
    return d >= start && d <= last
}

func programVoteNextMonthTarget() -> (year: Int, month: Int) {
    let (y, m, _) = moscowYmdNow()
    if m == 12 { return (y + 1, 1) }
    return (y, m + 1)
}

// MARK: - ИМТ и калории (как `dailyKcalRecommendation.js`)

struct BmiInterpretation {
    var category: String
    var detail: String
}

func getBmiInterpretation(bmi: Double) -> BmiInterpretation? {
    guard bmi.isFinite else { return nil }
    let v = bmi
    if v < 18.5 {
        return BmiInterpretation(
            category: "Недостаточная масса тела",
            detail: "ИМТ ниже 18,5 — по шкале ВОЗ это ниже нормы для взрослых. При сомнениях имеет смысл обсудить показатели с врачом."
        )
    }
    if v < 25 {
        return BmiInterpretation(
            category: "Нормальная масса тела",
            detail: "ИМТ от 18,5 до 25 — диапазон, который ВОЗ считает нормальным для взрослых."
        )
    }
    if v < 30 {
        return BmiInterpretation(
            category: "Избыточная масса тела",
            detail: "ИМТ от 25 до 30 — предожирение. Полезно следить за питанием и нагрузкой; ИМТ не различает жир и мышцы."
        )
    }
    if v < 35 {
        return BmiInterpretation(
            category: "Ожирение I степени",
            detail: "ИМТ от 30 до 35. Это медицинская категория; при необходимости проконсультируйтесь со специалистом."
        )
    }
    return BmiInterpretation(
        category: "Ожирение II степени и выше",
        detail: "ИМТ 35 и выше. Рекомендуется консультация со специалистом."
    )
}

private let profileHeightMin = 50.0
private let profileHeightMax = 250.0
private let profileWeightMin = 20.0
private let profileWeightMax = 300.0
private let profileAgeMin = 14
private let profileAgeMax = 100
private let recommendedKcalDefaultAge = 30
private let activityFactor = 1.55
private let kcalMinBound = 1200
private let kcalMaxBound = 6000

struct KcalNorms {
    var maintenance: Int?
    var deficit: Int?
    var surplus: Int?
}

func normalizeProfileSex(_ raw: String?) -> String {
    let s = String(raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if s == "male" || s == "m" { return "male" }
    if s == "female" || s == "f" { return "female" }
    return ""
}

private func parseDouble(_ s: String?) -> Double? {
    guard let s else { return nil }
    let t = s.replacingOccurrences(of: ",", with: ".")
    return Double(t.trimmingCharacters(in: .whitespaces))
}

private func computeProfileAnthroBmi(_ p: UserProfile) -> Double? {
    guard let h = parseDouble(p.heightCm), let w = parseDouble(p.weightKg) else { return nil }
    guard h >= profileHeightMin, h <= profileHeightMax, w >= profileWeightMin, w <= profileWeightMax else { return nil }
    let hm = h / 100
    let bmi = w / (hm * hm)
    guard bmi.isFinite, bmi > 0 else { return nil }
    return bmi
}

private func isAnthroCompleteForKcal(_ p: UserProfile) -> Bool {
    guard let h = parseDouble(p.heightCm), let w = parseDouble(p.weightKg) else { return false }
    guard h >= profileHeightMin, h <= profileHeightMax, w >= profileWeightMin, w <= profileWeightMax else { return false }
    let rawAge = String(p.ageYears ?? "").trimmingCharacters(in: .whitespaces)
    if rawAge.isEmpty { return true }
    guard let age = Int(rawAge.replacingOccurrences(of: ",", with: ".").components(separatedBy: ".").first ?? "") else { return false }
    return age >= profileAgeMin && age <= profileAgeMax
}

private func resolvedAgeYearsForBmr(_ p: UserProfile) -> Int? {
    guard isAnthroCompleteForKcal(p) else { return nil }
    let raw = String(p.ageYears ?? "").trimmingCharacters(in: .whitespaces)
    if raw.isEmpty { return recommendedKcalDefaultAge }
    guard let age = Int(raw.replacingOccurrences(of: ",", with: ".").components(separatedBy: ".").first ?? "") else { return nil }
    return age
}

private func bmrMifflinStJeor(weightKg: Double, heightCm: Double, ageYears: Int, sex: String) -> Double {
    let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(ageYears)
    if sex == "male" { return base + 5 }
    if sex == "female" { return base - 161 }
    return base - 78
}

private func adjustTdeeByWhoBmi(tdee: Double, bmi: Double) -> Double? {
    guard tdee.isFinite, tdee > 0, bmi.isFinite else { return nil }
    if bmi < 18.5 { return tdee * 1.1 }
    if bmi < 25 { return tdee }
    if bmi < 30 { return tdee * 0.88 }
    return tdee * 0.82
}

func computeTdeeAndKcalNorms(_ p: UserProfile) -> (bmi: Double?, norms: KcalNorms) {
    let bmi = computeProfileAnthroBmi(p)
    guard isAnthroCompleteForKcal(p), let bmi else {
        return (bmi, KcalNorms(maintenance: nil, deficit: nil, surplus: nil))
    }
    guard let h = parseDouble(p.heightCm), let w = parseDouble(p.weightKg),
          let ageYears = resolvedAgeYearsForBmr(p) else {
        return (bmi, KcalNorms(maintenance: nil, deficit: nil, surplus: nil))
    }
    let sex = normalizeProfileSex(p.sex)
    let bmr = bmrMifflinStJeor(weightKg: w, heightCm: h, ageYears: ageYears, sex: sex)
    guard bmr.isFinite, bmr > 0 else {
        return (bmi, KcalNorms(maintenance: nil, deficit: nil, surplus: nil))
    }
    let tdee = bmr * activityFactor
    guard tdee.isFinite, tdee > 0 else {
        return (bmi, KcalNorms(maintenance: nil, deficit: nil, surplus: nil))
    }
    guard let adjusted = adjustTdeeByWhoBmi(tdee: tdee, bmi: bmi) else {
        return (bmi, KcalNorms(maintenance: nil, deficit: nil, surplus: nil))
    }
    let maintenance = max(kcalMinBound, min(kcalMaxBound, Int((adjusted).rounded())))
    let deficit = max(kcalMinBound, min(kcalMaxBound, Int((adjusted * 0.8).rounded())))
    let surplus = max(kcalMinBound, min(kcalMaxBound, Int((adjusted * 1.12).rounded())))
    return (bmi, KcalNorms(maintenance: maintenance, deficit: deficit, surplus: surplus))
}

func kcalRecommendationAgeFootnote(_ p: UserProfile) -> String {
    let raw = String(p.ageYears ?? "").trimmingCharacters(in: .whitespaces)
    if raw.isEmpty {
        return "возраст в анкете не указан — в расчёте \(recommendedKcalDefaultAge) лет"
    }
    if let age = Int(raw.replacingOccurrences(of: ",", with: ".").components(separatedBy: ".").first ?? ""),
       age >= profileAgeMin, age <= profileAgeMax {
        return "возраст \(age) лет"
    }
    return "возраст в анкете не указан — в расчёте \(recommendedKcalDefaultAge) лет"
}

// MARK: - Ранг по уровню (`athleteLevelLabel`)

func athleteLevelLabel(level: Int) -> String {
    let l = max(1, level)
    if l == 1 { return "Начинающий" }
    if l <= 3 { return "Любитель" }
    if l <= 6 { return "Практик" }
    if l <= 10 { return "Продвинутый" }
    if l <= 14 { return "Опытный" }
    if l <= 19 { return "Мастер" }
    return "Элита"
}

// MARK: - ISO date parsing

extension Date {
    static func parseISO8601Like(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        if let d = f.date(from: s) { return d }
        if let t = TimeInterval(s), t > 0 { return Date(timeIntervalSince1970: t / 1000) }
        return nil
    }
}
