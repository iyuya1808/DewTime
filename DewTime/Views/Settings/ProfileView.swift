import SwiftUI

struct ProfileView: View {
    @Environment(AppDataStore.self) private var store
    @State private var selectedRecord: FishCareRecord?
    @State private var selectedAchievement: Achievement?
    @State private var showProfileEditor = false

    private let badgeColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    profileHeader
                        .padding(.horizontal)
                        .padding(.top, 12)

                    DepartureRecordCalendarView(selectedRecord: $selectedRecord)
                        .padding(.horizontal)

                    achievementsSection
                        .padding(.horizontal)
                }
                .padding(.bottom, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(L10n.Tab.profile)
            .dewAppBackground()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gear")
                    }
                    .accessibilityLabel(L10n.Settings.title)
                }
            }
            .sheet(item: $selectedRecord) { record in
                FishCareDetailSheet(record: record)
                    .presentationDetents([.fraction(0.68), .large])
                    .presentationBackground(.clear)
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showProfileEditor) {
                ProfileEditView()
            }
            .sheet(item: $selectedAchievement) { achievement in
                AchievementDetailSheet(achievement: achievement, store: store)
                    .presentationDetents([.height(300)])
            }
        }
    }

    // MARK: - Header

    private var profileHeader: some View {
        let profile = store.profiles.first
        let daysSinceStart = profile?.daysSinceStart ?? 1

        return HStack(spacing: 14) {
            ZStack {
                Circle().fill(.teal.opacity(0.16))
                Text(profile?.avatarEmoji ?? "🐟")
                    .font(.system(size: 34))
            }
            .frame(width: 64, height: 64)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(profile?.nickname ?? L10n.Profile.defaultNickname)
                    .font(.title3.weight(.bold))
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(L10n.Profile.dayCount(daysSinceStart))
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel(L10n.Profile.departureDayAccessibility(daysSinceStart))
            }

            Spacer()

            Button {
                showProfileEditor = true
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "pencil")
                        .font(.headline)
                        .foregroundStyle(.teal)
                    Text(L10n.Profile.edit)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.teal)
                }
                .frame(width: 44, height: 44)
                .background(Color.dewSurfaceSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.Profile.editAccessibility)
        }
        .padding(16)
        .background(Color.dewSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    // MARK: - Achievements

    private var achievementsSection: some View {
        let unlockedCount = Achievement.allCases.filter { $0.isUnlocked(in: store) }.count
        let totalCount = Achievement.allCases.count

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "trophy.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Text(L10n.Profile.achievements)
                    .font(.headline.weight(.bold))
                Spacer()
                Text("\(unlockedCount)/\(totalCount)")
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(L10n.Profile.achievementsAccessibility(unlocked: unlockedCount, total: totalCount))

            ForEach(AchievementCategory.allCases) { category in
                achievementCategoryBlock(category)
            }
        }
        .padding(14)
        .background(Color.dewSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func achievementCategoryBlock(_ category: AchievementCategory) -> some View {
        let achievements = category.achievements
        let unlockedInCategory = achievements.filter { $0.isUnlocked(in: store) }.count

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(category.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(category.tint)
                Text("\(unlockedInCategory)/\(achievements.count)")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: badgeColumns, spacing: 8) {
                ForEach(achievements) { achievement in
                    badgeCell(achievement)
                }
            }
        }
    }

    private func badgeCell(_ achievement: Achievement) -> some View {
        let unlocked = achievement.isUnlocked(in: store)
        return Button {
            selectedAchievement = achievement
        } label: {
            VStack(spacing: 4) {
                Text(achievement.emoji)
                    .font(.system(size: 24))
                    .saturation(unlocked ? 1 : 0)
                    .opacity(unlocked ? 1 : 0.35)
                if unlocked {
                    Text(achievement.title)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 2)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: unlocked ? 64 : 52)
                .background(
                    unlocked ? achievement.tint.opacity(0.16) : Color.dewSurfaceSoft,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .overlay {
                    if unlocked {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(achievement.tint.opacity(0.5), lineWidth: 1.5)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.Profile.achievementAccessibility(title: achievement.title, unlocked: unlocked))
        .accessibilityHint(L10n.Profile.achievementTapHint)
    }
}

// MARK: - Achievement detail

private struct AchievementDetailSheet: View {
    let achievement: Achievement
    let store: AppDataStore

    var body: some View {
        let unlocked = achievement.isUnlocked(in: store)
        let progress = achievement.progress(in: store)

        VStack(spacing: 16) {
            Text(achievement.emoji)
                .font(.system(size: 64))
                .saturation(unlocked ? 1 : 0)
                .opacity(unlocked ? 1 : 0.4)

            VStack(spacing: 6) {
                Text(achievement.title)
                    .font(.title3.weight(.bold))
                Text(achievement.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if unlocked {
                Label(L10n.Profile.achievementUnlocked, systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(achievement.tint)
                if achievement.feedReward > 0 {
                    Label(L10n.Profile.rewardFeed(achievement.feedReward), systemImage: FeedIcon.systemName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            } else {
                VStack(spacing: 6) {
                    ProgressView(value: Double(progress.current), total: Double(progress.target))
                        .tint(achievement.tint)
                    Text("\(progress.current) / \(progress.target)")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    if achievement.feedReward > 0 {
                        Label(L10n.Profile.unlockRewardFeed(achievement.feedReward), systemImage: FeedIcon.systemName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ProfileView()
        .environment(AppDataStore())
}
