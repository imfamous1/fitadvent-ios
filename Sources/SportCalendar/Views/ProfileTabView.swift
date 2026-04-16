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
                    activeSheet = .currentProgram
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
                    activeSheet = .individualProgram
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
        case .currentProgram:
            CurrentProgramVoteSheet()
        case .individualProgram:
            IndividualProgramVoteSheet()
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
    case currentProgram
    case individualProgram

    var id: String {
        switch self {
        case .settings: return "settings"
        case .stats: return "stats"
        case .health: return "health"
        case .level: return "level"
        case .trophies: return "trophies"
        case .edit: return "edit"
        case .exerciseHint(let s): return "hint-\(s.prefix(32))"
        case .currentProgram: return "current-program"
        case .individualProgram: return "individual-program"
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
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let banner = errorBanner {
                        Text(banner)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color(red: ProfileChrome.error.red, green: ProfileChrome.error.green, blue: ProfileChrome.error.blue))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: ProfileChrome.radiusXl, style: .continuous)
                                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                            )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        sectionHeader("Имя")
                        card {
                            TextField("Отображаемое имя", text: $displayName)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled(true)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        sectionHeader("Пол")
                        Picker("Пол", selection: $sex) {
                            Text("Не указан").tag("")
                            Text("Мужской").tag("male")
                            Text("Женский").tag("female")
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        sectionHeader("Антропометрия")
                        card {
                            VStack(spacing: 0) {
                                iconFieldRow(systemImage: "ruler", placeholder: "Рост, см", text: $heightCm, keyboard: .numberPad)
                                inputOnlyDivider
                                iconFieldRow(systemImage: "scalemass", placeholder: "Вес, кг", text: $weightKg, keyboard: .decimalPad)
                                inputOnlyDivider
                                iconFieldRow(systemImage: "calendar", placeholder: "Возраст, лет", text: $ageYears, keyboard: .numberPad)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        sectionHeader("Цель по калориям")
                        card {
                            TextField("не задана", text: $dailyKcal)
                                    #if os(iOS)
                                        .keyboardType(.numberPad)
                                    #endif
                        }
                        if let recommendedKcal {
                            Text("Рекомендуемо по Mifflin–St Jeor: ~\(recommendedKcal) ккал/день.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.leading, ProfileChrome.exerciseSectionTitleLeading)
                        } else {
                            Text("Укажите рост и вес, возраст можно оставить пустым.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.leading, ProfileChrome.exerciseSectionTitleLeading)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        sectionHeader("Сообщество")
                        card {
                            VStack(spacing: 0) {
                                toggleRow("Показывать мой профиль в общем списке", isOn: $showInCommunity)
                                divider
                                toggleRow(
                                    "Показывать рост и вес всем",
                                    isOn: $shareBody,
                                    disabled: !showInCommunity
                                )
                                divider
                                toggleRow(
                                    "Разрешить открывать фото в полном размере",
                                    isOn: $shareProofs,
                                    disabled: !showInCommunity
                                )
                            }
                        }
                    }

                    Button {
                        Task { await save() }
                    } label: {
                        Label(saving ? "Сохранение…" : "Сохранить", systemImage: "checkmark.circle.fill")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: ProfileChrome.profileBarFixedHeight)
                            .background(
                                Capsule()
                                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                            )
                            .foregroundStyle(Color(
                                red: ProfileChrome.accentBlue.red,
                                green: ProfileChrome.accentBlue.green,
                                blue: ProfileChrome.accentBlue.blue
                            ))
                    }
                    .buttonStyle(.plain)
                    .disabled(saving)
                    .opacity(saving ? 0.7 : 1)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Анкета")
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
            .onAppear { hydrate() }
            .onChange(of: appState.bootstrap?.user.profile.displayName) { _, _ in hydrate() }
            .onChange(of: heightCm) { _, _ in sanitizeKcalDependencyInput() }
            .onChange(of: weightKg) { _, _ in sanitizeKcalDependencyInput() }
            .onChange(of: ageYears) { _, _ in sanitizeKcalDependencyInput() }
            .onChange(of: sex) { _, _ in sanitizeSexInput() }
            .onChange(of: dailyKcal) { _, _ in sanitizeDailyKcalInput() }
            .onChange(of: showInCommunity) { _, isOn in
                if !isOn {
                    shareBody = false
                    shareProofs = false
                }
            }
        }
    }

    private var recommendedKcal: Int? {
        var p = UserProfile()
        p.heightCm = heightCm.trimmingCharacters(in: .whitespacesAndNewlines)
        p.weightKg = weightKg.trimmingCharacters(in: .whitespacesAndNewlines)
        p.ageYears = ageYears.trimmingCharacters(in: .whitespacesAndNewlines)
        p.sex = sex.trimmingCharacters(in: .whitespacesAndNewlines)
        return computeTdeeAndKcalNorms(p).norms.maintenance
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .padding(.leading, ProfileChrome.exerciseSectionTitleLeading)
    }

    @ViewBuilder
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(.horizontal, ProfileChrome.exerciseRowPaddingH)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: ProfileChrome.radiusXl, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
    }

    private var divider: some View {
        Divider()
            .padding(.leading, ProfileChrome.exerciseRowPaddingH)
    }

    private var inputOnlyDivider: some View {
        Divider()
            .padding(.leading, ProfileChrome.exerciseRowPaddingH + 14)
    }

    @ViewBuilder
    private func fieldRow<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func iconFieldRow(systemImage: String, placeholder: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18, alignment: .center)
            TextField(placeholder, text: text)
#if os(iOS)
                .keyboardType(keyboard)
#endif
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func toggleRow(_ title: String, isOn: Binding<Bool>, disabled: Bool = false) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(.subheadline)
        }
        .disabled(disabled)
        .padding(.vertical, 8)
        .opacity(disabled ? 0.55 : 1)
    }

    private func sanitizeKcalDependencyInput() {
        heightCm = sanitizeDecimalInput(heightCm)
        weightKg = sanitizeDecimalInput(weightKg)
        ageYears = sanitizeIntegerInput(ageYears)
    }

    private func sanitizeDailyKcalInput() {
        dailyKcal = sanitizeIntegerInput(dailyKcal)
    }

    private func sanitizeSexInput() {
        let normalized = normalizeProfileSex(sex)
        if normalized != sex { sex = normalized }
    }

    private func sanitizeIntegerInput(_ raw: String) -> String {
        raw.filter { $0.isNumber }
    }

    private func sanitizeDecimalInput(_ raw: String) -> String {
        var out = ""
        var hasSeparator = false
        for ch in raw {
            if ch.isNumber {
                out.append(ch)
            } else if ch == "," || ch == "." {
                if !hasSeparator {
                    out.append(".")
                    hasSeparator = true
                }
            }
        }
        return out
    }

    private func hydrate() {
        guard let p = appState.bootstrap?.user.profile else { return }
        displayName = p.displayName ?? appState.bootstrap?.user.login ?? ""
        heightCm = p.heightCm ?? ""
        weightKg = p.weightKg ?? ""
        ageYears = p.ageYears ?? ""
        sex = normalizeProfileSex(p.sex)
        dailyKcal = ""
        if let k = p.dailyKcalGoal, k > 0 { dailyKcal = String(k) }
        shareBody = p.shareBodyStats ?? false
        shareProofs = p.shareProofsLarge ?? false
        showInCommunity = p.showInCommunityList ?? true
        if !showInCommunity {
            shareBody = false
            shareProofs = false
        }
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
                shareBodyStats: showInCommunity && shareBody,
                shareProofsLarge: showInCommunity && shareProofs,
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

// MARK: - Program Vote Sheets (веб-паритет: текущий / индивидуальный)

private struct ProgramCatalogExercise: Identifiable, Sendable {
    var id: String
    var label: String
    var hint: String
    var unit: ProgramUnit
    var baseBeginner: Int
    var baseIntermediate: Int
    var baseAdvanced: Int
}

private enum ProgramLevel: String, CaseIterable, Identifiable, Sendable {
    case beginner
    case intermediate
    case advanced

    var id: String { rawValue }
    var title: String {
        switch self {
        case .beginner: return "Начальный"
        case .intermediate: return "Средний"
        case .advanced: return "Продвинутый"
        }
    }

    var blurb: String {
        switch self {
        case .beginner: return "Меньше повторов и времени, акцент на технике."
        case .intermediate: return "Умеренный объём и стабильная прогрессия."
        case .advanced: return "Больше объём, рассчитано на устойчивую технику."
        }
    }

    var monthEndRatio: Double {
        switch self {
        case .beginner: return 1.18
        case .intermediate: return 1.85
        case .advanced: return 2.75
        }
    }
}

private let programCatalog: [ProgramCatalogExercise] = [
    .init(id: "pushup", label: "Отжимания", hint: "Планка на руках, опускание почти до пола и подъём.", unit: .reps, baseBeginner: 8, baseIntermediate: 16, baseAdvanced: 28),
    .init(id: "pullup", label: "Подтягивания", hint: "Подтянуть подбородок выше перекладины и опуститься.", unit: .reps, baseBeginner: 4, baseIntermediate: 8, baseAdvanced: 12),
    .init(id: "squat", label: "Приседания", hint: "Присед с прямой спиной и возврат в стойку.", unit: .reps, baseBeginner: 15, baseIntermediate: 30, baseAdvanced: 45),
    .init(id: "plank", label: "Планка", hint: "Удержание корпуса прямой линией на локтях и носках.", unit: .sec, baseBeginner: 30, baseIntermediate: 50, baseAdvanced: 70),
    .init(id: "crunch", label: "Скручивания", hint: "Подъём плеч от пола и плавный возврат.", unit: .reps, baseBeginner: 10, baseIntermediate: 16, baseAdvanced: 24),
    .init(id: "lunge", label: "Выпады", hint: "Шаг вперёд, опускание до 90°, смена ноги.", unit: .reps, baseBeginner: 8, baseIntermediate: 14, baseAdvanced: 20),
    .init(id: "glute_bridge", label: "Ягодичный мостик", hint: "Подъём таза до прямой линии и плавный спуск.", unit: .reps, baseBeginner: 12, baseIntermediate: 18, baseAdvanced: 26),
    .init(id: "side_plank", label: "Боковая планка", hint: "Удержание корпуса на боку с опорой на предплечье.", unit: .sec, baseBeginner: 20, baseIntermediate: 35, baseAdvanced: 50),
    .init(id: "burpee", label: "Берпи", hint: "Присед, планка, прыжок к рукам и вверх.", unit: .reps, baseBeginner: 5, baseIntermediate: 10, baseAdvanced: 15),
    .init(id: "leg_raise", label: "Подъём ног лёжа", hint: "Поднять прямые ноги и медленно опустить.", unit: .reps, baseBeginner: 8, baseIntermediate: 14, baseAdvanced: 20),
    .init(id: "dip_bars", label: "Отжимания на брусьях", hint: "Опускание на брусьях до 90° и подъём.", unit: .reps, baseBeginner: 4, baseIntermediate: 10, baseAdvanced: 16),
    .init(id: "run", label: "Бег", hint: "Лёгкий/умеренный темп, контролируемое дыхание.", unit: .min, baseBeginner: 10, baseIntermediate: 20, baseAdvanced: 35),
]

private enum ProgramUnit: String, CaseIterable, Identifiable, Sendable {
    case reps
    case sec
    case min
    case km

    var id: String { rawValue }
    var title: String {
        switch self {
        case .reps: return "Повторы"
        case .sec: return "Секунды"
        case .min: return "Минуты"
        case .km: return "Километры"
        }
    }
}

private struct CustomProgramExercise: Identifiable {
    var id: String
    var label: String
    var unit: ProgramUnit
    var amount: Int?
}

private let isoDow: [String] = ["1", "2", "3", "4", "5", "6", "7"]
private let dowTitles: [String: String] = [
    "1": "Понедельник", "2": "Вторник", "3": "Среда", "4": "Четверг",
    "5": "Пятница", "6": "Суббота", "7": "Воскресенье",
]

private func currentMoscowTarget() -> (year: Int, month: Int) {
    let now = moscowYmdNow()
    return (now.year, now.month)
}

private func monthVoteKey(year: Int, month: Int) -> String {
    String(format: "%04d-%02d", year, month)
}

private func newCustomExerciseId() -> String {
    let raw = UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "_")
    return "u_\(raw.prefix(16))"
}

