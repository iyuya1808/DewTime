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
        .configurationDisplayName(L10n.Widget.displayName)
        .description(L10n.Widget.description)
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
            scheduleName: "DewTime",
            startedAt: .now.addingTimeInterval(-8 * 60),
            targetDepartureTime: .now.addingTimeInterval(22 * 60),
            fishEmoji: "🐟",
            speciesRawValue: "medaka",
            selectedSpeciesName: L10n.Widget.previewSpeciesName,
            segments: []
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
            return [("+10", 10), ("+15", 15), ("+20", 20), ("+30", 30)]
        }
    }

    var body: some View {
        let state = entry.timerState
        let waterLevel = state?.waterLevel(at: entry.date) ?? 0.86
        let isOverdue = state?.isOverdue(at: entry.date) ?? false

        VStack(alignment: .leading, spacing: 8) {
            header(state: state, isOverdue: isOverdue)

            Spacer(minLength: 8)

            if let state {
                runningFooter(state: state, isOverdue: isOverdue)
            } else {
                startControls
            }
        }
        .widgetURL(URL(string: "dewtime://timer"))
        .containerBackground(for: .widget) {
            WidgetAquariumView(
                waterLevel: waterLevel,
                isOverdue: isOverdue,
                fishEmoji: state?.fishEmoji ?? "🐟",
                speciesRawValue: state?.speciesRawValue,
                phase: wavePhase(at: entry.date)
            )
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

                Text(state.map { subtitle(for: $0, at: entry.date) } ?? L10n.Widget.departureTimer)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 0)
        }
    }

    private func subtitle(for state: SharedTimerWidgetState, at date: Date) -> String {
        if state.segments.isEmpty {
            return state.selectedSpeciesName
        }
        return state.currentTaskName(at: date)
    }

    private func runningFooter(state: SharedTimerWidgetState, isOverdue: Bool) -> some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                Text(isOverdue ? L10n.Live.overdue : L10n.Live.remaining)
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
                        Text(L10n.Timer.minutesUnit)
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

    /// ウィジェットは連続アニメ不可。タイムラインの各エントリ（毎分）で
    /// 位相をずらし、更新ごとに波がゆっくり流れて見えるようにする。
    private func wavePhase(at date: Date) -> CGFloat {
        let period: Double = 600 // 10分で一巡
        let t = date.timeIntervalSince1970.truncatingRemainder(dividingBy: period) / period
        return CGFloat(t) * 2 * .pi
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
    var speciesRawValue: String?
    var phase: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let clampedLevel = min(1, max(0, waterLevel))
            let waterHeight = size.height * max(0.18, clampedLevel)
            // 波の振幅は水面の余裕に合わせて控えめに。
            let amplitude = max(3, min(8, size.height * 0.03))

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

                // 奥の波（薄く、位相をずらして奥行きを出す）
                WaterWaveShape(phase: phase + .pi * 0.6, amplitude: amplitude * 0.7, waterHeight: waterHeight + amplitude)
                    .fill(waterColors.last!.opacity(0.45))
                    .frame(height: waterHeight + amplitude)

                // 手前の波（本体）
                WaterWaveShape(phase: phase, amplitude: amplitude, waterHeight: waterHeight + amplitude)
                    .fill(
                        LinearGradient(
                            colors: waterColors,
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: waterHeight + amplitude)
                    .overlay {
                        WaterWaveShape(phase: phase, amplitude: amplitude, waterHeight: waterHeight + amplitude)
                            .stroke(.white.opacity(0.4), lineWidth: 1.5)
                            .frame(height: waterHeight + amplitude)
                            .blendMode(.softLight)
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

                fishView(maxDimension: min(size.width, size.height))
                    .shadow(color: .black.opacity(0.22), radius: 4, y: 2)
                    .position(
                        x: size.width * 0.64,
                        y: size.height - waterHeight * 0.5
                    )

                LinearGradient(
                    colors: [.black.opacity(0.38), .clear, .black.opacity(0.25)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }

    /// 実写の魚画像（拡張バンドルの `fish_<species>` アセット）。
    /// 画像が無い種類・旧データでは絵文字にフォールバック。
    @ViewBuilder
    private func fishView(maxDimension: CGFloat) -> some View {
        if let raw = speciesRawValue,
           UIImage(named: "fish_\(raw)") != nil {
            Image("fish_\(raw)")
                .resizable()
                .scaledToFit()
                .frame(width: maxDimension * 0.42, height: maxDimension * 0.42)
        } else {
            Text(fishEmoji)
                .font(.system(size: maxDimension * 0.24))
        }
    }

    private var waterColors: [Color] {
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

/// 水面を正弦波で描く。`waterHeight + amplitude` の高さのフレームに
/// 下端詰めで配置し、上端から `amplitude` 下を平均水面とする。
private struct WaterWaveShape: Shape {
    var phase: CGFloat
    var amplitude: CGFloat
    var waterHeight: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let surfaceY = rect.minY + amplitude
        let waves: CGFloat = 1.8

        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        var x = rect.minX
        let step: CGFloat = 3
        while x <= rect.maxX {
            let rel = (x - rect.minX) / max(1, rect.width)
            let y = surfaceY + sin(rel * .pi * 2 * waves + phase) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
            x += step
        }
        let yEnd = surfaceY + sin(.pi * 2 * waves + phase) * amplitude
        path.addLine(to: CGPoint(x: rect.maxX, y: yEnd))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview(as: .systemMedium) {
    DewTimeQuickStartWidget()
} timeline: {
    QuickStartEntry(
        date: .now,
        timerState: SharedTimerWidgetState(
            scheduleName: "DewTime",
            startedAt: .now.addingTimeInterval(-8 * 60),
            targetDepartureTime: .now.addingTimeInterval(22 * 60),
            fishEmoji: "🐟",
            speciesRawValue: "medaka",
            selectedSpeciesName: L10n.Widget.previewSpeciesName,
            segments: []
        )
    )
}
