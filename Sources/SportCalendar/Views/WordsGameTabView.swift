import SwiftUI

struct WordsGameTabView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @FocusState private var inputFocused: Bool
    @State private var guess = ""
    @State private var gameState: WordsGameState?
    @State private var formFeedback = ""
    @State private var isFormError = false
    @State private var loading = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerBlock
                    boardCard
                    controlsCard
                    Text("Как играть")
                        .font(.headline.weight(.bold))
                        .padding(.leading, 8)
                    rulesCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Слова")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Закрыть")
                }
            }
            .task { await loadState() }
        }
    }

    private var headerBlock: some View {
        let status = gameState?.status ?? .playing
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text("Слово дня")
                    .font(.title3.weight(.bold))
                if status == .won {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .accessibilityHidden(true)
                }
            }
            Text(statusTitle(status))
                .font(.subheadline)
                .foregroundStyle(statusColor(status))
        }
        .padding(.leading, ProfileChrome.exerciseSectionTitleLeading)
    }

    private var boardCard: some View {
        VStack(spacing: 12) {
            ForEach(renderRows, id: \.id) { row in
                HStack(spacing: 8) {
                    ForEach(row.cells, id: \.id) { cell in
                        tileView(cell)
                    }
                }
            }
            Text("Осталось попыток: \(gameState?.attemptsLeft ?? WordsGameState.maxAttempts)")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: ProfileChrome.radiusXl, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: ProfileChrome.radiusXl, style: .continuous)
                .stroke(Color.primary.opacity(0.07), lineWidth: 1)
        )
    }

    private var controlsCard: some View {
        let status = gameState?.status ?? .playing
        let playable = status == .playing
        return VStack(alignment: .leading, spacing: 10) {
            TextField("Ваш вариант", text: $guess)
                .textInputAutocapitalization(.characters)
                .disableAutocorrection(true)
                .focused($inputFocused)
                .onChange(of: guess) { _, newValue in
                    guess = normalizeGuessInput(newValue)
                }
                .frame(minHeight: ProfileChrome.profileBarFixedHeight, maxHeight: ProfileChrome.profileBarFixedHeight)
                .padding(.horizontal, 16)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                )
                .disabled(!playable || loading)

            Button {
                Task { await sendGuess() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 15, weight: .semibold))
                    if loading {
                        ProgressView()
                            .tint(.white)
                    }
                    Text("Проверить")
                        .font(.body.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color(red: ProfileChrome.primary.red, green: ProfileChrome.primary.green, blue: ProfileChrome.primary.blue))
                )
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(!playable || loading || guess.count != 5)

            if !formFeedback.isEmpty {
                Text(formFeedback)
                    .font(.footnote)
                    .foregroundStyle(isFormError ? .red : .green)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ProfileChrome.radiusXl, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }

    private var rulesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("6 попыток, 5 букв из словаря игры. Слово дня меняется в полночь по Москве.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                tileDemo("К", kind: .correct)
                tileDemo("Л", kind: .present)
                tileDemo("О", kind: .absent)
            }
            Text("Зелёный — буква на месте, жёлтый — буква есть в слове, серый — буквы нет.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ProfileChrome.radiusXl, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }

    private func tileDemo(_ ch: String, kind: WordsTile) -> some View {
        tileView(.init(id: UUID().uuidString, letter: ch, state: kind))
    }

    private func tileView(_ cell: WordsBoardCell) -> some View {
        let colors = tileColors(cell.state)
        return Text(cell.letter)
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(colors.fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(colors.border, lineWidth: 1)
            )
            .foregroundStyle(colors.text)
    }

    private var renderRows: [WordsBoardRow] {
        let guesses = gameState?.guesses ?? []
        var rows: [WordsBoardRow] = guesses.enumerated().map { idx, g in
            let letters = Array(g.guess)
            let tiles = g.tiles
            let cells = (0 ..< 5).map { pos in
                let ch = pos < letters.count ? String(letters[pos]) : ""
                let t = pos < tiles.count ? tiles[pos] : .absent
                return WordsBoardCell(id: "\(idx)-\(pos)", letter: ch, state: t)
            }
            return WordsBoardRow(id: "g-\(idx)", cells: cells)
        }

        if guesses.count < WordsGameState.maxAttempts {
            let inputChars = Array(guess)
            let inputRow = (0 ..< 5).map { pos in
                let ch = pos < inputChars.count ? String(inputChars[pos]) : ""
                return WordsBoardCell(id: "i-\(pos)", letter: ch, state: .pending)
            }
            rows.append(WordsBoardRow(id: "input", cells: inputRow))
        }

        while rows.count < WordsGameState.maxAttempts {
            let rowIdx = rows.count
            let empty = (0 ..< 5).map { pos in
                WordsBoardCell(id: "e-\(rowIdx)-\(pos)", letter: "", state: .pending)
            }
            rows.append(WordsBoardRow(id: "e-\(rowIdx)", cells: empty))
        }

        return rows
    }

    private func tileColors(_ state: WordsTile) -> (fill: Color, border: Color, text: Color) {
        switch state {
        case .correct:
            return (Color(red: 0.19, green: 0.66, blue: 0.35), Color.clear, .white)
        case .present:
            return (Color(red: 0.80, green: 0.66, blue: 0.20), Color.clear, .white)
        case .absent:
            return (Color(uiColor: .systemGray), Color.clear, .white)
        case .pending:
            return (Color(uiColor: .tertiarySystemGroupedBackground), Color.primary.opacity(0.08), .primary)
        }
    }

    private func statusTitle(_ status: WordsStatus) -> String {
        switch status {
        case .playing:
            return "Введите слово из 5 букв"
        case .won:
            return "Угадали! Отличный ход."
        case .lost:
            return "Попытки закончились. Завтра будет новое слово."
        }
    }

    private func statusColor(_ status: WordsStatus) -> Color {
        switch status {
        case .playing: return .secondary
        case .won: return .green
        case .lost: return .secondary
        }
    }

    private func loadState() async {
        loading = true
        defer { loading = false }
        do {
            let response = try await APIClient.shared.getWordsState()
            let next = try decodeWordsState(from: response)
            gameState = next
            formFeedback = ""
            isFormError = false
            if next.status == .won {
                await appState.refreshBootstrap()
            }
        } catch let e as APIClientError {
            formFeedback = e.message
            isFormError = true
        } catch {
            formFeedback = error.localizedDescription
            isFormError = true
        }
    }

    private func sendGuess() async {
        let raw = normalizeGuessInput(guess)
        guard raw.count == 5 else {
            formFeedback = "Нужно ровно 5 букв."
            isFormError = true
            return
        }

        loading = true
        defer { loading = false }
        do {
            let response = try await APIClient.shared.postWordsGuess(raw)
            let next = try decodeWordsState(from: response)
            gameState = next
            guess = ""
            isFormError = false
            if next.status == .won {
                formFeedback = "Победа! +\(next.xpAwarded ?? next.xpPerWin ?? 0) XP."
                inputFocused = false
                await appState.refreshBootstrap()
            } else if next.status == .lost {
                formFeedback = "Попытки закончились. Приходите завтра."
                inputFocused = false
            } else {
                formFeedback = ""
                inputFocused = true
            }
        } catch let e as APIClientError {
            formFeedback = humanizeWordsError(e.message)
            isFormError = true
        } catch {
            formFeedback = error.localizedDescription
            isFormError = true
        }
    }

    private func decodeWordsState(from response: AnyCodableJSON) throws -> WordsGameState {
        let data = try JSONSerialization.data(withJSONObject: response.value, options: [])
        return try JSONDecoder().decode(WordsGameState.self, from: data)
    }

    private func normalizeGuessInput(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: "Ё", with: "Е")
            .filter { ch in
                ("А" ... "Я").contains(String(ch))
            }
            .prefix(5)
            .map(String.init)
            .joined()
    }

    private func humanizeWordsError(_ message: String) -> String {
        if message.contains("уже вводили") {
            return "Это слово уже пробовали. Введите другое."
        }
        return message
    }
}

private struct WordsGameState: Decodable {
    static let maxAttempts = 6
    var status: WordsStatus
    var guesses: [WordsGuessRow]
    var attemptsLeft: Int
    var xpPerWin: Int?
    var xpAwarded: Int?
}

private struct WordsGuessRow: Decodable {
    var guess: String
    var tiles: [WordsTile]
}

private enum WordsStatus: String, Decodable {
    case playing
    case won
    case lost
}

private enum WordsTile: String, Decodable {
    case correct
    case present
    case absent
    case pending
}

private struct WordsBoardRow: Identifiable {
    var id: String
    var cells: [WordsBoardCell]
}

private struct WordsBoardCell: Identifiable {
    var id: String
    var letter: String
    var state: WordsTile
}
