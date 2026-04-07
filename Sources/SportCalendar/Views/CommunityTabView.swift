import SwiftUI

struct CommunityTabView: View {
    @EnvironmentObject private var appState: AppState
    @State private var search = ""
    @State private var filter: CommFilter = .all
    @State private var board: BoardAPIResponse?
    @State private var boardCalendarId = ""
    @State private var loadingBoard = false
    @State private var boardError: String?
    @State private var actingKey: String?

    private enum CommFilter: String, CaseIterable {
        case all = "Все"
        case favorites = "Избранное"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    TabMegaHeader(title: "Сообщество", subtitle: "Вдохновляйся друзьями и не только")
                        .padding(.bottom, 12)

                    searchField
                    filterPicker
                    incomingRequests
                    boardSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .task { await loadBoard() }
            .refreshable {
                await appState.refreshBootstrap()
                await loadBoard()
            }
        }
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Поиск по имени или логину", text: $search)
            #if os(iOS)
                .textInputAutocapitalization(.never)
            #endif
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .padding(.bottom, 12)
    }

    private var filterPicker: some View {
        Picker("Фильтр", selection: $filter) {
            ForEach(CommFilter.allCases, id: \.self) { f in
                Text(f.rawValue).tag(f)
            }
        }
        .pickerStyle(.segmented)
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private var incomingRequests: some View {
        let incoming = appState.bootstrap?.friendRequests.incoming ?? []
        if !incoming.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("Заявки в друзья")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(incoming, id: \.loginKey) { req in
                    HStack(spacing: 12) {
                        avatar(url: req.avatarUrl, vip: req.vipActive == true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(req.displayName)
                                .font(.body.weight(.semibold))
                            Text(req.loginKey)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Принять") {
                            Task { await acceptFriend(req.loginKey) }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(red: ProfileChrome.primary.red, green: ProfileChrome.primary.green, blue: ProfileChrome.primary.blue))
                        .disabled(actingKey != nil)
                        Button("Отклонить") {
                            Task { await declineFriend(req.loginKey) }
                        }
                        .buttonStyle(.bordered)
                        .disabled(actingKey != nil)
                    }
                    .padding(.vertical, 8)
                    Divider()
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
            .padding(.bottom, 16)
        }
    }

    private var boardCalendarOptions: [String] {
        let keys = (appState.bootstrap.map { Array($0.progress.keys) } ?? []).sorted()
        var opts = Set(keys)
        opts.insert(MoscowCalendar.defaultCalendarId(keys: keys))
        opts.insert(boardCalendarId)
        return opts.sorted()
    }

    private var boardSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Календарь ленты")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Picker("Календарь", selection: $boardCalendarId) {
                ForEach(boardCalendarOptions, id: \.self) { id in
                    Text(id).tag(id)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: boardCalendarId) { _, _ in Task { await loadBoard() } }
            HStack {
                Text("Лента")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if loadingBoard {
                    ProgressView()
                }
            }
            if let boardError {
                Text(boardError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            let rows = filteredRows()
            if rows.isEmpty && !loadingBoard {
                Text(search.isEmpty ? "Пока никого нет в ленте для выбранного календаря." : "Никого не найдено.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(rows, id: \.key) { row in
                communityRow(row)
            }
        }
    }

    private func communityRow(_ row: (key: String, user: BoardUserPublic)) -> some View {
        let fav = appState.bootstrap?.favoriteLoginKeys.contains(row.key) == true
        let liked = row.user.likedByMe == true
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                avatar(url: row.user.avatarUrl ?? "", vip: row.user.vipActive == true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.user.displayName ?? row.user.login ?? row.key)
                        .font(.body.weight(.semibold))
                    HStack(spacing: 8) {
                        if let lvl = row.user.athleteLevel {
                            Text("Ур. \(lvl)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let tw = row.user.totalWorkoutsLifetime {
                            Text("· \(tw) трен.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text("\(row.user.likeCount ?? 0) респектов")
                        .font(.caption2)
                        .foregroundStyle(Color(red: ProfileChrome.accentBlue.red, green: ProfileChrome.accentBlue.green, blue: ProfileChrome.accentBlue.blue))
                }
                Spacer()
                VStack(spacing: 8) {
                    Button {
                        Task { await toggleFavorite(key: row.key, isFav: fav) }
                    } label: {
                        Image(systemName: fav ? "star.fill" : "star")
                            .foregroundStyle(fav ? .yellow : .secondary)
                    }
                    .disabled(actingKey != nil)
                    Button {
                        Task { await toggleLike(key: row.key, liked: liked) }
                    } label: {
                        Image(systemName: liked ? "hand.thumbsup.fill" : "hand.thumbsup")
                            .foregroundStyle(liked ? Color(red: ProfileChrome.primary.red, green: ProfileChrome.primary.green, blue: ProfileChrome.primary.blue) : .secondary)
                    }
                    .disabled(actingKey != nil)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .padding(.bottom, 8)
    }

    private func avatar(url: String, vip: Bool) -> some View {
        ZStack {
            if let u = URL(string: url), !url.isEmpty {
                AsyncImage(url: u) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        Image(systemName: "person.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Image(systemName: "person.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(vip ? Color.orange : Color.clear, lineWidth: 2)
        )
    }

    private func filteredRows() -> [(key: String, user: BoardUserPublic)] {
        guard let users = board?.users else { return [] }
        let fav = Set(appState.bootstrap?.favoriteLoginKeys ?? [])
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var out: [(key: String, user: BoardUserPublic)] = users.map { (key: $0.key, user: $0.value) }
        if filter == .favorites {
            out = out.filter { fav.contains($0.key) }
        }
        if !q.isEmpty {
            out = out.filter { pair in
                let name = (pair.user.displayName ?? "").lowercased()
                let login = (pair.user.login ?? "").lowercased()
                let key = pair.key.lowercased()
                return name.contains(q) || login.contains(q) || key.contains(q)
            }
        }
        out.sort { a, b in
            let na = a.user.displayName ?? a.key
            let nb = b.user.displayName ?? b.key
            return na.localizedCaseInsensitiveCompare(nb) == .orderedAscending
        }
        return out
    }

    private func loadBoard() async {
        let keys = (appState.bootstrap.map { Array($0.progress.keys) } ?? []).sorted()
        let cal = boardCalendarId.isEmpty ? MoscowCalendar.defaultCalendarId(keys: keys) : boardCalendarId
        if boardCalendarId.isEmpty { boardCalendarId = cal }
        loadingBoard = true
        boardError = nil
        defer { loadingBoard = false }
        do {
            board = try await APIClient.shared.fetchBoardDecoded(calendarId: cal)
        } catch let e as APIClientError {
            boardError = e.message
            board = nil
        } catch {
            boardError = error.localizedDescription
            board = nil
        }
    }

    private func acceptFriend(_ key: String) async {
        actingKey = key
        defer { actingKey = nil }
        do {
            try await APIClient.shared.friendAccept(loginKey: key)
            await appState.refreshBootstrap()
            await loadBoard()
        } catch {}
    }

    private func declineFriend(_ key: String) async {
        actingKey = key
        defer { actingKey = nil }
        do {
            try await APIClient.shared.friendDecline(loginKey: key)
            await appState.refreshBootstrap()
            await loadBoard()
        } catch {}
    }

    private func toggleFavorite(key: String, isFav: Bool) async {
        actingKey = key
        defer { actingKey = nil }
        do {
            if isFav {
                try await APIClient.shared.deleteFavorite(loginKey: key)
            } else {
                try await APIClient.shared.postFavorite(loginKey: key)
            }
            await appState.refreshBootstrap()
            await loadBoard()
        } catch {}
    }

    private func toggleLike(key: String, liked: Bool) async {
        actingKey = key
        defer { actingKey = nil }
        do {
            try await APIClient.shared.postLikeToggle(loginKey: key)
            await appState.refreshBootstrap()
            await loadBoard()
        } catch {}
    }
}
