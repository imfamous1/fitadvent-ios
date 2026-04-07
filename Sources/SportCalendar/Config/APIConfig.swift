import Foundation

/// Базовый URL API без суффикса `/api` (см. `sport-calendar-web/docs/IOS_AGENT_PROMPT.md`).
enum APIConfig {
    private static let plistKey = "API_BASE_URL"

    static var baseURL: String {
        if let url = readFromPlist(), !url.isEmpty {
            return normalize(url)
        }
        if let env = ProcessInfo.processInfo.environment["API_BASE_URL"], !env.isEmpty {
            return normalize(env)
        }
        return "http://127.0.0.1:8787"
    }

    private static func readFromPlist() -> String? {
        guard let url = Bundle.main.url(forResource: "Config", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let obj = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let dict = obj as? [String: Any],
              let s = dict[plistKey] as? String
        else { return nil }
        return s
    }

    private static func normalize(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        while t.hasSuffix("/") { t.removeLast() }
        if t.lowercased().hasSuffix("/api") {
            t = String(t.dropLast(4))
            while t.hasSuffix("/") { t.removeLast() }
        }
        return t
    }
}
