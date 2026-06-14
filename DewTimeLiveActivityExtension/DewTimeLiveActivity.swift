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
                .activityBackgroundTint(Color(red: 0.03, green: 0.10, blue: 0.14))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedTankView(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedFishView(state: context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedTaskView(context: context)
                }
            } compactLeading: {
                HStack(spacing: 3) {
                    Image(systemName: "drop.fill")
                    Text("\(context.state.waterPercent)%")
                        .monospacedDigit()
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.cyan)
            } compactTrailing: {
                Text(compactStatusText(context.state))
                    .font(.caption2.weight(.semibold))
            } minimal: {
                HStack(spacing: 1) {
                    Image(systemName: "drop.fill")
                    Text("\(context.state.waterPercent)%")
                        .monospacedDigit()
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(context.state.waterLevel <= 0.2 ? .orange : .cyan)
            }
        }
    }
}

private struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<DewTimerActivityAttributes>

    private var isDeparted: Bool { context.state.status == .departed }

    var body: some View {
        HStack(spacing: 14) {
            TankPreviewView(
                waterLevel: isDeparted ? 0 : context.state.waterLevel,
                segments: context.attributes.segments,
                fishEmoji: context.state.fishEmoji
            )
            .frame(width: 82, height: 92)

            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(context.attributes.scheduleName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.68))
                            .lineLimit(1)
                        Text(context.state.currentTaskName)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        if isDeparted {
                            Text("水槽へ")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.mint)
                            Text("注水完了")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white)
                                .minimumScaleFactor(0.72)
                        } else {
                            Text(context.state.status == .overdue ? "超過" : "残り")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(context.state.status == .overdue ? .orange : .white.opacity(0.58))
                            Text(timerInterval: Date.now...context.attributes.targetDepartureTime, countsDown: true)
                                .font(.title3.monospacedDigit().weight(.semibold))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.trailing)
                                .minimumScaleFactor(0.72)
                        }
                    }
                }

                WaterMeterView(
                    waterLevel: isDeparted ? 0 : context.state.waterLevel,
                    projectedWater: context.state.projectedWater,
                    requiredWater: context.state.requiredWater
                )

                HStack(spacing: 10) {
                    FishPreviewBadge(state: context.state)
                        .scaleEffect(isDeparted ? 1.18 : 1.0)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(context.state.selectedSpeciesName) / \(context.state.growthStageName)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                        Text("\(Int(context.state.projectedWater.rounded())) / \(Int(context.state.requiredWater.rounded())) pt")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.64))
                    }

                    Spacer()
                }
            }
        }
        .padding(16)
        .foregroundStyle(.white)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: context.state.status)
        .animation(.spring(response: 0.35, dampingFraction: 0.55), value: context.state.phaseIndex)
    }
}

private struct ExpandedTankView: View {
    let context: ActivityViewContext<DewTimerActivityAttributes>

    private var isDeparted: Bool { context.state.status == .departed }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TankPreviewView(
                waterLevel: isDeparted ? 0 : context.state.waterLevel,
                segments: context.attributes.segments,
                fishEmoji: context.state.fishEmoji
            )
            .frame(width: 66, height: 72)
            Text(isDeparted ? "注水完了" : "\(context.state.waterPercent)%")
                .font(.caption2.monospacedDigit().weight(.semibold))
                .foregroundStyle(isDeparted ? .mint : .cyan)
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: context.state.status)
    }
}

private struct ExpandedFishView: View {
    let state: DewTimerActivityAttributes.ContentState

    private var isDeparted: Bool { state.status == .departed }

    var body: some View {
        VStack(alignment: .trailing, spacing: 5) {
            Text(state.fishEmoji)
                .font(.title)
                .scaleEffect(isDeparted ? 1.3 : 1.0)
            Text(state.growthStageName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.82))
            ProgressView(value: state.growthProgress)
                .tint(.mint)
                .frame(width: 78)
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: state.status)
    }
}

private struct ExpandedTaskView: View {
    let context: ActivityViewContext<DewTimerActivityAttributes>

