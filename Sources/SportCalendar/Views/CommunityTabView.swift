import SwiftUI

private struct CommunityTabsMinYPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = .infinity
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = min(value, nextValue())
    }
}

struct CommunityTabView: View {
    @EnvironmentObject private var appState: AppState
    @State private var search = ""
    @FocusState private var searchFocused: Bool
    @State private var filter: CommunityScopeFilter = .all
    @State private var board: BoardAPIResponse?
    @State private var loadingBoard = false
    @State private var boardError: String?
    @State private var actingKey: String?
    /// Верх сегментов в координатах `communityScroll` (для sticky без скачка при смене оверлей ↔ скролл).
    @State private var scopeTabsMinY: CGFloat = .infinity
    /// Защёлка оверлея: иначе у порога `minY` отскок скролла даёт мигание.
    @State private var scopeTabsOverlayLatch = false

    private var implicitBoardCalendarId: String {
        let keys = (appState.bootstrap.map { Array($0.progress.keys) } ?? []).sorted()
        return MoscowCalendar.defaultCalendarId(keys: keys)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    TabMegaHeader(title: "Сообщество", subtitle: "Вдохновляйся друзьями и не только")
                        .padding(.top, 8)
                        .padding(.bottom, 20)

                    communitySearchField
                    scopeTabsInScroll
                        .padding(.bottom, 16)
                    incomingRequests
                    feedSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
            .coordinateSpace(name: "communityScroll")
            .scrollIndicators(.hidden)
            .background(Color(uiColor: .systemGroupedBackground))
            .overlay(alignment: .top) {
                CommunityScopeTabs(filter: $filter)
                    .padding(.horizontal, 16)
                    .offset(y: scopeTabsOverlayOffsetY)
                    .opacity(scopeTabsShowOverlay ? 1 : 0)
                    .allowsHitTesting(scopeTabsShowOverlay)
                    .accessibilityHidden(!scopeTabsShowOverlay)
            }
            .onPreferenceChange(CommunityTabsMinYPreferenceKey.self) { minY in
                var tx = Transaction()
                tx.disablesAnimations = true
                withTransaction(tx) {
                    // Не пишем в state без изменений — иначе SwiftUI ругается «multiple times per frame» при смене табов/скролле.
                    let yChanged =
                        scopeTabsMinY.isInfinite != minY.isInfinite
                        || (!minY.isInfinite && !scopeTabsMinY.isInfinite && abs(scopeTabsMinY - minY) > 0.5)
                    if yChanged {
                        scopeTabsMinY = minY
                    }
                    guard !minY.isInfinite else { return }
                    let newLatch: Bool = {
                        if minY < 34 { return true }
                        if minY > 50 { return false }
                        return scopeTabsOverlayLatch
                    }()
                    if scopeTabsOverlayLatch != newLatch {
                        scopeTabsOverlayLatch = newLatch
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .task { await loadBoard() }
            .refreshable {
                await appState.refreshBootstrap()
                await loadBoard()
            }
            .navigationDestination(for: String.self) { key in
                if let u = board?.users[key] {
                    CommunityMemberProfileView(loginKey: key, user: u, boardCalendarId: implicitBoardCalendarId)
                        .environmentObject(appState)
                } else {
                    Text("Не удалось открыть профиль.")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// Сегменты в потоке скролла; пока активен оверлей — скрываем (та же позиция задаётся `offset` у копии).
    private var scopeTabsInScroll: some View {
        CommunityScopeTabs(filter: $filter)
            .opacity(scopeTabsShowOverlay ? 0 : 1)
            .accessibilityHidden(scopeTabsShowOverlay)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: CommunityTabsMinYPreferenceKey.self,
                        value: proxy.frame(in: .named("communityScroll")).minY
                    )
                }
            )
    }

    private var scopeTabsShowOverlay: Bool {
        scopeTabsOverlayLatch
    }

    /// Пока табы «заехали» выше кромки (`minY < 0`), держим у верха; при возврате в зону 0…порог — двигаем вместе с контентом без скачка.
    private var scopeTabsOverlayOffsetY: CGFloat {
        if scopeTabsMinY < 0 { return 0 }
        return scopeTabsMinY
    }

    // MARK: - Поиск (как `.comm-search` на вебе: 52pt, капсула, центр «Поиск»)

    private var communitySearchField: some View {
        let showCenteredChrome = search.isEmpty && !searchFocused
        return ZStack {
            TextField("", text: $search, prompt: Text(""))
                .font(.body)
                .multilineTextAlignment(showCenteredChrome ? .center : .leading)
                .focused($searchFocused)
                .frame(minHeight: ProfileChrome.profileBarFixedHeight, maxHeight: ProfileChrome.profileBarFixedHeight)
                .padding(.horizontal, 16)
                .accessibilityLabel("Поиск по имени или логину")
            #if os(iOS)
                .textInputAutocapitalization(.never)
            #endif

            if showCenteredChrome {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("Поиск")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .allowsHitTesting(false)
            }
        }
        .background(
            Capsule()
                .fill(ProfileChrome.groupedContentSurface)
        )
        .padding(.bottom, 12)
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
                RoundedRectangle(cornerRadius: ProfileChrome.radiusXl, style: .continuous)
                    .fill(ProfileChrome.groupedContentSurface)
            )
            .padding(.bottom, 16)
        }
    }

    private var feedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if loadingBoard {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            if let boardError {
                Text(boardError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            let rows = filteredRows()
            if rows.isEmpty && !loadingBoard {
                Text(search.isEmpty ? "Пока никого нет в ленте." : "Никого не найдено.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(rows, id: \.key) { row in
                NavigationLink(value: row.key) {
                    communityRow(row)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func communityRow(_ row: (key: String, user: BoardUserPublic)) -> some View {
        let selfKey = appState.bootstrap.map { CommunityLoginKey.from(login: $0.user.login) }
        let isSelf = selfKey == row.key
        let proofs = CommunityProofItem.galleryDisplayList(
            CommunityProofsMerge.mergedProofs(
                server: row.user.communityProofs,
                bootstrap: appState.bootstrap,
                loginKey: row.key,
                selfLoginKey: selfKey
            )
        )
        let thumbs = Array(proofs.prefix(4))
        let workouts = max(0, row.user.totalWorkoutsLifetime ?? 0)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    avatar(url: row.user.avatarUrl ?? "", vip: row.user.vipActive == true)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(row.user.displayName ?? row.user.login ?? row.key)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)
                            if isSelf {
                                Text("(вы)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text("Всего тренировок: \(workouts)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(RussianCommunityCopy.respectPhrase(count: row.user.likeCount ?? 0))
                            .font(.caption2)
                            .foregroundStyle(Color(red: ProfileChrome.accentBlue.red, green: ProfileChrome.accentBlue.green, blue: ProfileChrome.accentBlue.blue))
                    }
                }
                Spacer(minLength: 8)
                if !isSelf {
                    Button {
                        Task { await toggleLike(key: row.key) }
                    } label: {
                        Image(systemName: row.user.likedByMe == true ? "hand.thumbsup.fill" : "hand.thumbsup")
                            .font(.title3)
                            .foregroundStyle(row.user.likedByMe == true ? Color(red: ProfileChrome.primary.red, green: ProfileChrome.primary.green, blue: ProfileChrome.primary.blue) : .secondary)
                    }
                    .disabled(actingKey != nil)
                    .buttonStyle(.plain)
                }
            }
            if !thumbs.isEmpty {
                HStack(spacing: 6) {
                    ForEach(Array(thumbs.enumerated()), id: \.offset) { _, p in
                        proofSlotThumb(p)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ProfileChrome.radiusXl, style: .continuous)
                .fill(ProfileChrome.groupedContentSurface)
        )
        .padding(.bottom, 8)
    }

    private func proofSlotThumb(_ proof: CommunityProofItem) -> some View {
        Group {
            if let s = proof.proofUrl, let u = URL(string: s) {
                if proof.isVideo {
                    ZStack {
                        Color.black.opacity(0.12)
                        Image(systemName: "play.fill")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    AsyncImage(url: u) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFill()
                        default:
                            Color(uiColor: .tertiarySystemFill)
                        }
                    }
                }
            } else {
                Color(uiColor: .tertiarySystemFill)
            }
        }
        .frame(width: 56, height: 56)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
        let incomingKeys = Set((appState.bootstrap?.friendRequests.incoming ?? []).map(\.loginKey))
        let sessionKey = appState.bootstrap.map { CommunityLoginKey.from(login: $0.user.login) } ?? ""
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        var out: [(key: String, user: BoardUserPublic)] = users.map { (key: $0.key, user: $0.value) }

        switch filter {
        case .friends:
            out = out.filter { fav.contains($0.key) }
        case .all:
            out = out.filter { !incomingKeys.contains($0.key) }
        }

        if q.isEmpty, filter == .all {
            out = out.filter { pair in
                pair.user.showInCommunityList != false || (!sessionKey.isEmpty && pair.key == sessionKey)
            }
        }

        if !q.isEmpty {
            out = out.filter { pair in
                let name = (pair.user.displayName ?? "").lowercased()
                let login = (pair.user.login ?? "").lowercased()
                let key = pair.key.lowercased()
                return name.contains(q) || login.contains(q) || key.contains(q)
            }
        }

        out = CommunityFeedOrdering.leaderboardSort(rows: out)
        out = CommunityFeedOrdering.selfFirst(rows: out, selfLogin: appState.bootstrap?.user.login)
        return out
    }

    private func loadBoard() async {
        loadingBoard = true
        boardError = nil
        defer { loadingBoard = false }
        let cal = implicitBoardCalendarId
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

    private func toggleLike(key: String) async {
        actingKey = key
        defer { actingKey = nil }
        do {
            try await APIClient.shared.postLikeToggle(loginKey: key)
            await appState.refreshBootstrap()
            await loadBoard()
        } catch {}
    }
}
