import ActivityKit
import SwiftUI
import WidgetKit

@main
struct DewTimeLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        DewTimeQuickStartWidget()
        DewTimeLiveActivity()
    }
}

struct DewTimeLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DewTimerActivityAttributes.self) { context in
            LockScreenLiveActivityView(context: context)
                .activityBackgroundTint(Color(red: 0.02, green: 0.09, blue: 0.13))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Color.clear.frame(width: 1, height: 1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Color.clear.frame(width: 1, height: 1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedIslandView(context: context)
                }
            } compactLeading: {
                CompactLeadingView(context: context)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .padding(.leading, 3)
            } compactTrailing: {
                CompactTrailingView(context: context)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .padding(.trailing, 3)
            } minimal: {
                IslandMinimalView(context: context)
            }
        }
    }
}

// MARK: - 出発時刻の切替 + 水位のリアルタイム計算

/// 出発時刻を必ず含め、1秒ごとに水位用の再描画を行う。
private struct LiveActivityTimelineSchedule: TimelineSchedule {
    let startedAt: Date
    let targetDepartureTime: Date
    let staleDate: Date
    let tickInterval: TimeInterval = 1

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> [Date] {
        let anchor = max(startDate, startedAt)
        let end = min(staleDate, anchor.addingTimeInterval(24 * 3600))
        guard anchor < end else { return [anchor] }

        var dates: [Date] = []
        var cursor = anchor
        while cursor <= end {
            dates.append(cursor)
            cursor = cursor.addingTimeInterval(tickInterval)
        }

        if targetDepartureTime > anchor, targetDepartureTime <= end, !dates.contains(targetDepartureTime) {
            dates.append(targetDepartureTime)
            dates.sort()
        }

        return dates.isEmpty ? [anchor] : dates
    }
}

private func liveWaterLevel(
    attributes: DewTimerActivityAttributes,
    state: DewTimerActivityAttributes.ContentState,
    at date: Date
) -> Double {
    switch state.status {
    case .departed, .cancelled:
        return 0
    case .running, .overdue:
        let overdue = date >= attributes.targetDepartureTime || state.status == .overdue
        return overdue ? 0 : attributes.waterLevel(at: date)
    }
}

private struct LiveActivityMoment<Content: View>: View {
    let attributes: DewTimerActivityAttributes
    let state: DewTimerActivityAttributes.ContentState
    @ViewBuilder let content: (_ isPastDeparture: Bool, _ date: Date) -> Content

    var body: some View {
        if state.status.isFinished {
            content(false, state.lastUpdatedAt)
        } else {
            TimelineView(
                LiveActivityTimelineSchedule(
                    startedAt: attributes.startedAt,
                    targetDepartureTime: attributes.targetDepartureTime,
                    staleDate: attributes.activityStaleDate
                )
            ) { timeline in
                content(
                    timeline.date >= attributes.targetDepartureTime,
                    timeline.date
                )
            }
        }
    }
}

private func isVisuallyOverdue(
    state: DewTimerActivityAttributes.ContentState,
    isPastDeparture: Bool
) -> Bool {
    isPastDeparture || state.status == .overdue
}

// MARK: - Shared

private struct AdaptiveTimerText: View {
    let attributes: DewTimerActivityAttributes
    let isPastDeparture: Bool
    var font: Font = .caption2.monospacedDigit().weight(.semibold)
    var runningTint: Color = .cyan
    var alignment: TextAlignment = .trailing

    var body: some View {
        if isPastDeparture {
            OverdueText(attributes: attributes, font: font, alignment: alignment)
        } else {
            CountdownText(
                attributes: attributes,
                font: font,
                color: runningTint,
                alignment: alignment
            )
        }
    }
}

private struct CountdownText: View {
    let attributes: DewTimerActivityAttributes
    var font: Font = .caption2.monospacedDigit().weight(.semibold)
    var color: Color = .cyan
    var alignment: TextAlignment = .trailing

    var body: some View {
        Text(attributes.timerPlaceholder(isOverdue: false))
            .font(font)
            .hidden()
            .overlay {
                Text(
                    timerInterval: attributes.timerInterval,
                    countsDown: true,
                    showsHours: attributes.showsHourTimer
                )
                .font(font)
                .monospacedDigit()
                .multilineTextAlignment(alignment)
                .foregroundStyle(color)
            }
            .fixedSize()
    }
}

