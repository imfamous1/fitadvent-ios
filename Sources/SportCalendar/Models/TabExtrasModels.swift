import Foundation

// MARK: - Доска сообщества (`GET /api/board/:calendarId`)

struct BoardAPIResponse: Decodable, Sendable {
    var users: [String: BoardUserPublic]
    var updatedAt: String?
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
