import SwiftUI

struct ProfileView: View {
    @Environment(AppDataStore.self) private var store
    @State private var selectedRecord: FishCareRecord?
    @State private var selectedAchievement: Achievement?
    @State private var period: ProfilePeriod = .week
    @State private var showProfileEditor = false

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    private let badgeColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    private var records: [FishCareRecord] {
        store.careRecords.sorted { $0.recordedAt > $1.recordedAt }
    }

    private var filteredRecords: [FishCareRecord] {
        period.filter(records)
    }

    private var stats: ProfileStats {
        ProfileStats(records: filteredRecords, calendar: calendar)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    profileHeader
                        .padding(.horizontal)
                        .padding(.top, 12)

                    periodPicker
                        .padding(.horizontal)

                    if filteredRecords.isEmpty {
                        statsEmptyState
                            .padding(.horizontal)
                    } else {
                        statsSummary.padding(.horizontal)
                        statsInsights.padding(.horizontal)
                    }

                    activitySection

                    if !filteredRecords.isEmpty {
                        recentRecords
                    }

                    achievementsSection
                        .padding(.horizontal)
                }
                .padding(.bottom, 32)
            }
            .navigationTitle("プロフィール")
            .background(
                LinearGradient(colors: [.aquariumTop, .aquariumBottom], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gear")
                    }
                }
            }
            .environment(\.colorScheme, .light)
            .sheet(item: $selectedRecord) { record in
                FishCareDetailSheet(record: record)
                    .presentationDetents([.fraction(0.68), .large])
                    .presentationBackground(.clear)
                    .presentationDragIndicator(.visible)
                    .environment(\.colorScheme, .light)
            }
            .sheet(isPresented: $showProfileEditor) {
                ProfileEditView()
                    .environment(\.colorScheme, .light)
            }
            .sheet(item: $selectedAchievement) { achievement in
                AchievementDetailSheet(achievement: achievement, store: store)
                    .presentationDetents([.height(260)])
                    .environment(\.colorScheme, .light)
            }
        }
    }

    // MARK: - Header

    private var profileHeader: some View {
        let profile = store.profiles.first
        let aquarium = store.aquariums.first
        let dexCount = Set(store.collectedFishes.map(\.speciesId)).count
        let totalSpecies = FishSpecies.allCases.count

        return VStack(spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(.teal.opacity(0.16))
                    Text(profile?.avatarEmoji ?? "🐟")
                        .font(.system(size: 34))
                }
                .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 3) {
                    Text(profile?.nickname ?? "あなた")
                        .font(.title3.weight(.bold))
                    Text("水やり \(profile?.daysSinceStart ?? 1)日目")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    showProfileEditor = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.headline)
                        .foregroundStyle(.teal)
                        .frame(width: 38, height: 38)
                        .background(.white.opacity(0.56), in: Circle())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                headerMetric(icon: "drop.fill", value: Aquarium.sizeName(for: aquarium?.sizeTier ?? 0), label: "水槽", tint: .teal)
                headerMetric(icon: "book.fill", value: "\(dexCount)/\(totalSpecies)", label: "図鑑", tint: .purple)
                headerMetric(icon: "drop.circle.fill", value: "\(Int((aquarium?.totalWaterCollected ?? 0).rounded()))", label: "累計pt", tint: .cyan)
            }
        }
        .padding(16)
        .background(.white.opacity(0.64), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func headerMetric(icon: String, value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.subheadline).foregroundStyle(tint)
            Text(value)
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var periodPicker: some View {
        Picker("期間", selection: $period) {
            ForEach(ProfilePeriod.allCases) { period in
                Text(period.title).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Stats

    private var statsSummary: some View {
        HStack(spacing: 8) {
            summaryCard(icon: "drop.fill", value: "\(Int(stats.totalWater.rounded()))", label: "水やり", tint: .cyan)
            summaryCard(icon: "fish.fill", value: "\(stats.wateringCount)", label: "記録", tint: .teal)
            summaryCard(icon: "sparkles", value: "\(stats.adultCount)", label: "成魚", tint: .orange)
        }
    }

    private var statsInsights: some View {
        let best = filteredRecords.max { $0.waterAmount < $1.waterAmount }

        return VStack(spacing: 10) {
            HStack {
                insightRow(icon: "flame.fill", title: "連続記録", value: "\(stats.longestStreak)日", tint: .orange)
                Divider().frame(height: 34)
                insightRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "平均進捗",
                    value: "\(Int((stats.averageProgress * 100).rounded()))%",
                    tint: .teal
                )
            }

            if let best {
                Button { selectedRecord = best } label: {
                    HStack(spacing: 10) {
                        recordSymbol(for: best, size: 22).frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("いちばん水を残した日")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(best.recordedAt.formatted(.dateTime.month().day())) / +\(Int(best.waterAmount.rounded()))pt")
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(.white.opacity(0.52), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(.white.opacity(0.66), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Activity

    @ViewBuilder
    private var activitySection: some View {
        switch period {
        case .week:
            VStack(spacing: 0) {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(recentWeekDays) { day in
                        weekDayCell(day)
                    }
                }
                .padding(.horizontal)
            }
        case .month:
            NavigationLink(destination: MonthlyAquariumView()) {
                HStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .font(.title2)
                        .foregroundStyle(.teal)
                        .frame(width: 40, height: 40)
                        .background(.white.opacity(0.56), in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("今月の水槽をカレンダーで見る")
                            .font(.subheadline.weight(.semibold))
                        Text("日ごとの水やりをまとめて確認")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .background(.white.opacity(0.64), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
        case .all:
            monthlySummary.padding(.horizontal)
        }
    }

    private var monthlySummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("月別のふりかえり")
                .font(.headline)

            ForEach(monthlyBuckets, id: \.id) { bucket in
                HStack(spacing: 12) {
                    Text(bucket.title)
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 84, alignment: .leading)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(bucket.count)回 / +\(Int(bucket.water.rounded()))pt")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ProgressView(value: monthlyBuckets.map(\.water).max().map { $0 > 0 ? bucket.water / $0 : 0 } ?? 0)
                            .tint(.teal)
                    }
                    if bucket.adults > 0 {
                        Text("🎉\(bucket.adults)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.orange)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(14)
        .background(.white.opacity(0.66), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
                        Text("+\(Int(record.waterAmount.rounded()))")
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
                    Text("未記録")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary.opacity(0.7))
                }

                Spacer(minLength: 0)
            }
            .padding(7)
            .frame(maxWidth: .infinity)
            .aspectRatio(0.68, contentMode: .fit)
            .background(
                day.record == nil ? .white.opacity(0.46) : .white.opacity(0.82),
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
    }

    // MARK: - Recent records

    private var recentRecords: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("水やりの記録")
                .font(.headline)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(filteredRecords) { record in
                        Button { selectedRecord = record } label: {
                            VStack(spacing: 6) {
                                recordSymbol(for: record, size: 28)
                                Text(record.recordedAt, format: .dateTime.month().day())
                                    .font(.caption2.weight(.semibold))
                                Text("+\(Int(record.waterAmount.rounded()))pt")
                                    .font(.caption2.bold())
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 82, height: 88)
                            .background(.white.opacity(0.68), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Achievements

    private var achievementsSection: some View {
        let unlockedCount = Achievement.allCases.filter { $0.isUnlocked(in: store) }.count

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("実績")
                    .font(.headline)
                Spacer()
                Text("\(unlockedCount)/\(Achievement.allCases.count)")
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: badgeColumns, spacing: 10) {
                ForEach(Achievement.allCases) { achievement in
                    badgeCell(achievement)
                }
            }
        }
        .padding(14)
        .background(.white.opacity(0.66), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func badgeCell(_ achievement: Achievement) -> some View {
        let unlocked = achievement.isUnlocked(in: store)
        return Button {
            selectedAchievement = achievement
        } label: {
            VStack(spacing: 6) {
                Text(achievement.emoji)
                    .font(.system(size: 30))
                    .saturation(unlocked ? 1 : 0)
                    .opacity(unlocked ? 1 : 0.35)
                Text(achievement.title)
                    .font(.system(size: 10, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .foregroundStyle(unlocked ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 78)
            .background(
                unlocked ? achievement.tint.opacity(0.16) : .white.opacity(0.4),
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
    }

    // MARK: - Empty state

    private var statsEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "fish")
                .font(.system(size: 48))
                .foregroundStyle(.teal)
            Text(period == .all ? "まだ記録がありません" : "この期間はまだ静かです")
                .font(.headline)
            Text("タイマー画面で「いってきます！」を押すと、今日の魚に水やり記録が残ります")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal)
        .background(.white.opacity(0.56), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Shared subviews

    @ViewBuilder
    private func recordSymbol(for record: FishCareRecord, size: CGFloat) -> some View {
        if record.completedGrowth {
            Text(record.species.emoji).font(.system(size: size))
        } else {
            Image(systemName: record.growthStage.icon)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(recordColor(for: record))
                .symbolRenderingMode(.hierarchical)
        }
    }

    private func summaryCard(icon: String, value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title3).foregroundStyle(tint)
            Text(value).font(.title3.weight(.bold)).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.white.opacity(0.68), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func insightRow(icon: String, title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon).font(.title3).foregroundStyle(tint).frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.headline).monospacedDigit()
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
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

    private var monthlyBuckets: [ProfileMonthBucket] {
        let grouped = Dictionary(grouping: records) { record -> DateComponents in
            calendar.dateComponents([.year, .month], from: record.recordedAt)
        }
        return grouped.compactMap { components, monthRecords -> ProfileMonthBucket? in
            guard let date = calendar.date(from: components) else { return nil }
            return ProfileMonthBucket(
                date: date,
                title: date.formatted(.dateTime.year().month()),
                count: monthRecords.count,
                water: monthRecords.reduce(0) { $0 + $1.waterAmount },
                adults: monthRecords.filter(\.completedGrowth).count
            )
        }
        .sorted { $0.date > $1.date }
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

private struct ProfileMonthBucket: Identifiable {
    var date: Date
    var title: String
    var count: Int
    var water: Double
    var adults: Int
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
