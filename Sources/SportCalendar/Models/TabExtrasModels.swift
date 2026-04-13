import Foundation

// MARK: - Доска сообщества (`GET /api/board/:calendarId`)

struct BoardAPIResponse: Decodable, Sendable {
    var users: [String: BoardUserPublic]
    var updatedAt: String?
}

struct BoardMonthProgram: Decodable, Sendable {
    var exerciseIds: [String]?
    var level: String?
}

struct BoardProgressDay: Decodable, Sendable {
    var done: Bool?
    var doneAt: String?
    var proofUrl: String?
    var proofType: String?
    var proofCaption: String?
    var tasksDone: [Bool]?
    var completedExerciseAmounts: [String: Double]?
}

struct BoardUserPublic: Decodable, Sendable {
    var login: String?
    var displayName: String?
    var avatarUrl: String?
    var athleteLevel: Int?
    var totalWorkoutsLifetime: Int?
    var likeCount: Int?
    var likedByMe: Bool?
    var vipActive: Bool?
    var bonusXp: Int?
    var shareBodyStats: Bool?
    var shareProofsLarge: Bool?
    var showInCommunityList: Bool?
    var heightCm: String?
    var weightKg: String?
    var calendarId: String?
    var days: [String: BoardProgressDay]?
    var communityProofs: [CommunityProofItem]?
    var monthProgram: BoardMonthProgram?
}

// MARK: - Питание (`GET /api/me/nutrition`)

struct NutritionDayResponse: Decodable, Sendable {
    var day: String
    var entries: [NutritionEntryDTO]
    var totalKcal: Int
}

struct NutritionEntryDTO: Decodable, Identifiable, Sendable {
    var id: Int
    var day: String
    var mealType: String
    var title: String
    var kcal: Int
    var createdAt: String?
}
