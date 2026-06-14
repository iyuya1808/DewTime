import SwiftUI

struct AquariumView: View {
    @Environment(AppDataStore.self) private var store

    @State private var selectedRecord: FishCareRecord?

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    private var records: [FishCareRecord] {
        store.careRecords.sorted { $0.recordedAt > $1.recordedAt }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    weekHeader
                        .padding(.horizontal)
                        .padding(.top, 12)

                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(recentWeekDays) { day in
                            weekDayCell(day)
                        }
                    }
                    .padding(.horizontal)

                    if weeklyRecords.isEmpty {
                        emptyState
                            .padding(.horizontal)
                            .padding(.top, 8)
                    } else {
                        weeklySummary
                            .padding(.horizontal)
                        weekInsights
                            .padding(.horizontal)
                        recentRecords
                    }
                }
                .padding(.bottom, 24)
            }
            .navigationTitle("水槽")
            .dewAppBackground()
        }
        .sheet(item: $selectedRecord) { record in
            FishCareDetailSheet(record: record)
                .presentationDetents([.fraction(0.68), .large])
                .presentationBackground(.clear)
                .presentationDragIndicator(.visible)
        }
    }

    private var weekHeader: some View {
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

            NavigationLink {
                MonthlyAquariumView()
            } label: {
                Image(systemName: "calendar")
                    .font(.headline)
                    .foregroundStyle(.teal)
                    .frame(width: 38, height: 38)
                    .background(Color.dewSurfaceSoft, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.dewSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func weekDayCell(_ day: AquariumWeekDay) -> some View {
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
                    recordSymbol(for: record, size: 24)
                        .frame(height: 28)

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
            .background(day.record == nil ? Color.dewSurfaceSoft : Color.dewSurface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                Button {
                    selectedRecord = best
                } label: {
                    HStack(spacing: 10) {
                        recordSymbol(for: best, size: 22)
                            .frame(width: 28)
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
                    .background(Color.dewSurfaceSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color.dewSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var recentRecords: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("この1週間の水やり")
                .font(.headline)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(weeklyRecords) { record in
                        Button {
                            selectedRecord = record
                        } label: {
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
                            .background(Color.dewSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    /// 成魚なら魚の姿、それ以外は成長段階の SF Symbol を表示する。
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

    private func summaryCard(icon: String, value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
            Text(value)
                .font(.title3.weight(.bold))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.dewSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func insightRow(icon: String, title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline)
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
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
        .background(Color.dewSurfaceSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var recentWeekDays: [AquariumWeekDay] {
        let recordsByDay = Dictionary(grouping: records) { record in
            calendar.startOfDay(for: record.recordedAt)
        }
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset - 6, to: calendar.startOfDay(for: .now)) else {
                return nil
            }
            let startOfDay = calendar.startOfDay(for: date)
            let dayRecords = recordsByDay[startOfDay] ?? []
            return AquariumWeekDay(
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
        guard let start = recentWeekDays.first?.date,
              let end = recentWeekDays.last?.date else { return "" }
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

        var best = 1
        var current = 1
        for index in days.indices.dropFirst() {
            let previous = days[days.index(before: index)]
            let distance = calendar.dateComponents([.day], from: previous, to: days[index]).day ?? 0
            if distance == 1 {
                current += 1
            } else {
                current = 1
            }
            best = max(best, current)
        }
        return best
    }
}

private struct AquariumWeekDay: Identifiable {
    var date: Date
    var weekday: String
    var isToday: Bool
    var record: FishCareRecord?
    var recordCount: Int

    var id: Date { date }
}

struct FishCareDetailSheet: View {
    let record: FishCareRecord
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Group {
                if colorScheme == .dark {
                    Color(red: 0.02, green: 0.06, blue: 0.10)
                } else {
                    LinearGradient(colors: [.aquariumTop, .aquariumBottom], startPoint: .top, endPoint: .bottom)
                }
            }
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {

                    ZStack {
                        Circle()
                            .fill(recordColor.opacity(0.16))
                            .frame(width: 112, height: 112)
                        if record.completedGrowth {
                            FishArtworkView(species: record.species)
                                .frame(width: 82, height: 76)
                        } else {
                            Image(systemName: record.growthStage.icon)
                                .font(.system(size: 58, weight: .semibold))
                                .foregroundStyle(recordColor)
                                .symbolRenderingMode(.hierarchical)
                        }
                    }

                    VStack(spacing: 6) {
                        Text(record.completedGrowth ? "\(record.species.displayName)が成魚になりました" : record.growthStage.message)
                            .font(.title2.weight(.bold))
                            .multilineTextAlignment(.center)
                        Text(record.recordedAt, format: .dateTime.year().month().day().hour().minute())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 10) {
                        metric(icon: "drop.fill", value: "+\(Int(record.waterAmount.rounded()))pt", label: "今回", tint: .cyan)
                        metric(
                            icon: "chart.line.uptrend.xyaxis",
                            value: "\(Int(record.totalWaterAfter.rounded()))/\(Int(record.requiredTotalWater.rounded()))pt",
                            label: "合計",
                            tint: recordColor
                        )
                    }

                    Text(record.completedGrowth ? "成魚になった魚は図鑑に登録されています。" : "次の朝も水を残して、この魚を育てましょう。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
            }
        }
    }

    private func metric(icon: String, value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
            Text(value)
                .font(.headline)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.dewSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var recordColor: Color {
        record.completedGrowth ? WaterLevelTheme(waterRatio: 1).tintColor : .orange
    }
}

#Preview {
    AquariumView()
        .environment(AppDataStore())
}
