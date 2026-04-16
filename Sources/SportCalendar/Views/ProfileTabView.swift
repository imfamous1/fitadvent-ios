import PhotosUI
import SwiftUI

struct ProfileTabView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme

    @State private var activeSheet: ProfileSheet?
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var avatarUploadError: String?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    profileHead
                    profileHero
                    statsRow
                    editProfileButton
                    exercisesBlock
                    logoutBlock
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $activeSheet) { sheet in
                sheetView(sheet)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .onChange(of: photoPickerItem) { _, new in
                Task { await uploadAvatarIfNeeded(item: new) }
            }
            .refreshable { await appState.refreshBootstrap() }
        }
    }

    // MARK: - Head (как view-head на вебе)

    private var profileHead: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Профиль")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.primary)
                    .tracking(-0.5)
                Text("Твой прогресс и данные профиля")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button {
                activeSheet = .settings
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundStyle(Color(red: ProfileChrome.accentBlue.red, green: ProfileChrome.accentBlue.green, blue: ProfileChrome.accentBlue.blue))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Настройки")
        }
        .padding(.top, 8)
        .padding(.bottom, 20)
    }

    // MARK: - Hero

    @ViewBuilder
    private var profileHero: some View {
        if let b = appState.bootstrap {
            let p = b.user.profile
            let vip = vipActive(p)
            VStack(spacing: 16) {
                avatarBlock(profile: p, vip: vip)
                VStack(spacing: 8) {
                    Text((p.displayName?.isEmpty == false ? p.displayName : nil) ?? b.user.login)
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(b.user.login)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    metaChips(profile: p, vip: vip)
                }
                .frame(maxWidth: 320)
                if let avatarUploadError {
                    Text(avatarUploadError)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 20)
        } else {
            ContentUnavailableView(
                "Нет данных",
                systemImage: "icloud.slash",
                description: Text("Потяните для обновления после входа.")
            )
            .padding(.vertical, 24)
        }
    }

    private func avatarBlock(profile: UserProfile, vip: Bool) -> some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let urlStr = profile.avatarUrl, let u = URL(string: urlStr) {
                    AsyncImage(url: u) { phase in
                        switch phase {
                        case .success(let img):
                            img
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            avatarPlaceholder
                        case .empty:
                            ProgressView()
                        @unknown default:
                            avatarPlaceholder
                        }
                    }
                } else {
                    avatarPlaceholder
                }
            }
            .frame(width: 96, height: 96)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .strokeBorder(avatarRingStyle(vip: vip), lineWidth: vip ? 3.5 : 2.5)
            }
            PhotosPicker(selection: $photoPickerItem, matching: .images) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        Color(red: ProfileChrome.accentBlue.red, green: ProfileChrome.accentBlue.green, blue: ProfileChrome.accentBlue.blue),
                        in: Circle()
                    )
                    .shadow(color: Color(red: ProfileChrome.accentBlue.red, green: ProfileChrome.accentBlue.green, blue: ProfileChrome.accentBlue.blue).opacity(0.45), radius: 6, y: 2)
            }
            .buttonStyle(.plain)
            .offset(x: 4, y: 4)
            .accessibilityLabel("Загрузить фото")
        }
    }

    private var avatarPlaceholder: some View {
        ZStack {
            Circle().fill(Color(uiColor: .tertiarySystemGroupedBackground))
            Image(systemName: "person.fill")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
        }
    }

    private func metaChips(profile: UserProfile, vip: Bool) -> some View {
        let athlete = formatAthleteSince(profile.registeredAt)
        let vipDate = formatVipUntilDisplay(profile.vipUntil)
        let tgName = profile.telegramUsername?.trimmingCharacters(in: .whitespacesAndNewlines)
        let showTg = (tgName != nil && !(tgName?.isEmpty ?? true)) || profile.telegramUserId != nil

        let tgText: String = {
            if let u = tgName, !u.isEmpty { return "@\(u)" }
            if let id = profile.telegramUserId { return String(id) }
            return ""
        }()

        var chipKinds: [ProfileMetaChipKind] = []
        if !athlete.isEmpty { chipKinds.append(.athlete(athlete)) }
        if vip, !vipDate.isEmpty { chipKinds.append(.vip("Премиум до \(vipDate)")) }
        if showTg, !tgText.isEmpty { chipKinds.append(.telegram(tgText)) }

        return Group {
            if !chipKinds.isEmpty {
                VStack(spacing: 8) {
                    ForEach(0 ..< ((chipKinds.count + 1) / 2), id: \.self) { row in
                        let i0 = row * 2
                        let i1 = i0 + 1
                        let hasPair = i1 < chipKinds.count
                        if hasPair {
                            HStack(spacing: 8) {
                                metaChipCell(chipKinds[i0]).frame(maxWidth: .infinity)
                                metaChipCell(chipKinds[i1]).frame(maxWidth: .infinity)
                            }
                        } else {
                            HStack {
                                Spacer(minLength: 0)
                                metaChipCell(chipKinds[i0])
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func metaChipCell(_ kind: ProfileMetaChipKind) -> some View {
        switch kind {
        case .athlete(let text):
            metaChip(text, style: .athlete)
        case .vip(let text):
            metaChip(text, style: .vip)
        case .telegram(let text):
            telegramMetaChip(text: text)
        }
    }

    private enum ProfileMetaChipKind: Identifiable {
        case athlete(String)
        case vip(String)
        case telegram(String)

        var id: String {
            switch self {
            case .athlete(let s): return "athlete:\(s)"
            case .vip(let s): return "vip:\(s)"
            case .telegram(let s): return "tg:\(s)"
            }
        }
    }

    private enum ChipStyle { case athlete, vip, telegram }

    private func telegramMetaChip(text: String) -> some View {
        HStack(spacing: 2) {
            Text("tg:")
                .fontWeight(.heavy)
                .layoutPriority(1)
            Text(text)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
               .font(.caption.weight(.semibold))
        .multilineTextAlignment(.center)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(ProfileChrome.communityProfilePillFill(colorScheme: colorScheme))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(ProfileChrome.communityProfilePillOutline(colorScheme: colorScheme), lineWidth: 1)
        )
        .foregroundStyle(Color(red: ProfileChrome.chipTelegram.red, green: ProfileChrome.chipTelegram.green, blue: ProfileChrome.chipTelegram.blue))
    }

    private func metaChip(_ text: String, style: ChipStyle) -> some View {
        switch style {
        case .athlete:
            return AnyView(
                Text(text)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(ProfileChrome.communityProfilePillFill(colorScheme: colorScheme))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(ProfileChrome.communityProfilePillOutline(colorScheme: colorScheme), lineWidth: 1)
                    )
                    .foregroundStyle(Color(red: ProfileChrome.chipAthlete.red, green: ProfileChrome.chipAthlete.green, blue: ProfileChrome.chipAthlete.blue))
            )
        case .vip:
            return AnyView(
                Text(text)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(ProfileChrome.communityProfilePillFill(colorScheme: colorScheme))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(ProfileChrome.communityProfilePillOutline(colorScheme: colorScheme), lineWidth: 1)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: ProfileChrome.primary.red, green: ProfileChrome.primary.green, blue: ProfileChrome.primary.blue),
                                Color(red: ProfileChrome.chipVip.red, green: ProfileChrome.chipVip.green, blue: ProfileChrome.chipVip.blue),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
        case .telegram:
            return AnyView(
                Text(text)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(ProfileChrome.communityProfilePillFill(colorScheme: colorScheme))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(ProfileChrome.communityProfilePillOutline(colorScheme: colorScheme), lineWidth: 1)
                    )
                    .foregroundStyle(Color(red: ProfileChrome.chipTelegram.red, green: ProfileChrome.chipTelegram.green, blue: ProfileChrome.chipTelegram.blue))
            )
        }
    }

    private func avatarRingStyle(vip: Bool) -> AnyShapeStyle {
        let blue = Color(red: ProfileChrome.accentBlue.red, green: ProfileChrome.accentBlue.green, blue: ProfileChrome.accentBlue.blue)
        guard vip else {
            return AnyShapeStyle(blue)
        }
        let o1 = Color(red: ProfileChrome.primary.red, green: ProfileChrome.primary.green, blue: ProfileChrome.primary.blue)
        let o2 = Color(red: ProfileChrome.chipVip.red, green: ProfileChrome.chipVip.green, blue: ProfileChrome.chipVip.blue)
        let gold = Color(red: 1.0, green: 0.84, blue: 0.35)
        let amber = Color(red: 0.99, green: 0.58, blue: 0.18)
        return AnyShapeStyle(
            AngularGradient(colors: [o1, amber, gold, o2, o1], center: .center)
        )
    }

    // MARK: - Стат-пиллы

    private var statsRow: some View {
        let b = appState.bootstrap
        let g = b?.gamification
        let level = g?.level ?? 1
        let bmi = g?.bmi
        return LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
            spacing: 8
        ) {
            statPillButton(title: "Статистика", systemImage: "chart.bar.fill", badge: nil) {
                if let b { activeSheet = .stats(WorkoutHistoryReportBuilder.build(from: b)) }
            }
            if let bmi, bmi.isFinite {
                statPillButton(title: "Здоровье", systemImage: "scalemass", badge: nil) {
                    activeSheet = .health
                }
            } else {
                statPillStatic(title: "Здоровье", systemImage: "scalemass")
            }
            statPillButton(title: "Уровень \(level)", systemImage: "star.fill", badge: nil) {
                activeSheet = .level
            }
            statPillButton(title: "Трофеи", systemImage: "trophy.fill", badge: nil) {
                activeSheet = .trophies
            }
        }
        .padding(.bottom, 14)
    }

    private func statPillButton(title: String, systemImage: String, badge: Int?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 4) {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(red: ProfileChrome.accentBlue.red, green: ProfileChrome.accentBlue.green, blue: ProfileChrome.accentBlue.blue))
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color(red: ProfileChrome.accentBlue.red, green: ProfileChrome.accentBlue.green, blue: ProfileChrome.accentBlue.blue))
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity, minHeight: ProfileChrome.profileBarFixedHeight, maxHeight: ProfileChrome.profileBarFixedHeight, alignment: .center)
                .padding(.horizontal, 6)
                .background(
                    RoundedRectangle(cornerRadius: ProfileChrome.radiusLg, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                )
                if let badge, badge > 0 {
                    Text(badge > 99 ? "99+" : String(badge))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.red.opacity(0.92)))
                        .offset(x: 4, y: -6)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func statPillStatic(title: String, systemImage: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: ProfileChrome.profileBarFixedHeight, maxHeight: ProfileChrome.profileBarFixedHeight, alignment: .center)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: ProfileChrome.radiusLg, style: .continuous)
                .fill(Color(uiColor: .tertiarySystemGroupedBackground))
        )
    }

    // MARK: - Редактировать и упражнения

    private var editProfileButton: some View {
        Button {
            activeSheet = .edit
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "square.and.pencil")
                    .font(.body.weight(.semibold))
                Text("Редактировать анкету")
                    .font(.body.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: ProfileChrome.profileBarFixedHeight, maxHeight: ProfileChrome.profileBarFixedHeight, alignment: .center)
            .background(
                Capsule()
                    .fill(Color(red: ProfileChrome.accentBlue.red, green: ProfileChrome.accentBlue.green, blue: ProfileChrome.accentBlue.blue))
            )
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 22)
    }

    private var exercisesBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Упражнения")
                    .font(.title3.weight(.bold))
                Text("Настрой свой план на месяц")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, ProfileChrome.exerciseSectionTitleLeading)
            VStack(spacing: 0) {
                exerciseRow(icon: "calendar", title: "Текущий", trailing: "FitAdvent") {
                    activeSheet = .exerciseHint("Текущий месяц")
                }
                Divider().padding(.leading, ProfileChrome.exercisePlanDividerLeading)
                if isProgramVoteBannerDayNow() {
                    exerciseRow(icon: "calendar.badge.clock", title: "Следующий", trailing: nil) {
                        let t = programVoteNextMonthTarget()
                        activeSheet = .exerciseHint("Программа на \(t.month).\(t.year) — скоро здесь же, что и на сайте.")
                    }
                    Divider().padding(.leading, ProfileChrome.exercisePlanDividerLeading)
                }
                exerciseRow(
                    icon: "person.fill",
                    title: "Индивидуальный",
                    trailing: nil,
                    showPremium: !(appState.bootstrap.map { vipActive($0.user.profile) } ?? false)
                ) {
                    let isVip = appState.bootstrap.map { vipActive($0.user.profile) } ?? false
                    if isVip {
                        activeSheet = .exerciseHint("Индивидуальная программа на месяц — полный сценарий как на сайте появится в следующих версиях.")
                    } else {
                        activeSheet = .exerciseHint("Доступно по подписке Премиум.")
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: ProfileChrome.radiusXl, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
        }
        .padding(.bottom, 24)
    }

    private func exerciseRow(
        icon: String,
        title: String,
        trailing: String?,
        showPremium: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: ProfileChrome.exerciseRowIconSpacing) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(Color(red: ProfileChrome.accentBlue.red, green: ProfileChrome.accentBlue.green, blue: ProfileChrome.accentBlue.blue))
                    .frame(width: ProfileChrome.exerciseRowIconColumnWidth)
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
                if let trailing {
                    Text(trailing)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                if showPremium {
                    Text("P")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color(red: ProfileChrome.primary.red, green: ProfileChrome.primary.green, blue: ProfileChrome.primary.blue))
                        )
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, ProfileChrome.exerciseRowPaddingH)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var logoutBlock: some View {
        Button {
            Task { await appState.logout() }
        } label: {
            Text("Выйти")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color(red: ProfileChrome.error.red, green: ProfileChrome.error.green, blue: ProfileChrome.error.blue))
                .frame(maxWidth: .infinity)
                .padding(.vertical, ProfileChrome.profileBarVerticalPadding)
                .background(
                    Capsule()
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                )
        }
        .buttonStyle(.plain)
        .padding(.bottom, 8)
    }

    // MARK: - Sheets

    @ViewBuilder
    private func sheetView(_ sheet: ProfileSheet) -> some View {
        switch sheet {
        case .settings:
            ProfileSettingsSheet()
        case .stats(let report):
            ProfileStatsSheet(report: report)
        case .health:
            ProfileHealthSheet(
                profile: appState.bootstrap?.user.profile,
                gamification: appState.bootstrap?.gamification,
                onPickKcal: { kcal in await applyKcalGoal(kcal) }
            )
        case .level:
            ProfileLevelSheet(g: appState.bootstrap?.gamification)
        case .trophies:
            ProfileTrophiesSheet(achievements: appState.bootstrap.map { $0.gamification.achievements ?? [] } ?? [])
        case .edit:
            ProfileEditSheet()
        case .exerciseHint(let t):
            ProfileHintSheet(text: t)
        }
    }

    private func uploadAvatarIfNeeded(item: PhotosPickerItem?) async {
        guard let item else { return }
        avatarUploadError = nil
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                avatarUploadError = "Не удалось прочитать файл"
                return
            }
            _ = try await APIClient.shared.uploadAvatar(imageData: data)
            photoPickerItem = nil
            await appState.refreshBootstrap()
        } catch let e as APIClientError {
            avatarUploadError = e.message
        } catch {
            avatarUploadError = error.localizedDescription
        }
    }

    private func applyKcalGoal(_ kcal: Int) async {
        guard let p = appState.bootstrap?.user.profile else { return }
        do {
            try await APIClient.shared.patchMe(ProfilePatchBody(
                displayName: p.displayName,
                heightCm: p.heightCm,
                weightKg: p.weightKg,
                ageYears: p.ageYears,
                sex: p.sex,
                shareBodyStats: p.shareBodyStats,
                shareProofsLarge: p.shareProofsLarge,
                showInCommunityList: p.showInCommunityList,
                dailyKcalGoal: kcal
            ))
            await appState.refreshBootstrap()
        } catch {}
    }
}

