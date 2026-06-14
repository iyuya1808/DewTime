import SwiftUI
import WidgetKit

struct DewTimeQuickStartWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "DewTimeQuickStartWidget",
            provider: QuickStartTimelineProvider()
        ) { entry in
            QuickStartWidgetView(entry: entry)
        }
        .configurationDisplayName("DewTime クイックタイマー")
        .description("ホーム画面から出発タイマーをすばやく開始します。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct QuickStartEntry: TimelineEntry {
    let date: Date
    let timerState: SharedTimerWidgetState?
}

private struct QuickStartTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickStartEntry {
        QuickStartEntry(date: .now, timerState: previewState)
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickStartEntry) -> Void) {
        completion(QuickStartEntry(date: .now, timerState: SharedTimerWidgetState.load() ?? previewState))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickStartEntry>) -> Void) {
        let now = Date.now
        guard let state = SharedTimerWidgetState.load() else {
            completion(Timeline(entries: [QuickStartEntry(date: now, timerState: nil)], policy: .never))
            return
        }

        let endDate = max(state.targetDepartureTime, now).addingTimeInterval(10 * 60)
        var entries: [QuickStartEntry] = []
        var entryDate = now
        while entryDate <= endDate {
            entries.append(QuickStartEntry(date: entryDate, timerState: state))
            entryDate = entryDate.addingTimeInterval(60)
        }

        completion(Timeline(entries: entries, policy: .after(endDate)))
    }

    private var previewState: SharedTimerWidgetState {
        SharedTimerWidgetState(
            scheduleName: "朝の準備",
            startedAt: .now.addingTimeInterval(-8 * 60),
            targetDepartureTime: .now.addingTimeInterval(22 * 60),
            fishEmoji: "🐟",
            selectedSpeciesName: "メダカ",
            segments: [
                .init(id: "1", name: "身支度", startOffset: 0, endOffset: 10 * 60),
                .init(id: "2", name: "朝ごはん", startOffset: 10 * 60, endOffset: 22 * 60),
                .init(id: "3", name: "出発準備", startOffset: 22 * 60, endOffset: 30 * 60)
            ]
        )
    }
}

