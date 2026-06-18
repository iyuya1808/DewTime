import SwiftUI

struct FishCareDetailSheet: View {
    let record: FishCareRecord
    @Environment(\.colorScheme) private var colorScheme

    private var aquarium: Aquarium {
        Aquarium(totalDepartures: record.departuresAfter)
    }

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
                        Image(systemName: record.earnedDrop ? "drop.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 52, weight: .semibold))
                            .foregroundStyle(recordColor)
                    }

                    Text(record.earnedDrop ? L10n.Aquarium.Care.onTime : L10n.Aquarium.Care.late)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(recordColor)

                    HStack(spacing: 12) {
                        Image(systemName: aquarium.isMaxTier ? "sparkles" : "drop.fill")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(aquarium.isMaxTier ? .yellow : .cyan)
                        Text("Lv.\(aquarium.sizeTier + 1)")
                            .font(.title2.weight(.bold))
                            .monospacedDigit()
                    }

                    Text(record.recordedAt, format: .dateTime.year().month().day().hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()

                    HStack(spacing: 10) {
                        metric(
                            icon: record.earnedDrop ? "drop.fill" : "drop",
                            value: record.earnedDrop ? "+1" : "0",
                            caption: L10n.Aquarium.dewDrop,
                            tint: .cyan,
                            accessibilityLabel: record.earnedDrop ? L10n.Aquarium.Care.dewEarnedA11y : L10n.Aquarium.Care.dewNoneA11y
                        )
                        if record.bonusFeedAwarded {
                            metric(
                                icon: FeedIcon.systemName,
                                value: "+1",
                                caption: L10n.Aquarium.feed,
                                tint: .orange,
                                accessibilityLabel: L10n.Aquarium.Care.feedEarnedA11y
                            )
                        }
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
        let dropText = record.earnedDrop ? L10n.Aquarium.Care.dewSummaryEarned : L10n.Aquarium.Care.dewSummaryNone
        let bonusText = record.bonusFeedAwarded ? L10n.Aquarium.Care.feedSummary : ""
        return L10n.Aquarium.Care.detailA11y(date: dateText, dropText: dropText, bonusText: bonusText)
    }

    private var recordColor: Color {
        record.earnedDrop ? WaterLevelTheme(waterRatio: 1).tintColor : .orange
    }
}
