import Foundation

// MARK: - Ключ логина (как `loginKey` в sport-calendar-web/js/utils/slug.js)

enum CommunityLoginKey {
    static func from(login: String?) -> String {
        String(login ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: "-", options: .regularExpression)
    }
}

// MARK: - Склонение «респект»

enum RussianCommunityCopy {
    /// 1 респект, 2 респекта, 5 респектов — как `ruRespectForm` на вебе.
    static func respectForm(for count: Int) -> String {
        let k = abs(count)
        let d10 = k % 10
        let d100 = k % 100
        if d10 == 1 && d100 != 11 { return "респект" }
        if d10 >= 2 && d10 <= 4 && (d100 < 12 || d100 > 14) { return "респекта" }
        return "респектов"
    }

    static func respectPhrase(count: Int) -> String {
        "\(count) \(respectForm(for: count))"
    }
}

// MARK: - Засчёт дня как тренировки (как `dayCountsAsWorkout` в progress.js)

enum CommunityProgressRules {
    static func dayCountsAsWorkout(_ d: ProgressDay?) -> Bool {
        guard let d else { return false }
        if d.done == true { return true }
        if let td = d.tasksDone, td.contains(true) { return true }
        if let raw = d.completedExerciseAmounts {
            for v in raw.values where v > 0 { return true }
        }
        return false
    }

    static func dayCountsAsWorkoutBoard(_ d: BoardProgressDay?) -> Bool {
        guard let d else { return false }
        if d.done == true { return true }
        if let td = d.tasksDone, td.contains(true) { return true }
        if let raw = d.completedExerciseAmounts {
            for v in raw.values where v > 0 { return true }
        }
        return false
    }
}

// MARK: - Галерея отчётов

struct CommunityProofItem: Codable, Sendable, Hashable, Identifiable {
    var calendarId: String
    var day: String
    var doneAt: String?
    var proofUrl: String?
    var proofType: String?
    var proofCaption: String?

    /// Стабильный ключ для списков: без дублей при пустом `proofUrl` и при нескольких отличиях в метаданных.
    var id: String {
        let url = proofUrl ?? ""
        let at = doneAt ?? ""
        let typ = proofType ?? ""
        let cap = proofCaption ?? ""
        return "\(calendarId)|\(day)|\(url)|\(at)|\(typ)|\(cap)"
    }

    /// Только элементы с реальным файлом — без «пустых» плейсхолдеров в сетке.
    static func galleryDisplayList(_ proofs: [CommunityProofItem]) -> [CommunityProofItem] {
        var seen = Set<String>()
        var out: [CommunityProofItem] = []
        out.reserveCapacity(proofs.count)
        for p in proofs {
            guard let raw = p.proofUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { continue }
            let key = p.id
            if seen.contains(key) { continue }
            seen.insert(key)
            out.append(p)
        }
        return out
    }

    var isVideo: Bool {
        let t = (proofType ?? "").lowercased()
        if t.contains("video") || t == "mp4" || t == "webm" { return true }
        if let u = proofUrl?.lowercased(), u.contains(".mp4") || u.contains(".webm") || u.contains(".mov") {
            return true
        }
        return false
    }
}

enum CommunityProofsMerge {
    /// Как `sortCommunityProofsNewestFirst` на вебе.
    static func sortNewestFirst(_ proofs: [CommunityProofItem]) -> [CommunityProofItem] {
        proofs.sorted { a, b in
            let ta = a.doneAt.flatMap { parseISO($0) }
            let tb = b.doneAt.flatMap { parseISO($0) }
            let validA = ta != nil
            let validB = tb != nil
            if validA, validB, let ta, let tb, tb != ta { return tb < ta }
            if validA && !validB { return true }
            if !validA && validB { return false }
            if b.calendarId != a.calendarId { return b.calendarId > a.calendarId }
            return (Int(b.day) ?? 0) > (Int(a.day) ?? 0)
        }
    }

    private static func parseISO(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }

    /// Серверные `communityProofs` + локальные дни с `proofUrl` из bootstrap (только для текущего пользователя).
    static func mergedProofs(
        server: [CommunityProofItem]?,
        bootstrap: BootstrapResponse?,
        loginKey rowKey: String,
        selfLoginKey: String?
    ) -> [CommunityProofItem] {
        var serverList = server ?? []
        let seen = Set(serverList.map { "\($0.calendarId)|\($0.day)" })
        if let selfKey = selfLoginKey, rowKey == selfKey, let b = bootstrap {
            let login = CommunityLoginKey.from(login: b.user.login)
            guard login == rowKey else { return sortNewestFirst(serverList) }
            for (calId, cal) in b.progress {
                for (dayKey, day) in cal.days {
                    guard CommunityProgressRules.dayCountsAsWorkout(day) else { continue }
                    guard let url = day.proofUrl, !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                    let key = "\(calId)|\(dayKey)"
                    if seen.contains(key) { continue }
                    serverList.append(
                        CommunityProofItem(
                            calendarId: calId,
                            day: dayKey,
                            doneAt: day.doneAt,
                            proofUrl: url,
                            proofType: day.proofType,
                            proofCaption: day.proofCaption
                        )
                    )
                }
            }
        }
        return sortNewestFirst(serverList)
    }
}

// MARK: - Геймификация для чужого профиля (как `computeGamification` в gamification.js)

struct CommunityGamificationSnapshot: Sendable {
    var level: Int
    var xpIntoLevel: Int
    var xpSpanThisLevel: Int
    var progressPct: Double
}

enum CommunityGamification {
    private static let xpPerWorkout = 15
    private static let xpScale = 50.0

    private static func levelFromTotalXp(_ xpTotal: Double) -> Int {
        let x = max(0, xpTotal)
        let lvl = Int(floor(sqrt(x / xpScale))) + 1
        return max(1, lvl)
    }

    private static func xpThresholdForLevel(_ level: Int) -> Int {
        let l = max(1, level)
        if l <= 1 { return 0 }
        return Int(xpScale * Double(l - 1) * Double(l - 1))
    }

    static func compute(totalWorkouts: Int, bonusXp: Int) -> CommunityGamificationSnapshot {
        let tw = max(0, totalWorkouts)
        let bx = max(0, bonusXp)
        let xpFromWorkouts = tw * xpPerWorkout
        let xpTotal = xpFromWorkouts + bx
        let level = levelFromTotalXp(Double(xpTotal))
        let curStart = xpThresholdForLevel(level)
        let nextStart = xpThresholdForLevel(level + 1)
        let xpInto = xpTotal - curStart
        let xpSpan = nextStart - curStart
        let progressPct: Double = {
            guard xpSpan > 0 else { return 1 }
            return min(1, max(0, Double(xpInto) / Double(xpSpan)))
        }()
        return CommunityGamificationSnapshot(
            level: level,
            xpIntoLevel: max(0, xpInto),
            xpSpanThisLevel: max(1, xpSpan),
            progressPct: progressPct
        )
    }
}

// MARK: - Порядок строк ленты

enum CommunityFeedOrdering {
    /// Текущий пользователь — первая карточка (как `orderCommunityRowsWithSelfFirst`).
    static func selfFirst(
        rows: [(key: String, user: BoardUserPublic)],
        selfLogin: String?
    ) -> [(key: String, user: BoardUserPublic)] {
        guard let selfLogin else { return rows }
        let k = CommunityLoginKey.from(login: selfLogin)
        guard !k.isEmpty else { return rows }
        guard let i = rows.firstIndex(where: { $0.key == k }), i > 0 else { return rows }
        var copy = rows
        let selfRow = copy.remove(at: i)
        copy.insert(selfRow, at: 0)
        return copy
    }

    /// Как на вебе: уровень атлета, затем всего тренировок, затем имя по алфавиту.
    static func leaderboardSort(rows: [(key: String, user: BoardUserPublic)]) -> [(key: String, user: BoardUserPublic)] {
        rows.sorted { a, b in
            let la = a.user.athleteLevel ?? 0
            let lb = b.user.athleteLevel ?? 0
            if la != lb { return la > lb }
            let ta = a.user.totalWorkoutsLifetime ?? 0
            let tb = b.user.totalWorkoutsLifetime ?? 0
            if ta != tb { return ta > tb }
            let na = a.user.displayName ?? a.key
            let nb = b.user.displayName ?? b.key
            return na.localizedCaseInsensitiveCompare(nb) == .orderedAscending
        }
    }
}

enum CommunityScopeFilter: String, CaseIterable, Identifiable, Hashable {
    case all = "Все"
    case friends = "Друзья"

    var id: String { rawValue }
}
