import AVKit
import SwiftUI

private struct CommunityProofLightboxRoute: Identifiable {
    var id: String { "\(index)" }
    let index: Int
}

/// Экран профиля участника сообщества (аналог `openProfileModal` на вебе).
struct CommunityMemberProfileView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let loginKey: String
    let user: BoardUserPublic
    let boardCalendarId: String

    @State private var acting = false
    @State private var lightbox: CommunityProofLightboxRoute?

    private var isSelf: Bool {
        guard let me = appState.bootstrap?.user.login else { return false }
        return CommunityLoginKey.from(login: me) == loginKey
    }

    private var isFriend: Bool {
        appState.bootstrap?.favoriteLoginKeys.contains(loginKey) == true
    }

    private var isIncomingRequest: Bool {
        appState.bootstrap?.friendRequests.incoming.contains { $0.loginKey == loginKey } == true
    }

    private var isOutgoingRequest: Bool {
        appState.bootstrap?.friendRequests.outgoingLoginKeys.contains(loginKey) == true
    }

    private var canShowBody: Bool {
        isSelf || user.shareBodyStats == true || isFriend
    }

    private var canEnlargeProofs: Bool {
        isSelf || user.shareProofsLarge == true || isFriend
    }

    private var mergedProofs: [CommunityProofItem] {
        let selfKey = appState.bootstrap.map { CommunityLoginKey.from(login: $0.user.login) }
        return CommunityProofsMerge.mergedProofs(
            server: user.communityProofs,
            bootstrap: appState.bootstrap,
            loginKey: loginKey,
            selfLoginKey: selfKey
        )
    }

    private var monthWorkoutCount: Int {
        guard let days = user.days else { return 0 }
        return days.values.filter { CommunityProgressRules.dayCountsAsWorkoutBoard($0) }.count
    }

    private var monthDaysTotal: Int {
        MoscowCalendar.daysInMonth(calendarId: boardCalendarId)
    }

    private var monthProgressPhrase: String {
        let title = MoscowCalendar.monthTitle(calendarId: boardCalendarId)
        return "в \(title.lowercased())"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                whoBlock
                xpBlock
                if !mergedProofs.isEmpty, !canEnlargeProofs, !isSelf {
                    Text("Увеличение фото отключено в настройках профиля участника.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                proofsSection
                monthProgressSection
                programSection
                anketaSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.backward")
                        .font(.body.weight(.semibold))
                }
                .accessibilityLabel("Назад")
            }
            ToolbarItem(placement: .topBarTrailing) {
                friendToolbarContent
            }
        }
        .fullScreenCover(item: $lightbox) { route in
            CommunityProofLightboxView(
                ownerLoginKey: loginKey,
                proofs: mergedProofs,
                startIndex: route.index,
                canInteract: true
            )
            .environmentObject(appState)
        }
    }

    @ViewBuilder
    private var friendToolbarContent: some View {
        if isSelf {
            EmptyView()
        } else if isIncomingRequest {
            HStack(spacing: 8) {
                Button {
                    Task { await acceptIncoming() }
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                }
                .disabled(acting)
                Button {
                    Task { await declineIncoming() }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .disabled(acting)
            }
        } else if isOutgoingRequest {
            Button {
                Task { await cancelOutgoing() }
            } label: {
                Image(systemName: "clock.badge.xmark")
            }
            .disabled(acting)
        } else if isFriend {
            Button {
                Task { await removeFriend() }
            } label: {
                Image(systemName: "person.crop.circle.badge.minus")
            }
            .disabled(acting)
        } else {
            Button {
                Task { await addFriend() }
            } label: {
                Image(systemName: "person.crop.circle.badge.plus")
            }
            .disabled(acting)
        }
    }

    private var whoBlock: some View {
        HStack(alignment: .top, spacing: 14) {
            communityAvatar(url: user.avatarUrl ?? "", vip: user.vipActive == true, size: 72)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(user.displayName ?? user.login ?? loginKey)
                        .font(.title2.weight(.bold))
                    if isSelf {
                        Text("(вы)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 8) {
                    if user.vipActive == true {
                        Text("Премиум")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.2), in: Capsule())
                    }
                    Text(RussianCommunityCopy.respectPhrase(count: user.likeCount ?? 0))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color(red: ProfileChrome.accentBlue.red, green: ProfileChrome.accentBlue.green, blue: ProfileChrome.accentBlue.blue))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var xpBlock: some View {
        let gam: (level: Int, into: Int, span: Int, pct: Double) = {
            if isSelf, let g = appState.bootstrap?.gamification {
                let lvl = g.level ?? 1
                let into = g.xpIntoLevel ?? 0
                let span = max(1, g.xpSpanThisLevel ?? 1)
                let pct = g.progressPct ?? 0
                return (lvl, into, span, pct)
            }
            let snap = CommunityGamification.compute(
                totalWorkouts: user.totalWorkoutsLifetime ?? 0,
                bonusXp: user.bonusXp ?? 0
            )
            return (snap.level, snap.xpIntoLevel, snap.xpSpanThisLevel, snap.progressPct)
        }()
        VStack(alignment: .leading, spacing: 10) {
            Text("Опыт и прогресс уровня")
                .font(.subheadline.weight(.semibold))
            Text("Уровень \(gam.level) — \(athleteLevelLabel(level: gam.level))")
                .font(.body.weight(.medium))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(uiColor: .tertiarySystemFill))
                    Capsule()
                        .fill(Color(red: ProfileChrome.primary.red, green: ProfileChrome.primary.green, blue: ProfileChrome.primary.blue))
                        .frame(width: max(8, geo.size.width * CGFloat(gam.pct)))
                }
            }
            .frame(height: 10)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Опыт в текущем уровне")
            .accessibilityValue("\(gam.into) из \(gam.span)")
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ProfileChrome.radiusXl, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }

    private var proofsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Фото тренировок")
                    .font(.subheadline.weight(.semibold))
                if !mergedProofs.isEmpty {
                    Text("· \(mergedProofs.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            if mergedProofs.isEmpty {
                Text("Пока нет загруженных фото к дням.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                let cols = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
                LazyVGrid(columns: cols, spacing: 8) {
                    ForEach(Array(mergedProofs.enumerated()), id: \.element.id) { idx, proof in
                        proofThumb(proof, index: idx)
                    }
                }
            }
        }
    }

    private func proofThumb(_ proof: CommunityProofItem, index: Int) -> some View {
        Button {
            if canEnlargeProofs || isSelf {
                lightbox = CommunityProofLightboxRoute(index: index)
            }
        } label: {
            ZStack {
                if let u = proof.proofUrl.flatMap({ URL(string: $0) }) {
                    if proof.isVideo {
                        Color.black.opacity(0.08)
                        Image(systemName: "play.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.primary)
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
            .frame(minHeight: 96)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!canEnlargeProofs && !isSelf)
    }

    private var monthProgressSection: some View {
        let pct = monthDaysTotal > 0 ? min(1, Double(monthWorkoutCount) / Double(monthDaysTotal)) : 0
        return VStack(alignment: .leading, spacing: 10) {
            Text("Тренировочные дни \(monthProgressPhrase)")
                .font(.subheadline.weight(.semibold))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(uiColor: .tertiarySystemFill))
                    Capsule()
                        .fill(Color(red: ProfileChrome.accentBlue.red, green: ProfileChrome.accentBlue.green, blue: ProfileChrome.accentBlue.blue))
                        .frame(width: max(8, geo.size.width * CGFloat(pct)))
                }
            }
            .frame(height: 10)
            Text("\(monthWorkoutCount) из \(monthDaysTotal) дней с тренировкой")
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

    @ViewBuilder
    private var programSection: some View {
        if let mp = user.monthProgram, mp.exerciseIds?.isEmpty == false || mp.level != nil {
            VStack(alignment: .leading, spacing: 8) {
                Text("Программа месяца")
                    .font(.subheadline.weight(.semibold))
                if let lvl = mp.level {
                    Text("Уровень: \(lvl)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let n = mp.exerciseIds?.count, n > 0 {
                    Text("Упражнений в программе: \(n)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: ProfileChrome.radiusXl, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
        }
    }

    @ViewBuilder
    private var anketaSection: some View {
        let h = (user.heightCm ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let w = (user.weightKg ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        VStack(alignment: .leading, spacing: 10) {
            Text("Анкета")
                .font(.subheadline.weight(.semibold))
            if canShowBody {
                if h.isEmpty && w.isEmpty, !isSelf {
                    Text("Рост и вес в профиле не указаны.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if h.isEmpty && w.isEmpty, isSelf {
                    Text("Рост и вес в профиле не указаны.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 16) {
                        if !h.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Рост").font(.caption).foregroundStyle(.secondary)
                                Text("\(h) см").font(.body.weight(.medium))
                            }
                        }
                        if !w.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Вес").font(.caption).foregroundStyle(.secondary)
                                Text("\(w) кг").font(.body.weight(.medium))
                            }
                        }
                    }
                }
            } else {
                Text("Участник не показывает рост и вес незнакомым пользователям.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ProfileChrome.radiusXl, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }

    private func communityAvatar(url: String, vip: Bool, size: CGFloat) -> some View {
        ZStack {
            if let u = URL(string: url), !url.isEmpty {
                AsyncImage(url: u) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        Image(systemName: "person.fill").foregroundStyle(.secondary)
                    }
                }
            } else {
                Image(systemName: "person.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(vip ? Color.orange : Color.clear, lineWidth: vip ? 3 : 0)
        )
    }

    private func addFriend() async {
        acting = true
        defer { acting = false }
        do {
            try await APIClient.shared.postFavorite(loginKey: loginKey)
            await appState.refreshBootstrap()
        } catch {}
    }

    private func removeFriend() async {
        acting = true
        defer { acting = false }
        do {
            try await APIClient.shared.deleteFavorite(loginKey: loginKey)
            await appState.refreshBootstrap()
        } catch {}
    }

    private func acceptIncoming() async {
        acting = true
        defer { acting = false }
        do {
            try await APIClient.shared.friendAccept(loginKey: loginKey)
            await appState.refreshBootstrap()
        } catch {}
    }

    private func declineIncoming() async {
        acting = true
        defer { acting = false }
        do {
            try await APIClient.shared.friendDecline(loginKey: loginKey)
            await appState.refreshBootstrap()
        } catch {}
    }

    private func cancelOutgoing() async {
        acting = true
        defer { acting = false }
        do {
            try await APIClient.shared.friendRequestCancel(loginKey: loginKey)
            await appState.refreshBootstrap()
        } catch {}
    }
}

// MARK: - Лайтбокс отчёта

private struct CommunityProofLightboxView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let ownerLoginKey: String
    let proofs: [CommunityProofItem]
    let startIndex: Int
    var canInteract: Bool = true

    @State private var page: Int = 0
    @State private var engagement: ProofEngagement?
    @State private var engagementLoading = false
    @State private var commentsRoute: ProofCommentsSheetRoute?
    @State private var likeBusy = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            TabView(selection: $page) {
                ForEach(Array(proofs.enumerated()), id: \.offset) { idx, proof in
                    proofPage(proof)
                        .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: proofs.count > 1 ? .automatic : .never))
            .onAppear { page = min(max(0, startIndex), max(0, proofs.count - 1)) }
            .onChange(of: page) { _, new in
                Task { await loadEngagement(for: new) }
            }
            .task {
                await loadEngagement(for: page)
            }

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white)
                    }
                    .padding()
                    Spacer()
                }
                Spacer()
                if canInteract {
                    bottomBar
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding()
                }
            }
        }
        .sheet(item: $commentsRoute) { route in
            ProofCommentsSheetView(
                ownerLoginKey: route.owner,
                calendarId: route.calendarId,
                day: route.day
            )
        }
    }

    private struct ProofCommentsSheetRoute: Identifiable {
        var id: String { "\(owner)|\(calendarId)|\(day)" }
        let owner: String
        let calendarId: String
        let day: String
    }

    @ViewBuilder
    private func proofPage(_ proof: CommunityProofItem) -> some View {
        Group {
            if let s = proof.proofUrl, let u = URL(string: s) {
                if proof.isVideo {
                    VideoPlayer(player: AVPlayer(url: u))
                        .onAppear { }
                } else {
                    AsyncImage(url: u) { phase in
                        switch phase {
                        case .success(let img):
                            img
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        default:
                            ProgressView().tint(.white)
                        }
                    }
                }
            } else {
                Text("Нет файла")
                    .foregroundStyle(.white)
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 20) {
            Button {
                Task { await toggleLike() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: (engagement?.likedByMe == true) ? "hand.thumbsup.fill" : "hand.thumbsup")
                    Text("\(engagement?.likeCount ?? 0)")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.primary)
            }
            .disabled(likeBusy || engagementLoading)

            Button {
                guard let p = proofs[safe: page] else { return }
                commentsRoute = ProofCommentsSheetRoute(
                    owner: ownerLoginKey,
                    calendarId: p.calendarId,
                    day: p.day
                )
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.left.and.bubble.right")
                    Text("\(engagement?.commentCount ?? 0)")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.primary)
            }
            Spacer(minLength: 0)
        }
    }

    private func loadEngagement(for index: Int) async {
        guard proofs.indices.contains(index) else { return }
        let p = proofs[index]
        engagementLoading = true
        defer { engagementLoading = false }
        do {
            engagement = try await APIClient.shared.getProofEngagement(
                ownerLoginKey: ownerLoginKey,
                calendarId: p.calendarId,
                day: p.day
            )
        } catch {
            engagement = nil
        }
    }

    private func toggleLike() async {
        guard proofs.indices.contains(page) else { return }
        let p = proofs[page]
        likeBusy = true
        defer { likeBusy = false }
        do {
            _ = try await APIClient.shared.postProofLikeToggle(
                ownerLoginKey: ownerLoginKey,
                calendarId: p.calendarId,
                day: p.day
            )
            await loadEngagement(for: page)
        } catch {}
    }
}

// MARK: - Комментарии к отчёту

private struct ProofCommentsSheetView: View {
    @Environment(\.dismiss) private var dismiss

    let ownerLoginKey: String
    let calendarId: String
    let day: String

    @State private var items: [ProofCommentItem] = []
    @State private var loading = true
    @State private var draft = ""
    @State private var sending = false
    @State private var beforeId: Int?
    @State private var hasMore = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if loading && items.isEmpty {
                    ProgressView().padding()
                } else if items.isEmpty {
                    Text("Пока нет комментариев")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding()
                } else {
                    List {
                        ForEach(items) { c in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(c.authorDisplayName)
                                    .font(.caption.weight(.semibold))
                                Text(c.body)
                                    .font(.body)
                            }
                            .padding(.vertical, 4)
                        }
                        if hasMore {
                            Button("Ранее") {
                                Task { await loadMore() }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
                HStack(alignment: .bottom, spacing: 8) {
                    TextField("Комментарий", text: $draft, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1 ... 4)
                    Button {
                        Task { await send() }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sending)
                }
                .padding()
            }
            .navigationTitle("Комментарии")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
            .task { await reload() }
        }
    }

    private func reload() async {
        loading = true
        defer { loading = false }
        do {
            let r = try await APIClient.shared.getProofCommentsDecoded(
                ownerLoginKey: ownerLoginKey,
                calendarId: calendarId,
                day: day,
                limit: 40,
                beforeId: nil
            )
            items = r.comments
            beforeId = r.nextBeforeId
            hasMore = r.hasMore ?? false
        } catch {
            items = []
        }
    }

    private func loadMore() async {
        guard let bid = beforeId else { return }
        do {
            let r = try await APIClient.shared.getProofCommentsDecoded(
                ownerLoginKey: ownerLoginKey,
                calendarId: calendarId,
                day: day,
                limit: 40,
                beforeId: bid
            )
            items.insert(contentsOf: r.comments, at: 0)
            beforeId = r.nextBeforeId
            hasMore = r.hasMore ?? false
        } catch {}
    }

    private func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        sending = true
        defer { sending = false }
        do {
            _ = try await APIClient.shared.postProofCommentDecoded(
                ownerLoginKey: ownerLoginKey,
                calendarId: calendarId,
                day: day,
                body: text
            )
            draft = ""
            await reload()
        } catch {}
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
