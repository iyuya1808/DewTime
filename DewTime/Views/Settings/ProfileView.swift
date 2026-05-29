import SwiftUI
import SwiftData

struct ProfileView: View {
    @Query(sort: \FishCareRecord.recordedAt, order: .reverse) private var records: [FishCareRecord]
    @State private var selectedRecord: FishCareRecord?

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    aquariumHeader
                        .padding(.horizontal)
                        .padding(.top, 12)

                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(recentWeekDays) { day in
                            weekDayCell(day)
                        }
                    }
                    .padding(.horizontal)

                    if weeklyRecords.isEmpty {
                        aquariumEmptyState
                            .padding(.horizontal)
                            .padding(.top, 8)
                    } else {
                        weeklySummary.padding(.horizontal)
                        weekInsights.padding(.horizontal)
                        recentRecords
                    }
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
            .sheet(item: $selectedRecord) { record in
                FishCareDetailSheet(record: record)
                    .presentationDetents([.medium])
                    .presentationBackground(.clear)
                    .presentationDragIndicator(.hidden)
            }
        }
    }

    // MARK: - Aquarium Views

    private var aquariumHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(.teal.opacity(0.16))
                Image(systemName: "fish.fill")
                    .font(.title2)
                    .foregroundStyle(.teal)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text("直近7日の水槽")
                    .font(.title3.weight(.bold))
                Text(weekRangeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            NavigationLink(destination: MonthlyAquariumView()) {
                Image(systemName: "calendar")
                    .font(.headline)
                    .foregroundStyle(.teal)
                    .frame(width: 38, height: 38)
                    .background(.white.opacity(0.56), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(.white.opacity(0.64), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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

    private var weeklySummary: some View {
        HStack(spacing: 8) {
            summaryCard(icon: "drop.fill", value: "\(Int(weeklyRecords.reduce(0) { $0 + $1.waterAmount }.rounded()))", label: "水やり", tint: .cyan)
            summaryCard(icon: "fish.fill", value: "\(weeklyRecords.count)", label: "記録", tint: .teal)
            summaryCard(icon: "sparkles", value: "\(weeklyRecords.filter(\.completedGrowth).count)", label: "成魚", tint: .orange)
        }
    }

    private var weekInsights: some View {
        let best = weeklyRecords.max { $0.waterAmount < $1.waterAmount }
        let streak = longestStreak(in: weeklyRecords)

        return VStack(spacing: 10) {
            HStack {
                insightRow(icon: "flame.fill", title: "連続記録", value: "\(streak)日", tint: .orange)
                Divider().frame(height: 34)
                insightRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "平均進捗",
                    value: "\(Int((averageProgress(in: weeklyRecords) * 100).rounded()))%",
                    tint: .teal
                )
            }

            if let best {
                Button { selectedRecord = best } label: {
                    HStack(spacing: 10) {
                        recordSymbol(for: best, size: 22).frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("この1週間でいちばん水を残した日")
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

    private var recentRecords: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("この1週間の水やり")
                .font(.headline)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(weeklyRecords) { record in
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

    private var aquariumEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "fish")
                .font(.system(size: 48))
                .foregroundStyle(.teal)
            Text("この1週間はまだ静かです")
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

    private var weeklyRecords: [FishCareRecord] {
        let start = recentWeekDays.first?.date ?? calendar.startOfDay(for: .now)
        guard let end = calendar.date(byAdding: .day, value: 7, to: start) else { return [] }
        return records
            .filter { $0.recordedAt >= start && $0.recordedAt < end }
            .sorted { $0.recordedAt > $1.recordedAt }
    }

    private var weekRangeText: String {
        guard let start = recentWeekDays.first?.date, let end = recentWeekDays.last?.date else { return "" }
        return "\(start.formatted(.dateTime.month().day())) - \(end.formatted(.dateTime.month().day()))"
    }

    private func recordColor(for record: FishCareRecord) -> Color {
        record.completedGrowth ? WaterLevelTheme(waterRatio: 1).tintColor : .orange
    }

    private func averageProgress(in records: [FishCareRecord]) -> Double {
        guard !records.isEmpty else { return 0 }
        return records.reduce(0.0) { $0 + $1.progress } / Double(records.count)
    }

    private func longestStreak(in records: [FishCareRecord]) -> Int {
        let days = Set(records.map { calendar.startOfDay(for: $0.recordedAt) }).sorted()
        guard !days.isEmpty else { return 0 }
        var best = 1, current = 1
        for index in days.indices.dropFirst() {
            let previous = days[days.index(before: index)]
            let distance = calendar.dateComponents([.day], from: previous, to: days[index]).day ?? 0
            if distance == 1 { current += 1 } else { current = 1 }
            best = max(best, current)
        }
        return best
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

#Preview {
    ProfileView()
        .modelContainer(for: [UserSchedule.self, RoutineItem.self, CollectedFish.self, ActiveFish.self, FishCareRecord.self, Aquarium.self], inMemory: true)
}