private struct OverdueText: View {
    let attributes: DewTimerActivityAttributes
    var font: Font = .caption2.monospacedDigit().weight(.semibold)
    var alignment: TextAlignment = .trailing

    var body: some View {
        Text(attributes.timerPlaceholder(isOverdue: true))
            .font(font)
            .hidden()
            .overlay {
                HStack(spacing: 0) {
                    Text("+")
                    Text(
                        timerInterval: attributes.targetDepartureTime...attributes.activityStaleDate,
                        countsDown: false
                    )
                    .monospacedDigit()
                }
                .font(font)
                .multilineTextAlignment(alignment)
                .foregroundStyle(.orange)
            }
            .fixedSize()
    }
}

private struct WaterBar: View {
    var level: Double
    var isOverdue: Bool = false
    var width: CGFloat? = nil
    var height: CGFloat = 5

    var body: some View {
        let clamped = max(0, min(1, level))
        let fill = isOverdue || clamped <= 0.2 ? Color.orange : Color.cyan
        let track = isOverdue ? Color.orange.opacity(0.3) : Color(white: 0.38)

        Group {
            if let width {
                barTrack(fill: fill, track: track, clamped: clamped, barWidth: width)
                    .frame(width: width, height: height)
            } else {
                GeometryReader { geo in
                    barTrack(fill: fill, track: track, clamped: clamped, barWidth: geo.size.width)
                }
                .frame(height: height)
            }
        }
    }

    private func barTrack(fill: Color, track: Color, clamped: Double, barWidth: CGFloat) -> some View {
        Capsule()
            .fill(track)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(fill)
                    .frame(width: max(height, barWidth * clamped), height: height)
                    .animation(.linear(duration: 1), value: clamped)
            }
    }
}

private enum CompactIslandMetrics {
    static let rowHeight: CGFloat = 11
    static let iconFont: Font = .system(size: 9, weight: .semibold)
    static let barWidth: CGFloat = 18
    static let barHeight: CGFloat = 3
}

private struct TankPreviewView: View {
    var waterLevel: Double
    var isOverdue: Bool = false
    var cornerRadius: CGFloat = 12

    private let innerInset: CGFloat = 3

    var body: some View {
        GeometryReader { geo in
            let clamped = max(0, min(1, waterLevel))
            let innerHeight = max(0, geo.size.height - innerInset * 2)
            let waterHeight = innerHeight * clamped
            let innerRadius = max(3, cornerRadius - innerInset)
            let waterColors = isOverdue || clamped <= 0.2
                ? [Color.orange.opacity(0.92), Color.orange.opacity(0.72)]
                : [Color.cyan.opacity(0.92), Color(red: 0.03, green: 0.47, blue: 0.76).opacity(0.95)]

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(red: 0.05, green: 0.12, blue: 0.16))

                if waterHeight > 0 {
                    RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: waterColors,
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: waterHeight)
                        .padding(.horizontal, innerInset)
                        .padding(.bottom, innerInset)
                        .animation(.linear(duration: 1), value: waterHeight)
                }

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.22), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}

private struct StatusLabel: View {
    let isOverdue: Bool

    var body: some View {
        HStack(spacing: 4) {
            if isOverdue {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9, weight: .bold))
            }
            Text(isOverdue ? L10n.Live.overdue : L10n.Live.remaining)
                .font(.caption2.weight(.bold))
        }
        .foregroundStyle(isOverdue ? .orange : .white.opacity(0.58))
    }
}

// MARK: - Lock screen

private struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<DewTimerActivityAttributes>

    var body: some View {
        LiveActivityMoment(attributes: context.attributes, state: context.state) { isPast, date in
            let status = context.state.status
            let overdue = isVisuallyOverdue(state: context.state, isPastDeparture: isPast)
            let level = liveWaterLevel(attributes: context.attributes, state: context.state, at: date)

            HStack(alignment: .top, spacing: 12) {
                TankPreviewView(
                    waterLevel: level,
                    isOverdue: overdue,
                    cornerRadius: 12
                )
                .frame(width: 80)
                .frame(maxHeight: .infinity, alignment: .top)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            if status == .departed {
                                Text(L10n.Live.toAquarium)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.mint)
                                Text(L10n.Live.pourComplete)
                                    .font(.title2.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            } else {
                                StatusLabel(isOverdue: overdue)
                                AdaptiveTimerText(
                                    attributes: context.attributes,
                                    isPastDeparture: isPast,
                                    font: .system(size: 30, weight: .semibold, design: .rounded).monospacedDigit(),
                                    runningTint: .white,
                                    alignment: .leading
                                )
                            }
                        }

                        Spacer(minLength: 4)

                        if status != .departed {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(L10n.Live.departure)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.white.opacity(overdue ? 0.35 : 0.55))
                                Text(context.attributes.targetDepartureTime, format: .dateTime.hour().minute())
                                    .font(.caption.monospacedDigit().weight(.semibold))
                                    .foregroundStyle(.white.opacity(overdue ? 0.4 : 0.92))
                            }
                        }
                    }

                    if status == .running || status == .overdue || isPast {
                        WaterBar(
                            level: level,
                            isOverdue: overdue,
                            height: 6
                        )
                    }

                    HStack(spacing: 6) {
                        Image(systemName: footerIcon(status: status, overdue: overdue))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(footerColor(status: status, overdue: overdue))
                        Text(footerLabel(status: status))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.82))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
        }
    }

    private func footerLabel(status: DewTimerActivityAttributes.TimerStatus) -> String {
        switch status {
        case .departed: return L10n.Live.pourToAquarium
        case .cancelled: return L10n.Timer.statusCancelled
        case .running, .overdue: return L10n.AquariumSize.name(tier: context.state.aquariumTier)
        }
    }

    private func footerIcon(status: DewTimerActivityAttributes.TimerStatus, overdue: Bool) -> String {
        switch status {
        case .departed: return "drop.fill"
        case .cancelled: return "figure.walk.motion"
        case .running, .overdue: return overdue ? "exclamationmark.triangle.fill" : "figure.walk.motion"
        }
    }

    private func footerColor(status: DewTimerActivityAttributes.TimerStatus, overdue: Bool) -> Color {
        switch status {
        case .departed: return .mint
        case .cancelled: return .cyan
        case .running, .overdue: return overdue ? .orange : .cyan
        }
    }
}

// MARK: - Dynamic Island

private struct CompactLeadingView: View {
    let context: ActivityViewContext<DewTimerActivityAttributes>

    var body: some View {
        LiveActivityMoment(attributes: context.attributes, state: context.state) { isPast, date in
            let status = context.state.status
            let overdue = isVisuallyOverdue(state: context.state, isPastDeparture: isPast)
            let level = liveWaterLevel(attributes: context.attributes, state: context.state, at: date)

            Group {
                switch status {
                case .departed:
                    Image(systemName: "drop.fill")
                        .font(CompactIslandMetrics.iconFont)
                        .foregroundStyle(.mint)
                case .cancelled:
                    Image(systemName: "drop.fill")
                        .font(CompactIslandMetrics.iconFont)
                        .foregroundStyle(.white.opacity(0.5))
                case .running, .overdue:
                    HStack(alignment: .center, spacing: 3) {
                        Image(systemName: overdue ? "exclamationmark.triangle.fill" : "drop.fill")
                            .font(CompactIslandMetrics.iconFont)
                        WaterBar(
                            level: level,
                            isOverdue: overdue,
                            width: CompactIslandMetrics.barWidth,
                            height: CompactIslandMetrics.barHeight
                        )
                    }
                    .foregroundStyle(overdue ? .orange : .cyan)
                }
            }
            .frame(height: CompactIslandMetrics.rowHeight)
            .fixedSize(horizontal: true, vertical: true)
        }
    }
}

private struct CompactTrailingView: View {
    let context: ActivityViewContext<DewTimerActivityAttributes>

    var body: some View {
        LiveActivityMoment(attributes: context.attributes, state: context.state) { isPast, _ in
            let status = context.state.status

            Group {
                switch status {
                case .departed: Text("✨")
                case .cancelled: Text("💧")
                case .running, .overdue:
                    AdaptiveTimerText(
                        attributes: context.attributes,
                        isPastDeparture: isPast,
                        runningTint: isPast ? .orange : .cyan
                    )
                }
            }
            .font(.caption2.monospacedDigit().weight(.semibold))
            .frame(height: CompactIslandMetrics.rowHeight)
            .fixedSize(horizontal: true, vertical: true)
        }
    }
}

private struct IslandMinimalView: View {
    let context: ActivityViewContext<DewTimerActivityAttributes>

    var body: some View {
        LiveActivityMoment(attributes: context.attributes, state: context.state) { isPast, _ in
            let overdue = isVisuallyOverdue(state: context.state, isPastDeparture: isPast)

            Image(systemName: overdue ? "exclamationmark.triangle.fill" : "drop.fill")
                .foregroundStyle(overdue ? .orange : .cyan)
        }
    }
}

