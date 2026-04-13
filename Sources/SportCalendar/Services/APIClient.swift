import Foundation

/// Клиент REST API, соответствующий `sport-calendar-web/js/services/api.js`.
actor APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Core

    private func url(_ path: String) -> URL {
        let base = APIConfig.baseURL
        let p = path.hasPrefix("/") ? path : "/\(path)"
        guard let u = URL(string: base + p) else {
            preconditionFailure("Invalid URL: \(base)\(p)")
        }
        return u
    }

    private func jsonRequest(
        _ path: String,
        method: String,
        body: Data? = nil,
        auth: Bool = true
    ) async throws -> (Data, HTTPURLResponse) {
        var req = URLRequest(url: url(path))
        req.httpMethod = method
        if body != nil {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        req.httpBody = body
        if auth, let t = KeychainTokenStore.readToken() {
            req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        }
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, http)
    }

    private func parseError(data: Data, status: Int) -> APIClientError {
        if let err = try? decoder.decode(APIErrorResponse.self, from: data) {
            return APIClientError(
                statusCode: status,
                message: err.error ?? HTTPURLResponse.localizedString(forStatusCode: status),
                fieldErrors: err.fieldErrors
            )
        }
        let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return APIClientError(
            statusCode: status,
            message: (text?.isEmpty == false) ? text! : HTTPURLResponse.localizedString(forStatusCode: status),
            fieldErrors: nil
        )
    }

    private func jsonDecode<T: Decodable>(_ type: T.Type, data: Data, http: HTTPURLResponse) throws -> T {
        guard (200 ... 299).contains(http.statusCode) else {
            throw parseError(data: data, status: http.statusCode)
        }
        return try decoder.decode(T.self, from: data)
    }

    private func jsonVoid(data: Data, http: HTTPURLResponse) throws {
        guard (200 ... 299).contains(http.statusCode) else {
            throw parseError(data: data, status: http.statusCode)
        }
    }

    private func jsonAny(data: Data, http: HTTPURLResponse) throws -> AnyCodableJSON {
        guard (200 ... 299).contains(http.statusCode) else {
            throw parseError(data: data, status: http.statusCode)
        }
        let obj = try JSONSerialization.jsonObject(with: data)
        return AnyCodableJSON(obj)
    }

    // MARK: - Health (без JWT)

    func health() async throws {
        var req = URLRequest(url: url("/health"))
        req.httpMethod = "GET"
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        try jsonVoid(data: data, http: http)
    }

    // MARK: - Auth

    func register(login: String, password: String) async throws -> AuthResponse {
        let body = try encoder.encode(AuthLoginBody(login: login, password: password))
        let (data, http) = try await jsonRequest("/api/auth/register", method: "POST", body: body, auth: false)
        let r = try jsonDecode(AuthResponse.self, data: data, http: http)
        if let t = r.token { KeychainTokenStore.saveToken(t) }
        return r
    }

    func login(login: String, password: String) async throws -> AuthResponse {
        let body = try encoder.encode(AuthLoginBody(login: login, password: password))
        let (data, http) = try await jsonRequest("/api/auth/login", method: "POST", body: body, auth: false)
        let r = try jsonDecode(AuthResponse.self, data: data, http: http)
        if let t = r.token { KeychainTokenStore.saveToken(t) }
        return r
    }

    func authTelegram(initData: String, createIfMissing: Bool = true) async throws -> AuthResponse {
        let body = try encoder.encode(TelegramAuthBody(initData: initData, createIfMissing: createIfMissing))
        let (data, http) = try await jsonRequest("/api/auth/telegram", method: "POST", body: body, auth: false)
        let r = try jsonDecode(AuthResponse.self, data: data, http: http)
        if let t = r.token { KeychainTokenStore.saveToken(t) }
        return r
    }

    func forgotPassword(login: String) async throws {
        let body = try encoder.encode(LoginOnlyBody(login: login))
        let (data, http) = try await jsonRequest("/api/auth/forgot-password", method: "POST", body: body, auth: false)
        try jsonVoid(data: data, http: http)
    }

    func resetPassword(token: String, password: String) async throws -> AuthResponse {
        let body = try encoder.encode(ResetPasswordBody(token: token, password: password))
        let (data, http) = try await jsonRequest("/api/auth/reset-password", method: "POST", body: body, auth: false)
        let r = try jsonDecode(AuthResponse.self, data: data, http: http)
        if let t = r.token { KeychainTokenStore.saveToken(t) }
        return r
    }

    func confirmEmail(token: String) async throws {
        let body = try encoder.encode(TokenBody(token: token))
        let (data, http) = try await jsonRequest("/api/auth/confirm-email", method: "POST", body: body, auth: false)
        try jsonVoid(data: data, http: http)
    }

    func telegramLink(initData: String) async throws {
        let body = try encoder.encode(TelegramLinkBody(initData: initData))
        let (data, http) = try await jsonRequest("/api/auth/telegram/link", method: "POST", body: body, auth: true)
        try jsonVoid(data: data, http: http)
    }

    func logout() {
        KeychainTokenStore.saveToken(nil)
    }

    // MARK: - Bootstrap & app

    func bootstrap() async throws -> BootstrapResponse {
        let (data, http) = try await jsonRequest("/api/bootstrap", method: "GET", body: nil, auth: true)
        return try jsonDecode(BootstrapResponse.self, data: data, http: http)
    }

    func patchMe(_ patch: ProfilePatchBody) async throws {
        let body = try encoder.encode(patch)
        let (data, http) = try await jsonRequest("/api/me", method: "PATCH", body: body, auth: true)
        try jsonVoid(data: data, http: http)
    }

    func patchMeEmail(email: String) async throws {
        let body = try encoder.encode(EmailBody(email: email))
        let (data, http) = try await jsonRequest("/api/me/email", method: "PATCH", body: body, auth: true)
        try jsonVoid(data: data, http: http)
    }

    func postEmailVerification() async throws {
        let (data, http) = try await jsonRequest("/api/me/email-verification", method: "POST", body: Data("{}".utf8), auth: true)
        try jsonVoid(data: data, http: http)
    }

    func putProgramVote(_ body: ProgramVoteBody) async throws {
        let data = try encoder.encode(body)
        let (dataOut, http) = try await jsonRequest("/api/me/program-vote", method: "POST", body: data, auth: true)
        try jsonVoid(data: dataOut, http: http)
    }

    func postCustomExercise(_ body: CustomExercisePostBody) async throws {
        let data = try encoder.encode(body)
        let (dataOut, http) = try await jsonRequest("/api/me/custom-exercise", method: "POST", body: data, auth: true)
        try jsonVoid(data: dataOut, http: http)
    }

    func getNutrition(day: String) async throws -> AnyCodableJSON {
        let (data, http) = try await jsonRequest("/api/me/nutrition?day=\(day.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? day)", method: "GET", auth: true)
        return try jsonAny(data: data, http: http)
    }

    func postNutrition(_ body: NutritionPostBody) async throws -> AnyCodableJSON {
        let data = try encoder.encode(body)
        let (dataOut, http) = try await jsonRequest("/api/me/nutrition", method: "POST", body: data, auth: true)
        return try jsonAny(data: dataOut, http: http)
    }

    func deleteNutrition(id: Int) async throws {
        let (data, http) = try await jsonRequest("/api/me/nutrition/\(id)", method: "DELETE", auth: true)
        try jsonVoid(data: data, http: http)
    }

    func postFavorite(loginKey: String) async throws {
        let body = try encoder.encode(LoginKeyBody(loginKey: loginKey))
        let (data, http) = try await jsonRequest("/api/me/favorites", method: "POST", body: body, auth: true)
        try jsonVoid(data: data, http: http)
    }

    func deleteFavorite(loginKey: String) async throws {
        let enc = loginKey.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? loginKey
        let (data, http) = try await jsonRequest("/api/me/favorites/\(enc)", method: "DELETE", auth: true)
        try jsonVoid(data: data, http: http)
    }

    func friendAccept(loginKey: String) async throws {
        let enc = loginKey.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? loginKey
        let (data, http) = try await jsonRequest("/api/me/friend-requests/\(enc)/accept", method: "POST", body: Data("{}".utf8), auth: true)
        try jsonVoid(data: data, http: http)
    }

    func friendDecline(loginKey: String) async throws {
        let enc = loginKey.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? loginKey
        let (data, http) = try await jsonRequest("/api/me/friend-requests/\(enc)/decline", method: "POST", body: Data("{}".utf8), auth: true)
        try jsonVoid(data: data, http: http)
    }

    func friendRequestCancel(loginKey: String) async throws {
        let enc = loginKey.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? loginKey
        let (data, http) = try await jsonRequest("/api/me/friend-requests/\(enc)", method: "DELETE", auth: true)
        try jsonVoid(data: data, http: http)
    }

    func postLikeToggle(loginKey: String) async throws {
        let body = try encoder.encode(LoginKeyBody(loginKey: loginKey))
        let (data, http) = try await jsonRequest("/api/me/likes", method: "POST", body: body, auth: true)
        try jsonVoid(data: data, http: http)
    }

    /// `days` — объект «день → поля», как в `api.js` / `cloudSync.js` (`Record<string, day>`).
    func putProgress(calendarId: String, days: [String: ProgressDayPayload]) async throws {
        let body = try encoder.encode(ProgressPutBody(days: days))
        let enc = calendarId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? calendarId
        let (data, http) = try await jsonRequest("/api/progress/\(enc)", method: "PUT", body: body, auth: true)
        try jsonVoid(data: data, http: http)
    }

    func putArchive(calendarId: String, completed: Int) async throws {
        let body = try encoder.encode(ArchivePutBody(completed: completed))
        let enc = calendarId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? calendarId
        let (data, http) = try await jsonRequest("/api/archive/\(enc)", method: "PUT", body: body, auth: true)
        try jsonVoid(data: data, http: http)
    }

    func fetchBoard(calendarId: String) async throws -> AnyCodableJSON {
        let enc = calendarId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? calendarId
        let (data, http) = try await jsonRequest("/api/board/\(enc)", method: "GET", auth: true)
        return try jsonAny(data: data, http: http)
    }

    func fetchBoardDecoded(calendarId: String) async throws -> BoardAPIResponse {
        let any = try await fetchBoard(calendarId: calendarId)
        let data = try JSONSerialization.data(withJSONObject: any.value, options: [])
        return try decoder.decode(BoardAPIResponse.self, from: data)
    }

    func getNutritionDecoded(day: String) async throws -> NutritionDayResponse {
        let any = try await getNutrition(day: day)
        let data = try JSONSerialization.data(withJSONObject: any.value, options: [])
        return try decoder.decode(NutritionDayResponse.self, from: data)
    }

    func getWordsState() async throws -> AnyCodableJSON {
        let (data, http) = try await jsonRequest("/api/games/words", method: "GET", auth: true)
        return try jsonAny(data: data, http: http)
    }

    func postWordsGuess(_ guess: String) async throws -> AnyCodableJSON {
        let body = try encoder.encode(WordsGuessBody(guess: guess))
        let (data, http) = try await jsonRequest("/api/games/words/guess", method: "POST", body: body, auth: true)
        return try jsonAny(data: data, http: http)
    }

    func getProofEngagement(ownerLoginKey: String, calendarId: String, day: String) async throws -> ProofEngagement {
        let path = proofPath(ownerLoginKey: ownerLoginKey, calendarId: calendarId, day: day) + "/engagement"
        let (data, http) = try await jsonRequest(path, method: "GET", auth: true)
        return try jsonDecode(ProofEngagement.self, data: data, http: http)
    }

    func postProofLikeToggle(ownerLoginKey: String, calendarId: String, day: String) async throws -> ProofLikeResponse {
        let path = proofPath(ownerLoginKey: ownerLoginKey, calendarId: calendarId, day: day) + "/like"
        let (data, http) = try await jsonRequest(path, method: "POST", body: Data("{}".utf8), auth: true)
        return try jsonDecode(ProofLikeResponse.self, data: data, http: http)
    }

    func getProofLikers(ownerLoginKey: String, calendarId: String, day: String, limit: Int?, offset: Int?) async throws -> AnyCodableJSON {
        var q = URLComponents()
        var items: [URLQueryItem] = []
        if let limit { items.append(URLQueryItem(name: "limit", value: String(limit))) }
        if let offset { items.append(URLQueryItem(name: "offset", value: String(offset))) }
        q.queryItems = items.isEmpty ? nil : items
        let qs = q.query.map { "?\($0)" } ?? ""
        let path = proofPath(ownerLoginKey: ownerLoginKey, calendarId: calendarId, day: day) + "/likers" + qs
        let (data, http) = try await jsonRequest(path, method: "GET", auth: true)
        return try jsonAny(data: data, http: http)
    }

    func getProofComments(ownerLoginKey: String, calendarId: String, day: String, limit: Int?, beforeId: Int?) async throws -> AnyCodableJSON {
        var q = URLComponents()
        var items: [URLQueryItem] = []
        if let limit { items.append(URLQueryItem(name: "limit", value: String(limit))) }
        if let beforeId { items.append(URLQueryItem(name: "beforeId", value: String(beforeId))) }
        q.queryItems = items.isEmpty ? nil : items
        let qs = q.query.map { "?\($0)" } ?? ""
        let path = proofPath(ownerLoginKey: ownerLoginKey, calendarId: calendarId, day: day) + "/comments" + qs
        let (data, http) = try await jsonRequest(path, method: "GET", auth: true)
        return try jsonAny(data: data, http: http)
    }

    func getProofCommentsDecoded(ownerLoginKey: String, calendarId: String, day: String, limit: Int?, beforeId: Int?) async throws -> ProofCommentsResponse {
        let any = try await getProofComments(ownerLoginKey: ownerLoginKey, calendarId: calendarId, day: day, limit: limit, beforeId: beforeId)
        let data = try JSONSerialization.data(withJSONObject: any.value, options: [])
        return try decoder.decode(ProofCommentsResponse.self, from: data)
    }

    func postProofComment(ownerLoginKey: String, calendarId: String, day: String, body: String) async throws -> AnyCodableJSON {
        let path = proofPath(ownerLoginKey: ownerLoginKey, calendarId: calendarId, day: day) + "/comments"
        let data = try encoder.encode(ProofCommentBody(body: body))
        let (dataOut, http) = try await jsonRequest(path, method: "POST", body: data, auth: true)
        return try jsonAny(data: dataOut, http: http)
    }

    func postProofCommentDecoded(ownerLoginKey: String, calendarId: String, day: String, body: String) async throws -> ProofCommentPostResponse {
        let any = try await postProofComment(ownerLoginKey: ownerLoginKey, calendarId: calendarId, day: day, body: body)
        let data = try JSONSerialization.data(withJSONObject: any.value, options: [])
        return try decoder.decode(ProofCommentPostResponse.self, from: data)
    }

    private func proofPath(ownerLoginKey: String, calendarId: String, day: String) -> String {
        let o = ownerLoginKey.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ownerLoginKey
        let c = calendarId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? calendarId
        let d = day.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? day
        return "/api/proofs/\(o)/\(c)/\(d)"
    }

    // MARK: - Multipart uploads

    func uploadAvatar(imageData: Data, filename: String = "avatar.jpg", mime: String = "image/jpeg") async throws -> AvatarUploadResponse {
        try await multipartUpload(path: "/api/avatar", fields: [], fileField: "file", fileName: filename, mime: mime, fileData: imageData)
    }

    func uploadMedia(imageData: Data, calendarId: String, day: Int, filename: String, mime: String = "image/jpeg") async throws -> AnyCodableJSON {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        func append(_ s: String) { body.append(s.data(using: .utf8)!) }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"calendarId\"\r\n\r\n\(calendarId)\r\n")
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"day\"\r\n\r\n\(day)\r\n")
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: \(mime)\r\n\r\n")
        body.append(imageData)
        append("\r\n--\(boundary)--\r\n")

        var req = URLRequest(url: url("/api/media"))
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let t = KeychainTokenStore.readToken() {
            req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = body
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return try jsonAny(data: data, http: http)
    }

    private func multipartUpload(
        path: String,
        fields: [(String, String)],
        fileField: String,
        fileName: String,
        mime: String,
        fileData: Data
    ) async throws -> AvatarUploadResponse {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        func append(_ s: String) { body.append(s.data(using: .utf8)!) }
        for (k, v) in fields {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"\(k)\"\r\n\r\n\(v)\r\n")
        }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(fileField)\"; filename=\"\(fileName)\"\r\n")
        append("Content-Type: \(mime)\r\n\r\n")
        body.append(fileData)
        append("\r\n--\(boundary)--\r\n")

        var req = URLRequest(url: url(path))
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let t = KeychainTokenStore.readToken() {
            req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = body
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return try jsonDecode(AvatarUploadResponse.self, data: data, http: http)
    }
}

