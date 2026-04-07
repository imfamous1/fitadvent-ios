import Foundation

struct APIErrorResponse: Decodable {
    var error: String?
    var fieldErrors: [String: String]?
}

struct APIClientError: LocalizedError {
    var statusCode: Int
    var message: String
    var fieldErrors: [String: String]?

    var errorDescription: String? { message }
}