    private var isDeparted: Bool { context.state.status == .departed }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(context.state.currentTaskName, systemImage: isDeparted ? "drop.fill" : "figure.walk.motion")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer()
                if isDeparted {
                    Text("水槽へ注水 ✨")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.mint)
                } else {
                    Text(timerInterval: Date.now...context.attributes.targetDepartureTime, countsDown: true)
                        .font(.caption.monospacedDigit().weight(.bold))
                        .foregroundStyle(.white.opacity(0.88))
                }
            }

            WaterMeterView(
                waterLevel: isDeparted ? 0 : context.state.waterLevel,
                projectedWater: context.state.projectedWater,
                requiredWater: context.state.requiredWater,
                isCompact: true
            )

            if !isDeparted, let nextTaskName = context.state.nextTaskName {
                Text("次: \(nextTaskName)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: context.state.status)
        .animation(.spring(response: 0.35, dampingFraction: 0.55), value: context.state.phaseIndex)
    }
}

private struct TankPreviewView: View {
    var waterLevel: Double
    var segments: [DewTimerActivityAttributes.RoutineSegment]
    var fishEmoji: String

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let clampedLevel = max(0, min(1, waterLevel))
            let waterHeight = max(8, size.height * clampedLevel)

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.02, green: 0.08, blue: 0.13),
                                Color(red: 0.08, green: 0.18, blue: 0.23)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.16, green: 0.78, blue: 0.92).opacity(0.86),
                                Color(red: 0.03, green: 0.47, blue: 0.76).opacity(0.94)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: waterHeight)

                Capsule()
                    .fill(.white.opacity(0.26))
                    .frame(height: 3)
                    .padding(.horizontal, 8)
                    .offset(y: -waterHeight + 1.5)

                TaskStripeView(segments: segments)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 7)

                Text(fishEmoji)
                    .font(.system(size: min(size.width, size.height) * 0.26))
                    .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
                    .offset(y: -max(12, waterHeight * 0.46))

                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.white.opacity(0.20), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

private struct WaterMeterView: View {
    var waterLevel: Double
    var projectedWater: Double
    var requiredWater: Double
    var isCompact: Bool = false

    var body: some View {
        let clampedLevel = max(0, min(1, waterLevel))

        VStack(alignment: .leading, spacing: isCompact ? 4 : 5) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("水量")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.58))
                Spacer(minLength: 8)
                Text("\(Int(projectedWater.rounded()))/\(Int(requiredWater.rounded()))")
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white.opacity(0.74))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.12))
                    Capsule()
                        .fill(clampedLevel <= 0.2 ? .orange : .cyan)
                        .frame(width: max(8, proxy.size.width * clampedLevel))
                }
            }
            .frame(height: isCompact ? 5 : 7)
        }
    }
}

private struct TaskStripeView: View {
    var segments: [DewTimerActivityAttributes.RoutineSegment]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(segments.prefix(5)) { segment in
                Capsule()
                    .fill(Color(hex: segment.colorHex).opacity(0.9))
            }
        }
        .frame(height: 5)
    }
}

private struct FishPreviewBadge: View {
    let state: DewTimerActivityAttributes.ContentState

    var body: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.12))
            Text(state.fishEmoji)
                .font(.title2)
        }
        .frame(width: 46, height: 46)
    }
}

private func shortTaskName(_ name: String) -> String {
    guard name.count > 3 else { return name }
    return String(name.prefix(3))
}

private func compactStatusText(_ state: DewTimerActivityAttributes.ContentState) -> String {
    switch state.status {
    case .overdue:
        return "⚠️"
    case .departed:
        return "✨"
    case .cancelled:
        return "💧"
    case .running:
        // 現時点の予測で成魚に届くなら ✨、それ以外は順調を表す 🐟。
        return state.growthProgress >= 1.0 ? "✨" : "🐟"
    }
}

private extension Color {
    init(hex: String) {
        let normalized = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let value = UInt64(normalized, radix: 16) ?? 0x38BDF8
        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}
