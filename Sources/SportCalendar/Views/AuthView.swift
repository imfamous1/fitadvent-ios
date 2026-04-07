import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var appState: AppState
    @State private var login = ""
    @State private var password = ""
    @State private var busy = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Логин", text: $login)
#if os(iOS)
                        .textInputAutocapitalization(.never)
#endif
                        .autocorrectionDisabled()
                    SecureField("Пароль", text: $password)
                }
                Section {
                    Button("Войти") { Task { await submitLogin() } }
                        .disabled(!canSubmit || busy)
                    Button("Регистрация") { Task { await submitRegister() } }
                        .disabled(!canSubmit || busy)
                }
                if let message {
                    Section {
                        Text(message)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Sport Calendar")
            .overlay {
                if busy { ProgressView().scaleEffect(1.2) }
            }
        }
    }

    private var canSubmit: Bool {
        login.count >= 2 && password.count >= 4
    }

    private func submitLogin() async {
        busy = true
        message = nil
        defer { busy = false }
        do {
            _ = try await APIClient.shared.login(login: login, password: password)
            appState.sessionDidRestore()
            await appState.refreshBootstrap()
        } catch let e as APIClientError {
            message = e.message
        } catch {
            message = error.localizedDescription
        }
    }

    private func submitRegister() async {
        busy = true
        message = nil
        defer { busy = false }
        do {
            _ = try await APIClient.shared.register(login: login, password: password)
            appState.sessionDidRestore()
            await appState.refreshBootstrap()
        } catch let e as APIClientError {
            message = e.message
        } catch {
            message = error.localizedDescription
        }
    }
}
