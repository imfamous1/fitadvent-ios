import Foundation
import Security

/// Хранение JWT в Keychain (аналог `TOKEN_KEY` в `api.js`, без открытого хранения в UserDefaults).
enum KeychainTokenStore {
    private static let service = "sport.calendar.suite.api"
    private static let account = "auth.jwt"

    static func readToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        guard status == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func saveToken(_ token: String?) {
        if let token, let data = token.data(using: .utf8) {
            SecItemDelete(baseQuery() as CFDictionary)
            var q = baseQuery()
            q[kSecValueData as String] = data
            q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(q as CFDictionary, nil)
        } else {
            SecItemDelete(baseQuery() as CFDictionary)
        }
    }

    private static func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