// MARK: - Sheet types

enum ProfileSheet: Identifiable {
    case settings
    case stats(WorkoutHistoryReport)
    case health
    case level
    case trophies
    case edit
    case exerciseHint(String)

    var id: String {
        switch self {
        case .settings: return "settings"
        case .stats: return "stats"
        case .health: return "health"
        case .level: return "level"
        case .trophies: return "trophies"
        case .edit: return "edit"
        case .exerciseHint(let s): return "hint-\(s.prefix(32))"
        }
    }
}

// MARK: - Вложенные листы

private struct ProfileSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appearanceOverride") private var appearanceOverride: String = ""

    /// Как карточки в «Статистика» (`secondarySystemGroupedBackground` на `systemGroupedBackground`).
    private func rowBackground() -> some View {
        Color(uiColor: .secondarySystemGroupedBackground)
    }

    private var nightModeIsOn: Bool {
        switch appearanceOverride {
        case "dark": return true
        case "light": return false
        default: return colorScheme == .dark
        }
    }

    private var nightModeBinding: Binding<Bool> {
        Binding(
            get: { nightModeIsOn },
            set: { appearanceOverride = $0 ? "dark" : "light" }
        )
    }

    /// Явная схема из настроек; совпадает с `AppRootView`. Нужна на самом листе: иначе `List`
    /// в sheet иногда не перерисовывает системные цвета при переключении тумблера.
    private var storedPreferredScheme: ColorScheme? {
        switch appearanceOverride {
        case "dark": return .dark
        case "light": return .light
        default: return nil
        }
    }

    /// Меняем идентичность контейнера при смене эффективной темы — форсируем обновление фона/строк.
    private var themeRefreshIdentity: String {
        switch appearanceOverride {
        case "dark": return "dark"
        case "light": return "light"
        default: return "sys-\(colorScheme == .dark ? "d" : "l")"
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("Уведомления", systemImage: "bell.fill")
                        .listRowBackground(rowBackground())
                    Toggle(isOn: nightModeBinding) {
                        Label("Ночной режим", systemImage: "moon.fill")
                    }
                    .listRowBackground(rowBackground())
                    Label("Аккаунт и безопасность", systemImage: "lock.shield.fill")
                        .listRowBackground(rowBackground())
                } footer: {
                    Text("Раздел в разработке — настройки будут как на сайте.")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .navigationTitle("Настройки")
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
        }
        .background {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
        }
        .preferredColorScheme(storedPreferredScheme)
        .id(themeRefreshIdentity)
    }
}

