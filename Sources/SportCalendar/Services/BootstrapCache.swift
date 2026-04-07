import Foundation

/// Кэш последнего `bootstrap` (UserDefaults), как в `IOS_AGENT_PROMPT.md` §5.
enum BootstrapCache {
    private static let key = "sport_calendar.bootstrap.json"

    static func save(_ data: Data) {
        UserDefaults.standard.set(data, forKey: key)
    }

    static func load() -> Data? {
        UserDefaults.standard.data(forKey: key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    static func loadDecoded() -> BootstrapResponse? {
        guard let load = load() else { return nil }
        return try? JSONDecoder().decode(BootstrapResponse.self, from: load)
    }
}