private struct QuickStartWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: QuickStartEntry

    private var presets: [(title: String, minutes: Int)] {
        switch family {
        case .systemSmall:
            return [("+15", 15), ("+30", 30)]
        default:
            return [("+15", 15), ("+30", 30), ("+45", 45), ("+60", 60)]
        }
    }

    var body: some View {
        let state = entry.timerState
        let waterLevel = state?.waterLevel(at: entry.date) ?? 0.86
        let isOverdue = state?.isOverdue(at: entry.date) ?? false

        ZStack {
            WidgetAquariumView(
                waterLevel: waterLevel,
                isOverdue: isOverdue,
                fishEmoji: state?.fishEmoji ?? "🐟"
            )

            VStack(alignment: .leading, spacing: 8) {
                header(state: state, isOverdue: isOverdue)

                Spacer()

                if let state {
                    runningFooter(state: state, isOverdue: isOverdue)
                } else {
                    startControls
                }
            }
            .padding(family == .systemSmall ? 14 : 16)
        }
        .widgetURL(URL(string: "dewtime://timer"))
        .containerBackground(for: .widget) {
            Color(red: 0.04, green: 0.18, blue: 0.24)
        }
    }

    private func header(state: SharedTimerWidgetState?, isOverdue: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: isOverdue ? "exclamationmark.triangle.fill" : "drop.fill")
                .font(.headline.weight(.semibold))
                .foregroundStyle(isOverdue ? .orange : Color(red: 0.61, green: 0.92, blue: 1.0))

            VStack(alignment: .leading, spacing: 2) {
                Text(state?.scheduleName ?? "DewTime")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(state.map { $0.currentTaskName(at: entry.date) } ?? "出発タイマー")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 0)
        }
    }

    private func runningFooter(state: SharedTimerWidgetState, isOverdue: Bool) -> some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                Text(isOverdue ? "超過" : "残り")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(isOverdue ? .orange : .white.opacity(0.72))

                Text(timeText(for: state, isOverdue: isOverdue))
                    .font(.title3.monospacedDigit().weight(.bold))
                    .foregroundStyle(.white)
            }

            Spacer(minLength: 8)

            Text(state.selectedSpeciesName)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }

    private var startControls: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: family == .systemSmall ? 1 : 2),
            spacing: 8
        ) {
            ForEach(presets, id: \.minutes) { preset in
                Link(destination: quickStartURL(minutes: preset.minutes)) {
                    HStack(spacing: 5) {
                        Image(systemName: "play.fill")
                            .font(.caption2.weight(.bold))
                        Text(preset.title)
                            .font(.subheadline.monospacedDigit().weight(.bold))
                        Text("分")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: family == .systemSmall ? 34 : 38)
                    .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(.white.opacity(0.26), lineWidth: 1)
                    )
                }
            }
        }
    }

    private func quickStartURL(minutes: Int) -> URL {
        URL(string: "dewtime://start-timer?minutes=\(minutes)")!
    }

    private func timeText(for state: SharedTimerWidgetState, isOverdue: Bool) -> String {
        let seconds = isOverdue
            ? max(0, Int(entry.date.timeIntervalSince(state.targetDepartureTime)))
            : max(0, Int(state.targetDepartureTime.timeIntervalSince(entry.date)))
        let prefix = isOverdue ? "+" : ""
        if seconds >= 3600 {
            return prefix + String(format: "%d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
        }
        return prefix + String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

private struct WidgetAquariumView: View {
    let waterLevel: Double
    let isOverdue: Bool
    let fishEmoji: String

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let clampedLevel = min(1, max(0, waterLevel))
            let waterHeight = size.height * max(0.18, clampedLevel)

            ZStack(alignment: .bottom) {
                LinearGradient(
                    colors: [
                        Color(red: 0.03, green: 0.11, blue: 0.15),
                        Color(red: 0.07, green: 0.24, blue: 0.30),
                        Color(red: 0.12, green: 0.42, blue: 0.50)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                RoundedRectangle(cornerRadius: 0)
                    .fill(
                        LinearGradient(
                            colors: waterColors,
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: waterHeight)
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill(.white.opacity(0.36))
                            .frame(height: 4)
                            .padding(.horizontal, 18)
                            .offset(y: -2)
                    }

                ForEach(0..<5) { index in
                    Circle()
                        .fill(.white.opacity(0.18))
                        .frame(width: CGFloat(4 + index * 2), height: CGFloat(4 + index * 2))
                        .position(
                            x: CGFloat(24 + index * 31).truncatingRemainder(dividingBy: max(80, size.width - 10)),
                            y: size.height - waterHeight + CGFloat(18 + index * 13)
                        )
                }

                Text(fishEmoji)
                    .font(.system(size: min(size.width, size.height) * 0.24))
                    .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                    .position(
                        x: size.width * 0.66,
                        y: size.height - waterHeight * 0.46
                    )

                LinearGradient(
                    colors: [.black.opacity(0.38), .clear, .black.opacity(0.25)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }

    private var waterColors: [Color] {
        if isOverdue {
            return [
                Color(red: 0.94, green: 0.42, blue: 0.26),
                Color(red: 0.72, green: 0.16, blue: 0.12)
            ]
        }

        if waterLevel > 0.55 {
            return [
                Color(red: 0.28, green: 0.81, blue: 0.92),
                Color(red: 0.05, green: 0.47, blue: 0.78)
            ]
        }

        if waterLevel > 0.25 {
            return [
                Color(red: 0.98, green: 0.68, blue: 0.24),
                Color(red: 0.80, green: 0.42, blue: 0.08)
            ]
        }

        return [
            Color(red: 0.98, green: 0.34, blue: 0.68),
            Color(red: 0.56, green: 0.14, blue: 0.42)
        ]
    }
}

#Preview(as: .systemMedium) {
    DewTimeQuickStartWidget()
} timeline: {
    QuickStartEntry(
        date: .now,
        timerState: SharedTimerWidgetState(
            scheduleName: "朝の準備",
            startedAt: .now.addingTimeInterval(-8 * 60),
            targetDepartureTime: .now.addingTimeInterval(22 * 60),
            fishEmoji: "🐟",
            selectedSpeciesName: "メダカ",
            segments: [
                .init(id: "1", name: "身支度", startOffset: 0, endOffset: 10 * 60),
                .init(id: "2", name: "朝ごはん", startOffset: 10 * 60, endOffset: 22 * 60),
                .init(id: "3", name: "出発準備", startOffset: 22 * 60, endOffset: 30 * 60)
            ]
        )
    )
}