private struct ProfileStatsSheet: View {
    @Environment(\.dismiss) private var dismiss
    var report: WorkoutHistoryReport

    var body: some View {
        let (cy, cm, _) = moscowYmdNow()
        let currentSortKey = cy * 12 + cm
        let currentMs = report.sections.filter { $0.sortKey == currentSortKey }
        let otherMs = report.sections.filter { $0.sortKey != currentSortKey }
        let calId = String(format: "%04d-%02d", cy, cm)
        let currentMonthTitle = MoscowCalendar.monthTitle(calendarId: calId)
        let currentWorkouts = currentMs.first?.workouts ?? 0
        let currentRows = currentMs.first?.exerciseRows ?? []

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(currentMonthTitle)
                                .font(.title3.weight(.bold))
                            (Text("Тренировок: ") + Text("\(currentWorkouts)").fontWeight(.bold))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.leading, ProfileChrome.exerciseSectionTitleLeading)

                        if report.sections.isEmpty {
                            emptyState(total: report.totalWorkoutsAllCalendars)
                        } else {
                            if !currentRows.isEmpty {
                                exerciseListCard(rows: currentRows)
                            } else if !otherMs.isEmpty {
                                currentMonthEmptyHint(monthTitle: currentMonthTitle)
                            }
                        }
                    }

                    if !otherMs.isEmpty {
                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: 16) {
                                ForEach(otherMs) { section in
                                    archiveMonthBlock(section)
                                }
                            }
                            .padding(.top, 8)
                        } label: {
                            HStack {
                                Text("Другие месяцы")
                                    .font(.body.weight(.semibold))
                                Text("(\(otherMs.count))")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tint(Color(red: ProfileChrome.primary.red, green: ProfileChrome.primary.green, blue: ProfileChrome.primary.blue))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Статистика")
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
        }
    }

    private func exerciseListCard(rows: [WorkoutHistoryExerciseRow]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                if idx > 0 {
                    Divider()
                        .padding(.leading, ProfileChrome.exercisePlanDividerLeading)
                }
                HStack(alignment: .firstTextBaseline) {
                    Text(row.label)
                        .font(.body)
                    Spacer(minLength: 12)
                    Text(row.valueDisplay)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color(red: ProfileChrome.accentBlue.red, green: ProfileChrome.accentBlue.green, blue: ProfileChrome.accentBlue.blue))
                        .multilineTextAlignment(.trailing)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, ProfileChrome.exerciseRowPaddingH)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ProfileChrome.radiusXl, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }

    private func archiveMonthBlock(_ section: WorkoutHistoryMonthSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(section.title)
                    .font(.title3.weight(.bold))
                (Text("Тренировок: ") + Text("\(section.workouts)").fontWeight(.bold))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, ProfileChrome.exerciseSectionTitleLeading)

            if !section.exerciseRows.isEmpty {
                exerciseListCard(rows: section.exerciseRows)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func emptyState(total: Int) -> some View {
        Group {
            if total > 0 {
                Text("Не удалось загрузить программы месяцев для детализации.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Отметьте дни в календаре — здесь появится разбивка по месяцам.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, ProfileChrome.exerciseSectionTitleLeading)
    }

    private func currentMonthEmptyHint(monthTitle: String) -> some View {
        (Text("За ") + Text(monthTitle).fontWeight(.bold) + Text(" (Москва) пока нет отмеченных тренировок."))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, ProfileChrome.exerciseSectionTitleLeading)
    }

}

private struct ProfileHealthSheet: View {
    @Environment(\.dismiss) private var dismiss
    var profile: UserProfile?
    var gamification: Gamification?
    var onPickKcal: (Int) async -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let bmi = gamification?.bmi, bmi.isFinite, let info = getBmiInterpretation(bmi: bmi) {
                        VStack(alignment: .leading, spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Индекс массы тела")
                                    .font(.title3.weight(.bold))
                                Text("ИМТ \(String(format: "%.1f", bmi).replacingOccurrences(of: ".", with: ",")) — \(info.category)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.leading, ProfileChrome.exerciseSectionTitleLeading)

                            VStack(alignment: .leading, spacing: 8) {
                                Text(info.detail)
                                    .font(.body)
                                Text("Ограничения показателя")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 4)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("• ИМТ — упрощённый показатель для взрослых.")
                                    Text("• Не учитывает мышечную массу, пол и возраст детей.")
                                }
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: ProfileChrome.radiusXl).fill(Color(uiColor: .secondarySystemGroupedBackground)))
                        }
                    }

                    if let p = profile {
                        let normsPack = computeTdeeAndKcalNorms(p)
                        let norms = normsPack.norms
                        VStack(alignment: .leading, spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Суточные калории")
                                    .font(.title3.weight(.bold))
                                Text(norms.maintenance != nil ? "Три ориентира при обычной нагрузке" : "Не удалось оценить по текущим данным")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.leading, ProfileChrome.exerciseSectionTitleLeading)

                            VStack(alignment: .leading, spacing: 8) {
                                if let d = norms.deficit, let m = norms.maintenance, let s = norms.surplus {
                                    kcalRow(label: "Похудение", value: d)
                                    Divider()
                                    kcalRow(label: "Поддержание веса", value: m)
                                    Divider()
                                    kcalRow(label: "Набор веса", value: s)
                                    Text("Оценка по Mifflin–St Jeor, \(kcalRecommendationAgeFootnote(p)), умеренная активность. Не заменяет консультацию врача.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.top, 6)
                                    Text("Нажмите строку, чтобы записать ориентир в профиль как дневную цель.")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                } else {
                                    Text("Заполните анкету (рост, вес), чтобы получить ориентиры.")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: ProfileChrome.radiusXl).fill(Color(uiColor: .secondarySystemGroupedBackground)))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Здоровье")
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
        }
    }

    private func kcalRow(label: String, value: Int) -> some View {
        Button {
            Task { await onPickKcal(value) }
        } label: {
            HStack {
                Text(label)
                Spacer()
                Text("~\(value) ккал")
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(red: ProfileChrome.primary.red, green: ProfileChrome.primary.green, blue: ProfileChrome.primary.blue))
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct ProfileLevelSheet: View {
    @Environment(\.dismiss) private var dismiss
    var g: Gamification?

    /// Как на вебе (`gamification.js`):15 за тренировку, до 5 за «Слова».
    private let xpPerWorkout = 15
    private let xpPerWordsWin = 5

    private var navigationTitleText: String {
        guard let g else { return "Уровень" }
        return "Уровень \(g.level ?? 1)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let g {
                        levelProgressBlock(g: g)
                        xpSourcesBlock
                    } else {
                        Text("Нет данных геймификации.")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(navigationTitleText)
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
        }
    }

    private func levelProgressBlock(g: Gamification) -> some View {
        let level = g.level ?? 1
        let rank = athleteLevelLabel(level: level)
        let span = max(0, g.xpSpanThisLevel ?? 0)
        let into = max(0, g.xpIntoLevel ?? 0)
        let xpNext = max(0, g.xpForNextLevel ?? 0)
        let pct = min(max(g.progressPct ?? 0, 0), 1)
        let primary = Color(red: ProfileChrome.primary.red, green: ProfileChrome.primary.green, blue: ProfileChrome.primary.blue)

        return VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Прогресс")
                    .font(.title3.weight(.bold))
                Text("\(rank) · \(xpNext) XP до следующего уровня")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, ProfileChrome.exerciseSectionTitleLeading)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 8) {
                    Text("0")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 10, alignment: .leading)
                    GeometryReader { geo in
                        let fillW = max(0, min(geo.size.width, geo.size.width * CGFloat(pct)))
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(uiColor: .tertiarySystemFill))
                            Capsule()
                                .fill(primary)
                                .frame(width: fillW)
                        }
                    }
                    .frame(height: 10)
                    Text("\(span)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 18, alignment: .trailing)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Опыт в текущем уровне")
                .accessibilityValue("\(into) из \(max(span, 1))")

                (Text("\(into)").fontWeight(.bold) + Text(" / \(span) XP в этом уровне"))
                    .font(.subheadline)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: ProfileChrome.radiusXl).fill(Color(uiColor: .secondarySystemGroupedBackground)))
        }
    }

    private var xpSourcesBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Начисление опыта")
                    .font(.title3.weight(.bold))
                Text("Физическая и умственная активность")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, ProfileChrome.exerciseSectionTitleLeading)

            VStack(alignment: .leading, spacing: 8) {
                Text("• ") + Text("Физический: ") + Text("\(xpPerWorkout) XP").fontWeight(.semibold) + Text(" за каждую отмеченную тренировку в календаре.")
                Text("• ") + Text("Умственный: до ") + Text("\(xpPerWordsWin) XP").fontWeight(.semibold) + Text(" в сутки за победу в «Словах»; позже — другие умственные задания.")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(RoundedRectangle(cornerRadius: ProfileChrome.radiusXl).fill(Color(uiColor: .secondarySystemGroupedBackground)))
        }
    }
}

