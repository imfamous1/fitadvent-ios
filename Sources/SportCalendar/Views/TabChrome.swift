import SwiftUI

/// Шапка вкладки в стиле `view-head` на вебе (как у профиля).
struct TabMegaHeader: View {
    var title: String
    var subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.primary)
                .tracking(-0.5)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

enum MoscowCalendar {
    private static var msk: TimeZone { TimeZone(identifier: "Europe/Moscow") ?? .current }

    static func todayYmd() -> String {
        ymdString(from: Date())
    }

    static func ymdString(from date: Date) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = msk
        let y = cal.component(.year, from: date)
        let m = cal.component(.month, from: date)
        let d = cal.component(.day, from: date)
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    /// «2026-04» → заголовок «Апрель 2026»
    static func monthTitle(calendarId: String) -> String {
        let parts = calendarId.split(separator: "-")
        guard parts.count >= 2,
              let y = Int(parts[0]),
              let m = Int(parts[1]), m >= 1, m <= 12 else {
            return calendarId
        }
        let names = [
            "Январь", "Февраль", "Март", "Апрель", "Май", "Июнь",
            "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь",
        ]
        return "\(names[m - 1]) \(y)"
    }

    /// «2026-04» → «в апреле 2026» (предложный падеж и год — для фраз вроде «тренировочные дни в …»).
    static func monthInPrepositionalWithYear(calendarId: String) -> String {
        let parts = calendarId.split(separator: "-")
        guard parts.count >= 2,
              let y = Int(parts[0]),
              let m = Int(parts[1]), m >= 1, m <= 12 else {
            return "в \(calendarId)"
        }
        let prep = [
            "январе", "феврале", "марте", "апреле", "мае", "июне",
            "июле", "августе", "сентябре", "октябре", "ноябре", "декабре",
        ]
        return "в \(prep[m - 1]) \(y)"
    }

    static func defaultCalendarId(keys: [String]) -> String {
        if let first = keys.sorted().first { return first }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = msk
        let d = Date()
        let y = cal.component(.year, from: d)
        let m = cal.component(.month, from: d)
        return String(format: "%04d-%02d", y, m)
    }

    static func shiftMonth(calendarId: String, delta: Int) -> String {
        let parts = calendarId.split(separator: "-")
        guard parts.count >= 2,
              var y = Int(parts[0]),
              var m = Int(parts[1]) else {
            return calendarId
        }
        m += delta
        while m > 12 { m -= 12; y += 1 }
        while m < 1 { m += 12; y -= 1 }
        return String(format: "%04d-%02d", y, m)
    }

    static func daysInMonth(calendarId: String) -> Int {
        let parts = calendarId.split(separator: "-")
        guard parts.count >= 2,
              let y = Int(parts[0]),
              let m = Int(parts[1]) else { return 31 }
        var c = DateComponents()
        c.year = y
        c.month = m + 1
        c.day = 0
        let cal = Calendar(identifier: .gregorian)
        guard let date = cal.date(from: c) else { return 31 }
        return cal.range(of: .day, in: .month, for: date)?.count ?? 31
    }

    /// Первый день месяца (МСК): 1 = пн … 7 = вс (как `Calendar.firstWeekday` в РФ часто пн)
    static func firstWeekdayMonday1Sunday7(calendarId: String) -> Int {
        let parts = calendarId.split(separator: "-")
        guard parts.count >= 2,
              let y = Int(parts[0]),
              let m = Int(parts[1]) else { return 1 }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = msk
        var c = DateComponents()
        c.year = y
        c.month = m
        c.day = 1
        guard let date = cal.date(from: c) else { return 1 }
        let wd = cal.component(.weekday, from: date)
        // Sunday=1 … Saturday=7 → пн=1 … вс=7
        let monBased = wd == 1 ? 7 : wd - 1
        return monBased
    }
}
