import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var bootstrap: BootstrapResponse?
    @Published var isLoading = false
    @Published var lastError: String?
    @Published var isLoggedIn: Bool

    init() {
        isLoggedIn = KeychainTokenStore.readToken() != nil
        bootstrap = BootstrapCache.loadDecoded()
    }

    func refreshBootstrap() async {
        guard KeychainTokenStore.readToken() != nil else {
            bootstrap = nil
            BootstrapCache.clear()
            isLoggedIn = false
            return
        }
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        do {
            let b = try await APIClient.shared.bootstrap()
            bootstrap = b
            if let data = try? JSONEncoder().encode(b) {
                BootstrapCache.save(data)
            }
            isLoggedIn = true
        } catch let e as APIClientError {
            lastError = e.message
            if e.statusCode == 401 {
                await APIClient.shared.logout()
                bootstrap = nil
                BootstrapCache.clear()
                isLoggedIn = false
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func logout() async {
        await APIClient.shared.logout()
        bootstrap = nil
        BootstrapCache.clear()
        isLoggedIn = false
        lastError = nil
    }

    func sessionDidRestore() {
        isLoggedIn = KeychainTokenStore.readToken() != nil
    }
}