private struct ProfileTrophiesSheet: View {
    @Environment(\.dismiss) private var dismiss
    var achievements: [Achievement]
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Все значки")
                            .font(.title3.weight(.bold))
                        Text("Нажмите карточку, чтобы открыть подробности")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.leading, ProfileChrome.exerciseSectionTitleLeading)

                    if achievements.isEmpty {
                        Text("Пока нет значков.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(RoundedRectangle(cornerRadius: ProfileChrome.radiusXl, style: .continuous).fill(Color(uiColor: .secondarySystemGroupedBackground)))
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(achievements, id: \.id) { a in
                                Button {
                                    path.append(a)
                                } label: {
                                    trophyGridCell(a)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: ProfileChrome.radiusXl, style: .continuous).fill(Color(uiColor: .secondarySystemGroupedBackground)))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Трофеи")
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
            .navigationDestination(for: Achievement.self) { a in
                ProfileAchievementDetailView(achievement: a)
            }
        }
    }

    private func trophyGridCell(_ a: Achievement) -> some View {
        VStack(spacing: 8) {
            Text(a.icon)
                .font(.system(size: 36))
            Text(a.displayTitle)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .foregroundStyle(a.unlocked ? Color.primary : Color.secondary)
            Text(a.unlocked ? "Открыто" : "Закрыто")
                .font(.caption2.weight(.medium))
                .foregroundStyle(a.unlocked ? Color.green : Color.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: ProfileChrome.radiusLg, style: .continuous)
                .fill(Color(uiColor: .tertiarySystemGroupedBackground))
        )
        .opacity(a.unlocked ? 1 : 0.55)
        .accessibilityLabel(a.unlocked ? "Открыто: \(a.displayTitle). Подробнее" : "Закрыто: \(a.displayTitle). Подробнее")
    }
}

