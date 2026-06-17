import SwiftUI

struct ProfileView: View {
    @Environment(AppDataStore.self) private var store
    @State private var selectedRecord: FishCareRecord?
    @State private var selectedAchievement: Achievement?
    @State private var showProfileEditor = false

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    private let badgeColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    private var records: [FishCareRecord] {
        store.careRecords.sorted { $0.recordedAt > $1.recordedAt }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    profileHeader
                        .padding(.horizontal)
                        .padding(.top, 12)

                    weekGrid
                        .padding(.horizontal)

                    achievementsSection
                        .padding(.horizontal)
                }
                .padding(.bottom, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .dewAppBackground()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gear")
                    }
                    .accessibilityLabel("設定")
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
                    .presentationDetents([.height(260)])
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
                Text(profile?.nickname ?? "あなた")
                    .font(.title3.weight(.bold))
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("\(daysSinceStart)")
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("水やり\(daysSinceStart)日目")
            }

            Spacer()

            Button {
                showProfileEditor = true
            } label: {
                Image(systemName: "pencil")
                    .font(.headline)
                    .foregroundStyle(.teal)
                    .frame(width: 38, height: 38)
                    .background(Color.dewSurfaceSoft, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("プロフィールを編集")
        }
        .padding(16)
        .background(Color.dewSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    // MARK: - Week grid

    private var weekGrid: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(recentWeekDays) { day in
                weekDayCell(day)
            }
        }
    }

    private func weekDayCell(_ day: ProfileWeekDay) -> some View {
        Button {
            selectedRecord = day.record
        } label: {
            VStack(spacing: 5) {
                Text(day.weekday)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text("\(calendar.component(.day, from: day.date))")
                    .font(.subheadline.weight(day.isToday ? .bold : .semibold))
                    .monospacedDigit()

                Spacer(minLength: 0)

                if let record = day.record {
                    recordSymbol(for: record, size: 24).frame(height: 28)

                    HStack(spacing: 2) {
                        Text("+\(record.departuresAfter)💧")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        if day.recordCount > 1 {
                            Text("+\(day.recordCount - 1)")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(recordColor(for: record), in: Capsule())
                        }
                    }
                    .foregroundStyle(.secondary)
                } else {
                    Circle()
                        .fill(.secondary.opacity(0.12))
                        .frame(width: 8, height: 8)
                }

                Spacer(minLength: 0)
            }
            .padding(7)
            .frame(maxWidth: .infinity)
            .aspectRatio(0.68, contentMode: .fit)
            .background(
                day.record == nil ? Color.dewSurfaceSoft : Color.dewSurface,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay {
                if day.isToday {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.teal.opacity(0.7), lineWidth: 1.5)
                }
            }
            .overlay(alignment: .bottom) {
                if let record = day.record {
                    Capsule()
                        .fill(recordColor(for: record).opacity(0.9))
                        .frame(height: 3)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 5)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(day.record == nil)
        .accessibilityLabel(weekDayAccessibilityLabel(for: day))
    }

    // MARK: - Achievements

    private var achievementsSection: some View {
        let unlockedCount = Achievement.allCases.filter { $0.isUnlocked(in: store) }.count
        let totalCount = Achievement.allCases.count

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "trophy.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Spacer()
                Text("\(unlockedCount)/\(totalCount)")
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("実績 \(unlockedCount)個獲得、全\(totalCount)個")

            LazyVGrid(columns: badgeColumns, spacing: 8) {
                ForEach(Achievement.allCases) { achievement in
                    badgeCell(achievement)
                }
            }
        }
        .padding(14)
        .background(Color.dewSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func badgeCell(_ achievement: Achievement) -> some View {
        let unlocked = achievement.isUnlocked(in: store)
        return Button {
            selectedAchievement = achievement
        } label: {
            Text(achievement.emoji)
                .font(.system(size: 28))
                .saturation(unlocked ? 1 : 0)
                .opacity(unlocked ? 1 : 0.35)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
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
        .accessibilityLabel(
            unlocked
                ? "\(achievement.title)、獲得済み"
                : "\(achievement.title)、未獲得"
        )
        .accessibilityHint("タップして詳細を表示")
    }

    // MARK: - Shared subviews

    @ViewBuilder
    private func recordSymbol(for record: FishCareRecord, size: CGFloat) -> some View {
        if record.completedGrowth {
            FishArtworkView(species: record.species)
                .frame(width: size * 1.2, height: size)
        } else {
            Image(systemName: record.growthStage.icon)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(recordColor(for: record))
                .symbolRenderingMode(.hierarchical)
        }
    }

    // MARK: - Helpers

    private var recentWeekDays: [ProfileWeekDay] {
        let recordsByDay = Dictionary(grouping: records) { calendar.startOfDay(for: $0.recordedAt) }
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset - 6, to: calendar.startOfDay(for: .now)) else { return nil }
            let startOfDay = calendar.startOfDay(for: date)
            let dayRecords = recordsByDay[startOfDay] ?? []
            return ProfileWeekDay(
                date: date,
                weekday: date.formatted(.dateTime.weekday(.abbreviated)),
                isToday: calendar.isDateInToday(date),
                record: dayRecords.first,
                recordCount: dayRecords.count
            )
        }
    }

    private func weekDayAccessibilityLabel(for day: ProfileWeekDay) -> String {
        let dateLabel = day.date.formatted(.dateTime.month().day())
        if let record = day.record {
            let growth = record.completedGrowth ? "成魚" : record.growthStage.displayName
            return "\(dateLabel)、しずく\(record.departuresAfter)、\(growth)"
        }
        return "\(dateLabel)、記録なし"
    }

    private func recordColor(for record: FishCareRecord) -> Color {
        record.completedGrowth ? WaterLevelTheme(waterRatio: 1).tintColor : .orange
    }
}

private struct ProfileWeekDay: Identifiable {
    var date: Date
    var weekday: String
    var isToday: Bool
    var record: FishCareRecord?
    var recordCount: Int
    var id: Date { date }
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
                Label("獲得済み", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(achievement.tint)
            } else {
                VStack(spacing: 6) {
                    ProgressView(value: Double(progress.current), total: Double(progress.target))
                        .tint(achievement.tint)
                    Text("\(progress.current) / \(progress.target)")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
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
