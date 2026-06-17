import SwiftUI

struct FishCareDetailSheet: View {
    let record: FishCareRecord
    @Environment(\.colorScheme) private var colorScheme

    private var requiredDepartures: Int { record.species.requiredDepartures }

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
                    .accessibilityHidden(true)

                    growthTimeline

                    Text(record.recordedAt, format: .dateTime.year().month().day().hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()

                    HStack(spacing: 10) {
                        metric(
                            icon: "drop.fill",
                            value: record.earnedDrop ? "+1" : "0",
                            caption: "しずく",
                            tint: .cyan,
                            accessibilityLabel: record.earnedDrop ? "今回 しずく1" : "今回 しずく0"
                        )
                        metric(
                            icon: "drop.fill",
                            value: "\(record.departuresAfter)/\(requiredDepartures)",
                            caption: "ごうけい",
                            tint: recordColor,
                            accessibilityLabel: "合計 \(record.departuresAfter)しずく、必要 \(requiredDepartures)しずく"
                        )
                    }
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(detailAccessibilityLabel)
    }

    private var growthTimeline: some View {
        HStack(spacing: 0) {
            ForEach(Array(GrowthStage.allCases.enumerated()), id: \.element) { index, stage in
                let progress = requiredDepartures > 0
                    ? Double(record.departuresAfter) / Double(requiredDepartures)
                    : 0
                let reached = stage.thresholdProgress <= progress

                if index > 0 {
                    Rectangle()
                        .fill(reached ? recordColor.opacity(0.7) : Color.secondary.opacity(0.2))
                        .frame(height: 3)
                        .frame(maxWidth: .infinity)
                }

                VStack(spacing: 2) {
                    Image(systemName: stage.icon)
                        .font(.system(size: stage == record.growthStage ? 24 : 20, weight: .semibold))
                        .foregroundStyle(reached ? recordColor : Color.secondary.opacity(0.35))
                        .scaleEffect(stage == record.growthStage ? 1.12 : 1.0)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(stage == record.growthStage ? recordColor.opacity(0.16) : Color.secondary.opacity(0.08))
                        )

                    if stage == record.growthStage {
                        Text(stage.displayNameHiragana)
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityLabel(stage.displayName)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .background(Color.dewSurface.opacity(0.65), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func metric(icon: String, value: String, caption: String, tint: Color, accessibilityLabel: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
            Text(value)
                .font(.headline)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(caption)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.dewSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var detailAccessibilityLabel: String {
        let dateText = record.recordedAt.formatted(.dateTime.year().month().day().hour().minute())
        let stageText = record.completedGrowth ? "\(record.species.displayName)が成魚" : record.growthStage.displayName
        let dropText = record.earnedDrop ? "しずく1獲得" : "しずくなし"
        return "\(dateText)、\(stageText)、\(dropText)、\(record.departuresAfter)/\(requiredDepartures)しずく"
    }

    private var recordColor: Color {
        record.completedGrowth ? WaterLevelTheme(waterRatio: 1).tintColor : .orange
    }
}