// MARK: - Request/response DTO (совпадают с api.js)

struct AuthLoginBody: Encodable {
    var login: String
    var password: String
}

struct LoginOnlyBody: Encodable {
    var login: String
}

struct ResetPasswordBody: Encodable {
    var token: String
    var password: String
}

struct TokenBody: Encodable {
    var token: String
}

struct TelegramAuthBody: Encodable {
    var initData: String
    var createIfMissing: Bool
}

struct TelegramLinkBody: Encodable {
    var initData: String
}

struct EmailBody: Encodable {
    var email: String
}

struct LoginKeyBody: Encodable {
    var loginKey: String
}

struct WordsGuessBody: Encodable {
    var guess: String
}

struct ProofCommentBody: Encodable {
    var body: String
}

struct ArchivePutBody: Encodable {
    var completed: Int
}

struct ProgressPutBody: Encodable {
    var days: [String: ProgressDayPayload]
}

struct ProfilePatchBody: Encodable {
    var displayName: String?
    var heightCm: String?
    var weightKg: String?
    var ageYears: String?
    var sex: String?
    var shareBodyStats: Bool?
    var shareProofsLarge: Bool?
    var showInCommunityList: Bool?
    var dailyKcalGoal: Int?
}

struct ProgramVoteBody: Encodable {
    var targetYear: Int
    var targetMonth: Int
    var exerciseIds: [String]
    var level: String
    var startAmounts: [String: Int]?
    var dowOverrides: [String: [String]]?
    var customExercises: [String: CustomExerciseDef]?
}