private struct ProfileAchievementDetailView: View {
    var achievement: Achievement

    private var copy: AchievementCopy.Resolved { AchievementCopy.resolved(for: achievement) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Детали")
                        .font(.title3.weight(.bold))
                    Text(detailSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, ProfileChrome.exerciseSectionTitleLeading)

                VStack(alignment: .leading, spacing: 16) {
                    Text(achievement.icon)
                        .font(.system(size: 48))
                        .frame(maxWidth: .infinity)

                    if achievement.unlocked {
                        if copy.wisdom.isEmpty {
                            Text("Послание скоро появится.")
                                .foregroundStyle(.secondary)
                        } else {
                            Text(copy.wisdom)
                                .font(.body)
                                .italic()
                            if !copy.wisdomAuthor.isEmpty {
                                Text(copy.wisdomAuthor)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        if !copy.unlockHint.isEmpty {
                            Text(copy.unlockHint)
                                .font(.body)
                        }
                        Text("Выполните условие — и здесь появится послание.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: ProfileChrome.radiusXl, style: .continuous).fill(Color(uiColor: .secondarySystemGroupedBackground)))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(achievement.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var detailSubtitle: String {
        achievement.unlocked ? "Послание за открытие награды" : "Как получить награду"
    }
}

private struct ProfileHintSheet: View {
    var text: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(text)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding()
                Spacer()
            }
            .navigationTitle("Упражнения")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
    }
}

private struct ProfileEditSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var heightCm = ""
    @State private var weightKg = ""
    @State private var ageYears = ""
    @State private var sex = ""
    @State private var dailyKcal = ""
    @State private var shareBody = false
    @State private var shareProofs = false
    @State private var showInCommunity = true
    @State private var saving = false
    @State private var errorBanner: String?

    var body: some View {
        NavigationStack {
            Form {
                if let banner = errorBanner {
                    Section { Text(banner).foregroundStyle(.red) }
                }
                Section("Имя") {
                    TextField("Отображаемое имя", text: $displayName)
                }
                Section("Антропометрия") {
                    TextField("Рост, см", text: $heightCm)
                    #if os(iOS)
                        .keyboardType(.numberPad)
                    #endif
                    TextField("Вес, кг", text: $weightKg)
                    #if os(iOS)
                        .keyboardType(.decimalPad)
                    #endif
                    TextField("Возраст, лет", text: $ageYears)
                    #if os(iOS)
                        .keyboardType(.numberPad)
                    #endif
                    TextField("Пол (male / female или пусто)", text: $sex)
                }
                Section("Цель по калориям") {
                    TextField("Ккал в день (0 — не задано)", text: $dailyKcal)
                    #if os(iOS)
                        .keyboardType(.numberPad)
                    #endif
                }
                Section("Приватность") {
                    Toggle("Делиться параметрами тела", isOn: $shareBody)
                    Toggle("Крупные доказательства", isOn: $shareProofs)
                    Toggle("Показывать в списке сообщества", isOn: $showInCommunity)
                }
                Section {
                    Button(saving ? "Сохранение…" : "Сохранить") {
                        Task { await save() }
                    }
                    .disabled(saving)
                }
            }
            .navigationTitle("Анкета")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
            .onAppear { hydrate() }
            .onChange(of: appState.bootstrap?.user.profile.displayName) { _, _ in hydrate() }
        }
    }

    private func hydrate() {
        guard let p = appState.bootstrap?.user.profile else { return }
        displayName = p.displayName ?? appState.bootstrap?.user.login ?? ""
        heightCm = p.heightCm ?? ""
        weightKg = p.weightKg ?? ""
        ageYears = p.ageYears ?? ""
        sex = p.sex ?? ""
        if let k = p.dailyKcalGoal { dailyKcal = k > 0 ? String(k) : "" }
        shareBody = p.shareBodyStats ?? false
        shareProofs = p.shareProofsLarge ?? false
        showInCommunity = p.showInCommunityList ?? true
    }

    private func save() async {
        saving = true
        errorBanner = nil
        defer { saving = false }
        let kcalParsed: Int? = {
            let t = dailyKcal.trimmingCharacters(in: .whitespaces)
            if t.isEmpty { return nil }
            return Int(t)
        }()
        do {
            try await APIClient.shared.patchMe(ProfilePatchBody(
                displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                heightCm: heightCm.isEmpty ? nil : heightCm,
                weightKg: weightKg.isEmpty ? nil : weightKg,
                ageYears: ageYears.isEmpty ? nil : ageYears,
                sex: sex.isEmpty ? nil : sex,
                shareBodyStats: shareBody,
                shareProofsLarge: shareProofs,
                showInCommunityList: showInCommunity,
                dailyKcalGoal: kcalParsed
            ))
            await appState.refreshBootstrap()
            dismiss()
        } catch let e as APIClientError {
            errorBanner = e.message
        } catch {
            errorBanner = error.localizedDescription
        }
    }
}

