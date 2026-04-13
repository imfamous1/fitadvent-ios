import Foundation

/// Ответ `GET /api/bootstrap` (см. `server/src/routes/api.js`).
struct BootstrapResponse: Codable, Sendable {
    var user: BootstrapUserBlock
    var progress: [String: ProgressCalendar]
    var leaderboardArchive: [String: [String: LeaderboardArchiveEntry]]
    var gamification: Gamification
    var favoriteLoginKeys: [String]
    var friendRequests: FriendRequestsPayload
    var programVotes: [String: ProgramVoteRecord]
    var customExerciseLibrary: [String: CustomExerciseLibraryEntry]
}

struct BootstrapUserBlock: Codable, Sendable {
    var login: String
    var profile: UserProfile
}

struct UserProfile: Codable, Sendable {
    var displayName: String?
    var heightCm: String?
    var weightKg: String?
    var ageYears: String?
    var sex: String?
    var avatarUrl: String?
    var registeredAt: String?
    var shareBodyStats: Bool?
    var shareProofsLarge: Bool?
    var showInCommunityList: Bool?
    var bonusXp: Int?
    var wordsEverWon: Bool?
    var dailyKcalGoal: Int?
    var vipUntil: String?
    var vipActive: Bool?
    var telegramLinked: Bool?
    var telegramUsername: String?
    var telegramUserId: Int64?
    var email: String?
    var emailVerified: Bool?
}

struct ProgressCalendar: Codable, Sendable {
    var days: [String: ProgressDay]
}

struct ProgressDay: Codable, Sendable {
    var done: Bool?
    var doneAt: String?
    var proofUrl: String?
    var proofType: String?
    var proofCaption: String?
    var tasksDone: [Bool]?
    var completedExerciseAmounts: [String: Double]?
}

struct LeaderboardArchiveEntry: Codable, Sendable {
    var completed: Int
    var displayName: String
    var login: String
}

struct Gamification: Codable, Sendable {
    var totalWorkouts: Int?
    var bonusXp: Int?
    var xpFromWorkouts: Int?
    var xpFromBonus: Int?
    var xpTotal: Int?
    var level: Int?
    var xpIntoLevel: Int?
    var xpForNextLevel: Int?
    var xpSpanThisLevel: Int?
    var progressPct: Double?
    var bmi: Double?
    var achievements: [Achievement]?
}

struct Achievement: Codable, Sendable, Hashable {
    var id: String
    var title: String
    var icon: String
    var unlocked: Bool
    /// С сервера может прийти позже; до тех пор подставляем копию из `AchievementCopy` (как `ACHIEVEMENT_DEFS` на вебе).
    var wisdom: String?
    var wisdomAuthor: String?
    var unlockHint: String?

    /// Короткий заголовок в сетке и на экране деталей (в т.ч. если в кэше ещё старая строка с «· скоро»).
    var displayTitle: String {
        if id == "competition_win" { return "Победа в соревновании" }
        return title
    }
}

struct FriendRequestsPayload: Codable, Sendable {
    var incoming: [IncomingFriendRequest]
    var outgoingLoginKeys: [String]
}

struct IncomingFriendRequest: Codable, Sendable {
    var loginKey: String
    var displayName: String
    var avatarUrl: String
    var vipUntil: String
    var vipActive: Bool
}

struct ProgramVoteRecord: Codable, Sendable {
    var exerciseIds: [String]
    var level: String
    var updatedAt: String
    var startAmounts: [String: Int]?
    var dowOverrides: [String: [String]]?
    var customExercises: [String: CustomExerciseLibraryEntry]?
}

struct CustomExerciseLibraryEntry: Codable, Sendable {
    var label: String
    var unit: String
    var base: CustomExerciseBaseDecodable?
    var monthEndMultiplier: Double?
}

struct CustomExerciseBaseDecodable: Codable, Sendable {
    var beginner: Double?
    var intermediate: Double?
    var advanced: Double?
}