private struct CurrentProgramVoteSheet: View {
    private enum Step {
        case exercises
        case level
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var step: Step = .exercises
    @State private var selected: Set<String> = []
    @State private var level: ProgramLevel = .beginner
    @State private var saving = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if step == .exercises {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Шаг 1: Упражнения")
                                    .font(.title3.weight(.bold))
                                Text(stepOneSubtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.leading, ProfileChrome.exerciseSectionTitleLeading)

                            VStack(spacing: 0) {
                                ForEach(Array(programCatalog.enumerated()), id: \.element.id) { idx, ex in
                                    if idx > 0 {
                                        Divider()
                                            .padding(.leading, ProfileChrome.exercisePlanDividerLeading)
                                    }
                                    Button {
                                        toggleExercise(ex.id)
                                    } label: {
                                        HStack(alignment: .top, spacing: 10) {
                                            Image(systemName: selected.contains(ex.id) ? "checkmark.square.fill" : "square")
                                                .font(.title3)
                                                .foregroundStyle(selected.contains(ex.id) ? Color.accentColor : .secondary)
                                                .padding(.top, 2)
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(ex.label)
                                                    .font(.body.weight(.semibold))
                                                    .foregroundStyle(.primary)
                                                Text(ex.hint)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Spacer(minLength: 0)
                                        }
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, ProfileChrome.exerciseRowPaddingH)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: ProfileChrome.radiusXl, style: .continuous)
                                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                            )
                        } else {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Шаг 2: Уровень и превью")
                                    .font(.title3.weight(.bold))
                                Text("Выберите уровень программы и проверьте прогрессию к концу месяца.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.leading, ProfileChrome.exerciseSectionTitleLeading)

                            Picker("Уровень", selection: $level) {
                                ForEach(ProgramLevel.allCases) { lv in
                                    Text(lv.title).tag(lv)
                                }
                            }
                            .pickerStyle(.segmented)

                            Text(level.blurb)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.leading, ProfileChrome.exerciseSectionTitleLeading)

                            if previewRows.isEmpty {
                                Text("Выберите упражнения на первом шаге.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            } else {
                                VStack(spacing: 0) {
                                    HStack {
                                        Text("Упражнение").font(.caption.weight(.semibold))
                                        Spacer()
                                        Text("Неделя 1").font(.caption.weight(.semibold))
                                            .frame(width: 90, alignment: .trailing)
                                        Text("Неделя 4").font(.caption.weight(.semibold))
                                            .frame(width: 90, alignment: .trailing)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(uiColor: .tertiarySystemGroupedBackground))

                                    VStack(spacing: 0) {
                                        ForEach(Array(previewRows.enumerated()), id: \.element.id) { idx, row in
                                            if idx > 0 { Divider() }
                                            HStack {
                                                Text(row.label)
                                                    .font(.footnote)
                                                Spacer()
                                                Text(row.week1)
                                                    .font(.footnote.monospacedDigit())
                                                    .frame(width: 90, alignment: .trailing)
                                                Text(row.week4)
                                                    .font(.footnote.monospacedDigit())
                                                    .frame(width: 90, alignment: .trailing)
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 10)
                                        }
                                    }
                                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                            }
                        }

                        if let errorText {
                            Text(errorText)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                }
                .padding(16)

                Divider()
                HStack(spacing: 10) {
                    if step == .level {
                        Button("Назад") {
                            errorText = nil
                            step = .exercises
                        }
                        .buttonStyle(.bordered)
                    }
                    Spacer(minLength: 0)
                    if step == .exercises {
                        Button("Далее") {
                            if !canGoNext {
                                errorText = "Выберите от \(poolMin) до \(poolMax) упражнений."
                                return
                            }
                            errorText = nil
                            step = .level
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canGoNext)
                    } else {
                        Button(saving ? "Сохранение..." : "Сохранить выбор") {
                            Task { await save() }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(saving || selected.isEmpty)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Текущий")
            .navigationBarTitleDisplayMode(.inline)
            .background {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
            }
            .onAppear(perform: hydrate)
        }
    }

    private var isVip: Bool {
        guard let b = appState.bootstrap else { return false }
        return vipActive(b.user.profile)
    }

    private var poolMin: Int { isVip ? 1 : 2 }
    private var poolMax: Int { isVip ? programCatalog.count : 5 }
    private var canGoNext: Bool { selected.count >= poolMin && selected.count <= poolMax }

    private var stepOneSubtitle: String {
        if isVip {
            return "Выберите упражнения из каталога - удобное вам количество."
        }
        return "Выберите упражнения из каталога - от \(poolMin) до \(poolMax)."
    }

    private struct PreviewRow {
        var id: String
        var label: String
        var week1: String
        var week4: String
    }

    private var previewRows: [PreviewRow] {
        programCatalog
            .filter { selected.contains($0.id) }
            .map { ex in
                let base: Int = switch level {
                case .beginner: ex.baseBeginner
                case .intermediate: ex.baseIntermediate
                case .advanced: ex.baseAdvanced
                }
                let w1 = max(1, base)
                let w4 = max(w1, Int((Double(w1) * level.monthEndRatio).rounded()))
                return PreviewRow(
                    id: ex.id,
                    label: ex.label,
                    week1: formatAmount(w1, unit: ex.unit),
                    week4: formatAmount(w4, unit: ex.unit)
                )
            }
    }

    private func formatAmount(_ n: Int, unit: ProgramUnit) -> String {
        switch unit {
        case .reps: return "\(n)"
        case .sec: return "\(n) с"
        case .min: return "\(n) мин"
        case .km:
            let km = Double(n) / 10.0
            return String(format: "%.1f км", km)
        }
    }

    private func toggleExercise(_ id: String) {
        if selected.contains(id) {
            selected.remove(id)
            errorText = nil
            return
        }
        if selected.count >= poolMax {
            errorText = "Не больше \(poolMax) упражнений."
            return
        }
        selected.insert(id)
        errorText = nil
    }

    private func hydrate() {
        guard let boot = appState.bootstrap else { return }
        let target = currentMoscowTarget()
        let vote = boot.programVotes[monthVoteKey(year: target.year, month: target.month)]
        selected = Set((vote?.exerciseIds ?? []).filter { !$0.hasPrefix("u_") })
        level = ProgramLevel(rawValue: vote?.level ?? "") ?? .beginner
    }

    private func save() async {
        let target = currentMoscowTarget()
        saving = true
        errorText = nil
        defer { saving = false }
        do {
            try await APIClient.shared.putProgramVote(.init(
                targetYear: target.year,
                targetMonth: target.month,
                exerciseIds: Array(selected).sorted(),
                level: level.rawValue,
                startAmounts: [:],
                dowOverrides: nil,
                customExercises: nil
            ))
            await appState.refreshBootstrap()
            dismiss()
        } catch let e as APIClientError {
            errorText = e.message
        } catch {
            errorText = error.localizedDescription
        }
    }
}

private struct IndividualProgramVoteSheet: View {
    private enum Step {
        case pool
        case preview
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var step: Step = .pool
    @State private var customPool: [CustomProgramExercise] = []
    @State private var selectedIds: Set<String> = []
    @State private var dowSelection: [String: Set<String>] = [:]
    @State private var newLabel = ""
    @State private var newUnit: ProgramUnit = .reps
    @State private var newAmount = ""
    @State private var newDow: String?
    @State private var saving = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if !isVip {
                            premiumOnlyView
                        } else if step == .pool {
                            poolStepView
                        } else {
                            previewStepView
                        }

                        if let errorText {
                            Text(errorText)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, ProfileChrome.exerciseSectionTitleLeading)
                        }
                    }
                }
                .padding(16)

                Divider()
                footerButtons
                    .padding(16)
            }
            .navigationTitle("Индивидуальный")
            .navigationBarTitleDisplayMode(.inline)
            .background {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
            }
            .onAppear(perform: hydrate)
        }
    }

    private var isVip: Bool {
        guard let b = appState.bootstrap else { return false }
        return vipActive(b.user.profile)
    }

    private var premiumOnlyView: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Индивидуальный план")
                    .font(.title3.weight(.bold))
                Text("Раздел доступен только с подпиской Премиум.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, ProfileChrome.exerciseSectionTitleLeading)

            VStack(alignment: .leading, spacing: 10) {
                Text("С Премиум вы сможете собрать свой пул упражнений, разнести их по дням недели и сохранить персональный план месяца.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                Text("Откройте Премиум в профиле, чтобы активировать этот раздел.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: ProfileChrome.radiusXl, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
        }
    }

    private var poolStepView: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Пул упражнений")
                    .font(.title3.weight(.bold))
                Text("Добавьте свои упражнения, укажите единицу, количество (по желанию) и день недели.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, ProfileChrome.exerciseSectionTitleLeading)

            VStack(spacing: 0) {
                if customPool.isEmpty {
                    Text("Добавьте хотя бы одно упражнение, чтобы продолжить.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, ProfileChrome.exerciseRowPaddingH)
                        .padding(.vertical, 14)
                } else {
                    ForEach(Array(customPool.enumerated()), id: \.element.id) { idx, ex in
                        if idx > 0 {
                            Divider()
                                .padding(.leading, ProfileChrome.exercisePlanDividerLeading)
                        }
                        HStack(alignment: .top, spacing: 10) {
                            Button {
                                togglePoolSelection(ex.id)
                            } label: {
                                Image(systemName: selectedIds.contains(ex.id) ? "checkmark.square.fill" : "square")
                                    .font(.title3)
                                    .foregroundStyle(selectedIds.contains(ex.id) ? Color.accentColor : .secondary)
                                    .padding(.top, 2)
                            }
                            .buttonStyle(.plain)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(ex.label)
                                    .font(.body.weight(.semibold))
                                Text(exerciseMetaText(ex))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Button {
                                removeCustom(ex.id)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.body)
                                    .foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, ProfileChrome.exerciseRowPaddingH)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: ProfileChrome.radiusXl, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )

            VStack(alignment: .leading, spacing: 10) {
                Text("Добавить упражнение")
                    .font(.headline)
                    .padding(.leading, ProfileChrome.exerciseSectionTitleLeading)

                VStack(spacing: 10) {
                    formFieldShell {
                        TextField("Название (например, Жим лежа)", text: $newLabel)
                            .textInputAutocapitalization(.sentences)
                    }

                    Picker("Единица", selection: $newUnit) {
                        ForEach(ProgramUnit.allCases) { u in
                            Text(u.title).tag(u)
                        }
                    }
                    .pickerStyle(.segmented)

                    formFieldShell {
                        TextField("Количество (необязательно)", text: $newAmount)
                            .keyboardType(.numberPad)
                    }

                    HStack(spacing: 10) {
                        Menu {
                            ForEach(isoDow, id: \.self) { day in
                                Button(dowTitles[day] ?? day) {
                                    newDow = day
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                Text(newDow.flatMap { dowTitles[$0] } ?? "День")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.down")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .frame(minHeight: ProfileChrome.profileBarFixedHeight, maxHeight: ProfileChrome.profileBarFixedHeight)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                            )
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)

                        Button(action: addCustom) {
                            Text("Добавить в пул")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: ProfileChrome.profileBarFixedHeight, maxHeight: ProfileChrome.profileBarFixedHeight)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(Color(red: ProfileChrome.accentBlue.red, green: ProfileChrome.accentBlue.green, blue: ProfileChrome.accentBlue.blue))
                                )
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: ProfileChrome.radiusXl, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                )
            }
        }
    }

    private var previewStepView: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Превью")
                    .font(.title3.weight(.bold))
                Text("Календарь показывает дни с тренировками и нагрузку по количеству упражнений.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, ProfileChrome.exerciseSectionTitleLeading)

            VStack(alignment: .leading, spacing: 10) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                    ForEach(["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"], id: \.self) { w in
                        Text(w)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }

                    ForEach(0 ..< previewLeading, id: \.self) { _ in
                        Color.clear
                            .frame(height: 56)
                    }

                    ForEach(previewCalendarDays) { day in
                        previewDayCell(day)
                    }
                }

                if !hasActivePreviewDays {
                    Text("В этом месяце пока нет активных дней — задайте день недели у упражнений на первом шаге.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 2)
                }

                Text("• Точки под числом показывают, сколько упражнений запланировано в этот день.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 2)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: ProfileChrome.radiusXl, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
        }
    }

    @ViewBuilder
    private var footerButtons: some View {
        HStack(spacing: 10) {
            if !isVip {
                Spacer(minLength: 0)
                Button("Понятно") { dismiss() }
                    .buttonStyle(.borderedProminent)
                Spacer(minLength: 0)
            } else if step == .pool {
                Spacer(minLength: 0)
                Button("Далее") {
                    guard !selectedIds.isEmpty else {
                        errorText = "Выберите хотя бы одно упражнение в пуле."
                        return
                    }
                    errorText = nil
                    step = .preview
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Назад") {
                    errorText = nil
                    step = .pool
                }
                .buttonStyle(.bordered)
                Spacer(minLength: 0)
                Button(saving ? "Сохранение..." : "Сохранить выбор") {
                    Task { await save() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(saving || selectedIds.isEmpty)
            }
        }
    }

    private struct PreviewDay: Identifiable {
        var id: String
        var day: Int
        var exerciseCount: Int
        var labels: [String]
    }

    private var selectedPool: [CustomProgramExercise] {
        customPool.filter { selectedIds.contains($0.id) }
    }

    private func formFieldShell<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .font(.body)
            .padding(.horizontal, 16)
            .frame(minHeight: ProfileChrome.profileBarFixedHeight, maxHeight: ProfileChrome.profileBarFixedHeight)
            .background(
                Capsule()
                    .fill(Color(uiColor: .tertiarySystemGroupedBackground))
            )
    }

    private func assignedDow(for exerciseId: String) -> String? {
        for day in isoDow {
            if dowSelection[day]?.contains(exerciseId) == true {
                return day
            }
        }
        return nil
    }

    private func assignDay(_ day: String, for exerciseId: String) {
        for key in isoDow {
            var set = dowSelection[key] ?? []
            set.remove(exerciseId)
            if key == day {
                set.insert(exerciseId)
            }
            dowSelection[key] = set
        }
    }

    private func exerciseMetaText(_ ex: CustomProgramExercise) -> String {
        let day = assignedDow(for: ex.id).flatMap { dowTitles[$0] } ?? "день не выбран"
        let amountText: String
        if let amount = ex.amount, amount > 0 {
            amountText = "\(amount) \(ex.unit.title.lowercased())"
        } else {
            amountText = "без количества"
        }
        return "\(amountText) · \(day)"
    }

    private var hasActivePreviewDays: Bool {
        previewCalendarDays.contains { $0.exerciseCount > 0 }
    }

    private var previewCalendarDays: [PreviewDay] {
        let target = currentMoscowTarget()
        let calendarId = monthVoteKey(year: target.year, month: target.month)
        let monthDays = MoscowCalendar.daysInMonth(calendarId: calendarId)

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Moscow") ?? .current

        var rows: [PreviewDay] = []
        for day in 1 ... monthDays {
            var comp = DateComponents()
            comp.year = target.year
            comp.month = target.month
            comp.day = day
            guard let date = cal.date(from: comp) else { continue }
            let swiftWeekday = cal.component(.weekday, from: date)
            let isoDay = String(swiftWeekday == 1 ? 7 : swiftWeekday - 1)
            let ids = (dowSelection[isoDay] ?? []).filter { selectedIds.contains($0) }
            let names = selectedPool
                .filter { ids.contains($0.id) }
                .map(\.label)
                .sorted()
            rows.append(.init(
                id: "\(target.year)-\(target.month)-\(day)",
                day: day,
                exerciseCount: ids.count,
                labels: names
            ))
        }
        return rows
    }

    private var previewLeading: Int {
        let target = currentMoscowTarget()
        let calendarId = monthVoteKey(year: target.year, month: target.month)
        return max(0, MoscowCalendar.firstWeekdayMonday1Sunday7(calendarId: calendarId) - 1)
    }

    private func previewDayCell(_ day: PreviewDay) -> some View {
        VStack(spacing: 6) {
            Text("\(day.day)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
            HStack(spacing: 3) {
                ForEach(0 ..< min(day.exerciseCount, 4), id: \.self) { _ in
                    Circle()
                        .fill(Color(red: ProfileChrome.accentBlue.red, green: ProfileChrome.accentBlue.green, blue: ProfileChrome.accentBlue.blue))
                        .frame(width: 5, height: 5)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .tertiarySystemGroupedBackground))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("День \(day.day)")
        .accessibilityValue("\(day.exerciseCount) упражнений: \(day.labels.joined(separator: ", "))")
    }

    private func hydrate() {
        guard let boot = appState.bootstrap else { return }
        let target = currentMoscowTarget()
        let vote = boot.programVotes[monthVoteKey(year: target.year, month: target.month)]

        var source: [CustomProgramExercise] = []
        for (id, def) in boot.customExerciseLibrary {
            let amount = vote?.startAmounts?[id]
            source.append(CustomProgramExercise(
                id: id,
                label: def.label,
                unit: ProgramUnit(rawValue: def.unit) ?? .reps,
                amount: amount
            ))
        }
        customPool = source.sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
        selectedIds = Set((vote?.exerciseIds ?? []).filter { $0.hasPrefix("u_") })

        var dow: [String: Set<String>] = [:]
        for day in isoDow {
            let ids = vote?.dowOverrides?[day] ?? Array(selectedIds)
            dow[day] = Set(ids.filter { selectedIds.contains($0) })
        }
        dowSelection = dow
    }

    private func addCustom() {
        let label = newLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty else {
            errorText = "Введите название упражнения."
            return
        }
        let trimmedAmount = newAmount.trimmingCharacters(in: .whitespacesAndNewlines)
        let amount: Int? = trimmedAmount.isEmpty ? nil : Int(trimmedAmount)
        if trimmedAmount.isEmpty == false, amount == nil || amount == 0 {
            errorText = "Количество должно быть больше нуля, либо оставьте поле пустым."
            return
        }

        guard let selectedDow = newDow else {
            errorText = "Выберите день недели."
            return
        }

        let item = CustomProgramExercise(
            id: newCustomExerciseId(),
            label: label,
            unit: newUnit,
            amount: amount
        )
        customPool.append(item)
        customPool.sort { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
        selectedIds.insert(item.id)
        assignDay(selectedDow, for: item.id)
        newLabel = ""
        newAmount = ""
        newDow = nil
        errorText = nil
    }

    private func removeCustom(_ id: String) {
        selectedIds.remove(id)
        for day in isoDow {
            dowSelection[day]?.remove(id)
        }
        customPool.removeAll { $0.id == id }
    }

    private func togglePoolSelection(_ id: String) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
            for day in isoDow {
                dowSelection[day]?.remove(id)
            }
        } else {
            selectedIds.insert(id)
            if assignedDow(for: id) == nil {
                assignDay("1", for: id)
            }
        }
        errorText = nil
    }

    private func save() async {
        let target = currentMoscowTarget()
        saving = true
        errorText = nil
        defer { saving = false }

        let selectedCustom = selectedPool
        guard !selectedCustom.isEmpty else {
            errorText = "Выберите минимум одно упражнение."
            return
        }

        do {
            for ex in selectedCustom {
                try await APIClient.shared.postCustomExercise(.init(
                    id: ex.id,
                    exercise: .init(
                        label: ex.label,
                        unit: ex.unit.rawValue,
                        base: nil,
                        monthEndMultiplier: nil
                    )
                ))
            }

            let allSorted = selectedCustom.map(\.id).sorted()
            let allSet = Set(allSorted)
            var dowPayload: [String: [String]] = [:]
            for day in isoDow {
                let ids = Array((dowSelection[day] ?? allSet).filter { allSet.contains($0) }).sorted()
                if ids != allSorted {
                    dowPayload[day] = ids
                }
            }

            var customPayload: [String: CustomExerciseDef] = [:]
            var startAmounts: [String: Int] = [:]
            for ex in selectedCustom {
                customPayload[ex.id] = CustomExerciseDef(
                    label: ex.label,
                    unit: ex.unit.rawValue,
                    base: nil,
                    monthEndMultiplier: nil
                )
                if let amount = ex.amount, amount > 0 {
                    startAmounts[ex.id] = amount
                }
            }

            try await APIClient.shared.putProgramVote(.init(
                targetYear: target.year,
                targetMonth: target.month,
                exerciseIds: allSorted,
                level: ProgramLevel.beginner.rawValue,
                startAmounts: startAmounts.isEmpty ? nil : startAmounts,
                dowOverrides: dowPayload.isEmpty ? nil : dowPayload,
                customExercises: customPayload
            ))
            await appState.refreshBootstrap()
            dismiss()
        } catch let e as APIClientError {
            errorText = e.message
        } catch {
            errorText = error.localizedDescription
        }
    }
}