private enum IslandExpandedMetrics {
    static let tankWidth: CGFloat = 68
    static let leadingInset: CGFloat = 12
    static let horizontalInset: CGFloat = 14
    static let topRowHeight: CGFloat = 34
    static let expandedHeight: CGFloat = 88
}

/// 展開 DI は bottom 1 枚にまとめる（leading/bottom 分割だと切れ目が出る）
private struct ExpandedIslandView: View {
    let context: ActivityViewContext<DewTimerActivityAttributes>

    var body: some View {
        LiveActivityMoment(attributes: context.attributes, state: context.state) { isPast, date in
            let status = context.state.status
            let overdue = isVisuallyOverdue(state: context.state, isPastDeparture: isPast)
            let level = liveWaterLevel(attributes: context.attributes, state: context.state, at: date)
            let tankGutter = IslandExpandedMetrics.tankWidth + IslandExpandedMetrics.leadingInset

            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    TankPreviewView(
                        waterLevel: level,
                        isOverdue: overdue,
                        cornerRadius: 12
                    )
                    .frame(width: IslandExpandedMetrics.tankWidth, height: geo.size.height)
                    .padding(.leading, IslandExpandedMetrics.leadingInset)

                    VStack(spacing: 0) {
                        HStack {
                            Spacer(minLength: tankGutter)
                            expandedDepartureBlock(status: status, overdue: overdue)
                        }
                        .frame(height: IslandExpandedMetrics.topRowHeight, alignment: .top)

                        HStack(alignment: .top, spacing: 10) {
                            Color.clear.frame(width: tankGutter)
                            VStack(alignment: .leading, spacing: 8) {
                                expandedTimerRow(status: status, isPast: isPast, overdue: overdue)
                                if status == .running || status == .overdue || isPast {
                                    WaterBar(level: level, isOverdue: overdue, height: 5)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: .infinity, alignment: .topLeading)
                    }
                    .padding(.trailing, IslandExpandedMetrics.horizontalInset)
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            }
            .frame(height: IslandExpandedMetrics.expandedHeight)
        }
    }

    @ViewBuilder
    private func expandedDepartureBlock(
        status: DewTimerActivityAttributes.TimerStatus,
        overdue: Bool
    ) -> some View {
        if status == .departed {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.mint)
        } else {
            VStack(alignment: .trailing, spacing: 2) {
                Text(L10n.Live.departure)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(overdue ? 0.35 : 0.55))
                HStack(spacing: 3) {
                    Text(context.attributes.targetDepartureTime, format: .dateTime.hour().minute())
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.white.opacity(overdue ? 0.35 : 0.95))
                    if overdue {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func expandedTimerRow(
        status: DewTimerActivityAttributes.TimerStatus,
        isPast: Bool,
        overdue: Bool
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: expandedRowIcon(status: status, overdue: overdue))
                .font(.caption.weight(.bold))
                .foregroundStyle(expandedRowColor(status: status, overdue: overdue))
                .frame(width: 14)

            switch status {
            case .departed:
                Text(L10n.Live.pourComplete)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.mint)
                    .lineLimit(1)
            case .cancelled:
                Text(L10n.Timer.statusCancelled)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            case .running, .overdue:
                HStack(spacing: 4) {
                    Text(overdue ? L10n.Live.overdue : L10n.Live.remaining)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(overdue ? .orange : .white.opacity(0.58))
                    AdaptiveTimerText(
                        attributes: context.attributes,
                        isPastDeparture: isPast,
                        font: .title3.monospacedDigit().weight(.semibold),
                        runningTint: overdue ? .orange : .white,
                        alignment: .leading
                    )
                }
            }

            Spacer(minLength: 0)
        }
    }

    private func expandedRowIcon(
        status: DewTimerActivityAttributes.TimerStatus,
        overdue: Bool
    ) -> String {
        switch status {
        case .departed: return "drop.fill"
        case .cancelled: return "figure.walk.motion"
        case .running, .overdue: return overdue ? "exclamationmark.triangle.fill" : "figure.walk.motion"
        }
    }

    private func expandedRowColor(
        status: DewTimerActivityAttributes.TimerStatus,
        overdue: Bool
    ) -> Color {
        switch status {
        case .departed: return .mint
        case .cancelled: return .cyan
        case .running, .overdue: return overdue ? .orange : .cyan
        }
    }
}