struct CustomExerciseDef: Encodable {
    var label: String
    var unit: String
    var base: CustomExerciseBase?
    var monthEndMultiplier: Double?
}

struct CustomExerciseBase: Encodable {
    var beginner: Double?
    var intermediate: Double?
    var advanced: Double?
}

struct CustomExercisePostBody: Encodable {
    var id: String
    var exercise: CustomExerciseDef
}

struct NutritionPostBody: Encodable {
    var day: String
    var mealType: String
    var title: String?
    var kcal: Int
}

struct ProgressDayPayload: Encodable {
    var done: Bool?
    var doneAt: String?
    var proofUrl: String?
    var proofType: String?
    var proofCaption: String?
    var tasksDone: [Bool]?
    var completedExerciseAmounts: [String: Double]?
}

struct AuthResponse: Decodable {
    var token: String?
    var user: AuthUser?
}

struct AuthUser: Decodable {
    var login: String?
}

struct AvatarUploadResponse: Decodable {
    var ok: Bool?
    var avatarUrl: String?
    var user: BootstrapUserBlock?
}

struct ProofEngagement: Decodable {
    var likeCount: Int?
    var commentCount: Int?
    var likedByMe: Bool?
}

struct ProofLikeResponse: Decodable {
    var ok: Bool?
    var likeCount: Int?
    var likedByMe: Bool?
}

struct ProofCommentItem: Decodable, Sendable, Identifiable {
    var id: Int
    var body: String
    var createdAt: String
    var authorLoginKey: String
    var authorDisplayName: String
    var authorAvatarUrl: String
}

struct ProofCommentsResponse: Decodable, Sendable {
    var comments: [ProofCommentItem]
    var nextBeforeId: Int?
    var hasMore: Bool?
}

struct ProofCommentPostResponse: Decodable, Sendable {
    var ok: Bool?
    var commentCount: Int?
    var comment: ProofCommentItem?
}

/// Обёртка над `JSONSerialization` для ответов без жёсткой схемы (доска, питание, слова).
struct AnyCodableJSON: @unchecked Sendable {
    let value: Any
    init(_ value: Any) { self.value = value }
}
