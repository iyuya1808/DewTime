import SwiftUI

/// 水槽の成長段階ラダーと次レベルまでの進捗。
struct AquariumGrowthStageView: View {
    let aquarium: Aquarium
    var showsProgress: Bool = true

    private let bowlDiameter: CGFloat = 28
    private let connectorWidth: CGFloat = 10
    private let tierLabelHeight: CGFloat = 18
    private let capacityNumberHeight: CGFloat = 12
    private let rowSpacing: CGFloat = 14
    private let slotsPerRow: CGFloat = 4
    private let firstRowTiers = Array(0...3)
    private let secondRowTiers = Array(4...Aquarium.maxTier)

    private var tierRowHeight: CGFloat {
        bowlDiameter + 8
    }

    private var tierColumnHeight: CGFloat {
        tierRowHeight + 4 + capacityNumberHeight + 2 + tierLabelHeight
    }

    private var ladderHeight: CGFloat {
        tierColumnHeight * 2 + rowSpacing
    }

    var body: some View {
        VStack(spacing: 12) {
            tierLadder

            if showsProgress, !aquarium.isMaxTier {
                tierProgressSection
            }
        }
    }

    private func capacityNumberSize(for capacity: Int) -> CGFloat {
        capacity >= 50 ? 11 : 10
    }

    private var tierLadder: some View {
        GeometryReader { geo in
            let connectorCount = slotsPerRow - 1
            let connectorTotal = connectorWidth * connectorCount
            let slotWidth = (geo.size.width - connectorTotal) / slotsPerRow
            let secondRowWidth = slotWidth * CGFloat(secondRowTiers.count) + connectorWidth * CGFloat(secondRowTiers.count - 1)

            VStack(spacing: rowSpacing) {
                tierRow(tiers: firstRowTiers, slotWidth: slotWidth)

                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    tierRow(tiers: secondRowTiers, slotWidth: slotWidth)
                        .frame(width: secondRowWidth)
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(height: ladderHeight)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("水槽の成長段階")
    }

    private func tierRow(tiers: [Int], slotWidth: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(Array(tiers.enumerated()), id: \.element) { index, tier in
                if index > 0 {
                    tierConnector(reached: tier <= aquarium.sizeTier)
                        .frame(width: connectorWidth)
                }
                tierColumn(tier)
                    .frame(width: slotWidth)
            }
        }
    }

    private func tierConnector(reached: Bool) -> some View {
        Rectangle()
            .fill(reached ? Color.teal.opacity(0.7) : Color.white.opacity(0.18))
            .frame(height: 2)
            .padding(.bottom, bowlDiameter / 2 - 1)
    }

    private func tierColumn(_ tier: Int) -> some View {
        let isCurrent = tier == aquarium.sizeTier
        let isUnlocked = tier <= aquarium.sizeTier
        let capacity = Aquarium.fishCapacity(for: tier)
        let labelColor: Color = isCurrent ? .white : .white.opacity(isUnlocked ? 0.72 : 0.36)

        return VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(
                        isCurrent
                            ? Color.teal.opacity(0.24)
                            : isUnlocked
                                ? Color.white.opacity(0.16)
                                : Color.white.opacity(0.07)
                    )
                    .frame(width: bowlDiameter, height: bowlDiameter)

                Circle()
                    .strokeBorder(
                        isCurrent ? Color.teal : Color.white.opacity(isUnlocked ? 0.4 : 0.2),
                        lineWidth: isCurrent ? 2 : 1
                    )
                    .frame(width: bowlDiameter, height: bowlDiameter)

                tierStatusIcon(isCurrent: isCurrent, isUnlocked: isUnlocked)
            }
            .overlay {
                if isCurrent {
                    Circle()
                        .strokeBorder(Color.teal.opacity(0.55), lineWidth: 1.5)
                        .frame(width: bowlDiameter + 6, height: bowlDiameter + 6)
                }
            }
            .frame(height: tierRowHeight, alignment: .bottom)

            VStack(spacing: 2) {
                Text("\(capacity)")
                    .font(.system(size: capacityNumberSize(for: capacity), weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(labelColor)
                    .lineLimit(1)

                Group {
                    if !isUnlocked {
                        HStack(spacing: 2) {
                            Image(systemName: "drop.fill")
                                .font(.system(size: 7, weight: .bold))
                            Text("\(Aquarium.tierThresholds[tier])しずく")
                                .font(.system(size: 8, weight: .bold))
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .foregroundStyle(.cyan.opacity(0.85))
                    } else if isCurrent && aquarium.isMaxTier {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.yellow)
                    } else {
                        Color.clear
                    }
                }
                .frame(height: tierLabelHeight)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tierAccessibilityLabel(tier, isCurrent: isCurrent, isUnlocked: isUnlocked))
    }

    @ViewBuilder
    private func tierStatusIcon(isCurrent: Bool, isUnlocked: Bool) -> some View {
        if !isUnlocked {
            Image(systemName: "lock.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.6))
        } else if isCurrent && aquarium.isMaxTier {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.yellow)
        } else if isCurrent {
            Image(systemName: "drop.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.teal)
        } else {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.75))
        }
    }

    private var tierProgressSection: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.16))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.cyan, .teal],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, geo.size.width * aquarium.progressToNextTier))
                }
            }
            .frame(height: 8)
            .accessibilityLabel("次の段階まで\(Int((aquarium.progressToNextTier * 100).rounded()))パーセント")

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "drop.fill")
                            .font(.caption.weight(.bold))
                        Text("\(aquarium.totalDepartures)")
                            .font(.subheadline.weight(.bold))
                            .monospacedDigit()
                        Text("しずく")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(.cyan)

                    Image(systemName: "arrow.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.45))

                    HStack(spacing: 4) {
                        Image(systemName: "drop.fill")
                            .font(.caption.weight(.bold))
                        Text("\(Aquarium.tierThresholds[aquarium.sizeTier + 1])")
                            .font(.subheadline.weight(.bold))
                            .monospacedDigit()
                        Text("しずく")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(.white.opacity(0.85))
                }

                if let remaining = aquarium.departuresUntilNextTier, remaining > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.walk.departure")
                            .font(.caption.weight(.bold))
                        Text("あと\(remaining)しずく")
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                    }
                    .foregroundStyle(.white.opacity(0.85))
                    .accessibilityLabel("あと\(remaining)回のオンタイム出発で水槽が大きくなります")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("オンタイム出発\(aquarium.totalDepartures)回。次の段階は\(Aquarium.tierThresholds[aquarium.sizeTier + 1])回")
        }
        .padding(.top, 4)
    }

    private func tierAccessibilityLabel(_ tier: Int, isCurrent: Bool, isUnlocked: Bool) -> String {
        let capacity = Aquarium.fishCapacity(for: tier)
        let name = Aquarium.sizeName(for: tier)
        if isCurrent {
            return "現在の段階\(tier + 1)、\(name)。魚を\(capacity)匹まで泳がせられます"
        }
        if isUnlocked {
            return "達成済みの段階\(tier + 1)、\(name)。魚を\(capacity)匹まで泳がせられます"
        }
        let threshold = Aquarium.tierThresholds[tier]
        return "未解放の段階\(tier + 1)、\(name)。オンタイム出発\(threshold)回で解放。魚を\(capacity)匹まで泳がせられます"
    }
}

#Preview {
    ZStack {
        LinearGradient.dewTimeSheet.ignoresSafeArea()
        AquariumGrowthStageView(aquarium: Aquarium(totalDepartures: 45))
            .padding()
    }
    .preferredColorScheme(.dark)
}
