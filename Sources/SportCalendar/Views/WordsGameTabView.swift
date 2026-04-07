import SwiftUI

struct WordsGameTabView: View {
    @State private var guess = ""
    @State private var stateText = "—"
    @State private var loading = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Состояние") {
                    Text(stateText)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
                Section("Попытка") {
                    TextField("Слово", text: $guess)
#if os(iOS)
                        .textInputAutocapitalization(.never)
#endif
                    Button("Отправить guess") { Task { await sendGuess() } }
                        .disabled(loading || guess.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                Section {
                    Button("Обновить состояние") { Task { await loadState() } }
                        .disabled(loading)
                }
            }
            .navigationTitle("Слова")
            .task { await loadState() }
        }
    }

    private func loadState() async {
        loading = true
        defer { loading = false }
        do {
            let j = try await APIClient.shared.getWordsState()
            stateText = jsonPretty(j.value)
        } catch let e as APIClientError {
            stateText = e.message
        } catch {
            stateText = error.localizedDescription
        }
    }

    private func sendGuess() async {
        loading = true
        defer { loading = false }
        do {
            let j = try await APIClient.shared.postWordsGuess(guess)
            stateText = jsonPretty(j.value)
        } catch let e as APIClientError {
            stateText = e.message
        } catch {
            stateText = error.localizedDescription
        }
    }

    private func jsonPretty(_ any: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: any, options: [.prettyPrinted]),
              let s = String(data: data, encoding: .utf8) else { return "\(any)" }
        return s
    }
}
