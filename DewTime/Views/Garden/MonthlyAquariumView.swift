import SwiftUI
import SwiftData

struct MonthlyAquariumView: View {
    @Query(sort: \FishCareRecord.recordedAt, order: .reverse) private var records: [FishCareRecord]

    @State private var displayedMonth = Date()
    @State private var selectedRecord: FishCareRecord?

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    private let weekdaySymbols = Calendar.current.shortStandaloneWeekdaySymbols

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                monthHeader
                    .padding(.horizontal)
                    .padding(.top, 12)

                if !recordsInDisplayedMonth.isEmpty {
                    monthlySummary
                        .padding(.horizontal)
                }

                weekdayHeader
                    .padding(.horizontal)

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(calendarDays) { day in
                        dayCell(day)
                    }
                }
                .padding(.horizontal)

                if recordsInDisplayedMonth.isEmpty {
                    monthEmptyState
                        .padding(.horizontal)
                        .padding(.top, 8)
                } else {
                    monthInsights
                        .padding(.horizontal)
                    monthlyRecords
                }
            }
            .padding(.bottom, 24)
        }
        .navigationTitle("月間カレンダー")
        .navigationBarTitleDisplayMode(.inline)
        .background(
            LinearGradient(colors: [.aquariumTop, .aquariumBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
        .sheet(item: $selectedRecord) { record in
            FishCareDetailSheet(record: record)
                .presentationDetents([.medium])
                .presentationBackground(.clear)
                .presentationDragIndicator(.hidden)
        }
    }

    private var monthHeader: some View {
        HStack {
            Button {
                moveMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 2) {
                Text(displayedMonth, format: .dateTime.year().month(.wide))
                    .font(.title3.weight(.bold))
                Text("月単位で水やり記録を確認")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .onTapGesture {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    displayedMonth = Date()
                }
            }

            Spacer()

            Button {
                moveMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .background(.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func dayCell(_ day: AquariumCalendarDay) -> some View {
        Button {
            selectedRecord = day.record
        } label: {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: day.date))")
                    .font(.caption.weight(day.isToday ? .bold : .medium))
                    .foregroundStyle(day.isCurrentMonth ? Color.primary : Color.secondary.opacity(0.45))
                    .frame(maxWidth: .infinity, alignment: .trailing)

                Spacer(minLength: 0)

                if let record = day.record {
                    recordSymbol(for: record, size: 23)
                        .frame(height: 26)

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
                        .fill(.secondary.opacity(day.isCurrentMonth ? 0.12 : 0.05))
                        .frame(width: 6, height: 6)
                }

                Spacer(minLength: 0)
            }
            .padding(7)
            .frame(maxWidth: .infinity)
            .aspectRatio(0.82, contentMode: .fit)
            .background(day.record == nil ? .white.opacity(day.isCurrentMonth ? 0.46 : 0.22) : .white.opacity(day.isCurrentMonth ? 0.82 : 0.42), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                if day.isToday {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.teal.opacity(0.7), lineWidth: 1.5)
                }
            }
            .overlay(alignment: .bottom) {
                if let record = day.record {
                    Capsule()
                        .fill(recordColor(for: record).opacity(day.isCurrentMonth ? 0.9 : 0.45))
                        .frame(height: 3)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 5)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(day.record == nil)
    }

    private var monthlySummary: some View {
        let records = recordsInDisplayedMonth
        return HStack(spacing: 8) {
            summaryCard(icon: "drop.fill", value: "\(Int(records.reduce(0) { $0 + $1.waterAmount }.rounded()))", label: "水やり", tint: .cyan)
            summaryCard(icon: "fish.fill", value: "\(records.count)", label: "記録", tint: .teal)
            summaryCard(icon: "sparkles", value: "\(records.filter(\.completedGrowth).count)", label: "成魚", tint: .orange)
        }
    }

    private var monthInsights: some View {
        let records = recordsInDisplayedMonth
        let best = records.max { $0.waterAmount < $1.waterAmount }
        let streak = longestStreak(in: records)

        return VStack(spacing: 10) {
            HStack {
                insightRow(icon: "flame.fill", title: "最長連続", value: "\(streak)日", tint: .orange)
                Divider().frame(height: 34)
                insightRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "平均進捗",
                    value: "\(Int((averageProgress(in: records) * 100).rounded()))%",
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
                            Text("今月いちばん水を残した日")
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

    private var monthlyRecords: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("今月の水やり")
                .font(.headline)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(recordsInDisplayedMonth) { record in
                        Button {
                            selectedRecord = record
                        } label: {
                            VStack(spacing: 6) {
                                recordSymbol(for: record, size: 28)
                                Text(record.recordedAt, format: .dateTime.day())
                                    .font(.caption2.weight(.semibold))
                                Text("+\(Int(record.waterAmount.rounded()))pt")
                                    .font(.caption2.bold())
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 78, height: 86)
                            .background(.white.opacity(0.68), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var monthEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 38))
                .foregroundStyle(.teal)
            Text("この月はまだ静かです")
                .font(.headline)
            Text("別の月へ移動するか、次の朝に水やり記録を残しましょう")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    displayedMonth = Date()
                }
            } label: {
                Label("今月へ戻る", systemImage: "arrow.uturn.backward")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(.white.opacity(0.62), in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal)
        .background(.white.opacity(0.56), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    /// 成魚なら魚の絵文字、それ以外は成長段階の SF Symbol を表示する。
    @ViewBuilder
    private func recordSymbol(for record: FishCareRecord, size: CGFloat) -> some View {
        if record.completedGrowth {
            Text(record.species.emoji)
                .font(.system(size: size))
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
        .background(.white.opacity(0.68), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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

    private var calendarDays: [AquariumCalendarDay] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
              let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start),
              let lastWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.end.addingTimeInterval(-1))
        else { return [] }

        let recordsByDay = Dictionary(grouping: records) { record in
            calendar.startOfDay(for: record.recordedAt)
        }
        let days = calendar.dateComponents([.day], from: firstWeek.start, to: lastWeek.end).day ?? 0

        return (0..<days).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: firstWeek.start) else { return nil }
            let startOfDay = calendar.startOfDay(for: date)
            let dayRecords = recordsByDay[startOfDay] ?? []
            return AquariumCalendarDay(
                date: date,
                isCurrentMonth: calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month),
                isToday: calendar.isDateInToday(date),
                record: dayRecords.first,
                recordCount: dayRecords.count
            )
        }
    }

    private var recordsInDisplayedMonth: [FishCareRecord] {
        records
            .filter { calendar.isDate($0.recordedAt, equalTo: displayedMonth, toGranularity: .month) }
            .sorted { $0.recordedAt > $1.recordedAt }
    }

    private func moveMonth(by amount: Int) {
        displayedMonth = calendar.date(byAdding: .month, value: amount, to: displayedMonth) ?? displayedMonth
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

private struct AquariumCalendarDay: Identifiable {
    var date: Date
    var isCurrentMonth: Bool
    var isToday: Bool
    var record: FishCareRecord?
    var recordCount: Int

    var id: Date { date }
}

#Preview {
    NavigationStack {
        MonthlyAquariumView()
            .modelContainer(for: [UserSchedule.self, RoutineItem.self, CollectedFish.self, ActiveFish.self, FishCareRecord.self, Aquarium.self], inMemory: true)
    }
}
