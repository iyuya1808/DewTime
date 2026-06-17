import SwiftUI

struct MonthlyAquariumView: View {
    @Environment(AppDataStore.self) private var store

    @State private var displayedMonth = Date()
    @State private var selectedRecord: FishCareRecord?

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    private let weekdaySymbols = Calendar.current.shortStandaloneWeekdaySymbols

    private var records: [FishCareRecord] {
        store.careRecords.sorted { $0.recordedAt > $1.recordedAt }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                monthHeader
                    .padding(.horizontal)
                    .padding(.top, 12)

                weekdayHeader
                    .padding(.horizontal)

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(calendarDays) { day in
                        dayCell(day)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 24)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Image(systemName: "calendar")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.teal)
                    .accessibilityLabel("育成記録")
            }
        }
        .dewAppBackground()
        .sheet(item: $selectedRecord) { record in
            FishCareDetailSheet(record: record)
                .presentationDetents([.fraction(0.68), .large])
                .presentationBackground(.clear)
                .presentationDragIndicator(.visible)
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
            .accessibilityLabel("前の月")

            Spacer()

            Text(displayedMonth, format: .dateTime.year().month(.wide))
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        displayedMonth = Date()
                    }
                }
                .accessibilityLabel(displayedMonth.formatted(.dateTime.year().month(.wide)))
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("タップで今月に戻ります")

            Spacer()

            Button {
                moveMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("次の月")
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .background(Color.dewSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("曜日")
    }

    private func dayCell(_ day: AquariumCalendarDay) -> some View {
        Button {
            selectedRecord = day.record
        } label: {
            VStack(spacing: 6) {
                Text("\(calendar.component(.day, from: day.date))")
                    .font(.caption.weight(day.isToday ? .bold : .medium))
                    .foregroundStyle(day.isCurrentMonth ? Color.primary : Color.secondary.opacity(0.45))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .monospacedDigit()

                Spacer(minLength: 0)

                if let record = day.record {
                    recordSymbol(for: record, size: 22)
                        .frame(height: 24)
                }

                Spacer(minLength: 0)
            }
            .padding(7)
            .frame(maxWidth: .infinity)
            .aspectRatio(0.82, contentMode: .fit)
            .background(
                day.record == nil
                    ? Color.dewSurfaceSoft.opacity(day.isCurrentMonth ? 1 : 0.55)
                    : Color.dewSurface.opacity(day.isCurrentMonth ? 1 : 0.58),
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
                        .fill(recordColor(for: record).opacity(day.isCurrentMonth ? 0.9 : 0.45))
                        .frame(height: 3)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 5)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(day.record == nil)
        .accessibilityLabel(dayAccessibilityLabel(day))
    }

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

    private func dayAccessibilityLabel(_ day: AquariumCalendarDay) -> String {
        let dateText = day.date.formatted(.dateTime.month().day())
        guard let record = day.record else {
            return "\(dateText)、未記録"
        }
        let dropText = record.earnedDrop ? "しずく1" : "しずくなし"
        let stageText = record.completedGrowth ? "成魚" : record.growthStage.displayName
        if day.recordCount > 1 {
            return "\(dateText)、記録\(day.recordCount)件、\(dropText)、\(stageText)"
        }
        return "\(dateText)、\(dropText)、\(stageText)"
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

    private func moveMonth(by amount: Int) {
        displayedMonth = calendar.date(byAdding: .month, value: amount, to: displayedMonth) ?? displayedMonth
    }

    private func recordColor(for record: FishCareRecord) -> Color {
        record.completedGrowth ? WaterLevelTheme(waterRatio: 1).tintColor : .orange
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
    }
    .environment(AppDataStore())
}
