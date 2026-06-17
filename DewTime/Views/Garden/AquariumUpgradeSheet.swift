import SwiftUI

/// 水槽の成長段階と魚の収容上限を、テキストラベルなしで確認できるシート。
struct AquariumUpgradeSheet: View {
    let aquarium: Aquarium
    let swimmingCount: Int
    let totalSwimmableCount: Int
    let onDismiss: () -> Void

    private let minBowlDiameter: CGFloat = 22
    private let maxBowlDiameter: CGFloat = 42
    private let tierColumnWidth: CGFloat = 40
    private let tierLabelHeight: CGFloat = 16
    private let minCapacity = 5
    private let maxCapacity = 100

    private var waitingCount: Int {
        max(0, totalSwimmableCount - aquarium.fishCapacity)
    }

    private var occupancyRatio: Double {
        guard aquarium.fishCapacity > 0 else { return 0 }
        return min(1, Double(swimmingCount) / Double(aquarium.fishCapacity))
    }

    var body: some View {
        ZStack {
            LinearGradient.dewTimeSheet
                .ignoresSafeArea()

            VStack(spacing: 14) {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("閉じる")
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)

                growthCard

                occupancyCard

                if waitingCount > 0 {
                    waitingIndicator
                        .padding(.horizontal, 20)
                }

                Spacer(minLength: 0)
            }
            .padding(.bottom, 20)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Cards

    private var growthCard: some View {
        VStack(spacing: 12) {
            sectionDivider(icon: "drop.fill")

            tierLadder

            if !aquarium.isMaxTier {
                tierProgressSection
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(cardBackground)
        .padding(.horizontal, 20)
    }

    private var occupancyCard: some View {
        VStack(spacing: 10) {
            sectionDivider(icon: "fish.fill")

            fishOccupancySection
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(cardBackground)
        .padding(.horizontal, 20)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.white.opacity(0.08))
    }

    // MARK: - Section chrome

    private func sectionDivider(icon: String) -> some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(Color.white.opacity(0.22))
                .frame(height: 1)
            Image(systemName: icon)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.5))
            Rectangle()
                .fill(Color.white.opacity(0.22))
                .frame(height: 1)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Tier visuals

    private var tierRowHeight: CGFloat {
        maxBowlDiameter + 10
    }

    private func capacityScale(_ capacity: Int) -> CGFloat {
        let span = CGFloat(max(1, maxCapacity - minCapacity))
        let t = CGFloat(capacity - minCapacity) / span
        return 0.28 + t * 0.72
    }

    private func bowlDiameter(for capacity: Int) -> CGFloat {
        minBowlDiameter + (maxBowlDiameter - minBowlDiameter) * capacityScale(capacity)
    }

    private func capacityNumberSize(for capacity: Int) -> CGFloat {
        9 + capacityScale(capacity) * 6
    }

    private func statusIconSize(for capacity: Int) -> CGFloat {
        8 + capacityScale(capacity) * 6
    }

    // MARK: - Tier ladder

    private var tierLadder: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(0...Aquarium.maxTier, id: \.self) { tier in
                        if tier > 0 {
                            tierConnector(
                                from: Aquarium.fishCapacity(for: tier - 1),
                                to: Aquarium.fishCapacity(for: tier),
                                reached: tier <= aquarium.sizeTier
                            )
                        }
                        tierColumn(tier)
                            .id(tier)
                    }
                }
                .padding(.horizontal, 14)
            }
            .contentMargins(.horizontal, 6, for: .scrollContent)
            .scrollClipDisabled()
            .frame(height: tierRowHeight + tierLabelHeight + 20)
            .onAppear {
                proxy.scrollTo(aquarium.sizeTier, anchor: .center)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("水槽の成長段階")
    }

    private func tierConnector(from previousCapacity: Int, to capacity: Int, reached: Bool) -> some View {
        let y = (bowlDiameter(for: previousCapacity) + bowlDiameter(for: capacity)) / 4
        return Rectangle()
            .fill(reached ? Color.teal.opacity(0.7) : Color.white.opacity(0.18))
            .frame(width: 6, height: 2)
            .padding(.bottom, y)
    }

    private func tierColumn(_ tier: Int) -> some View {
        let isCurrent = tier == aquarium.sizeTier
        let isUnlocked = tier <= aquarium.sizeTier
        let capacity = Aquarium.fishCapacity(for: tier)
        let diameter = bowlDiameter(for: capacity)
        let labelColor: Color = isCurrent ? .white : .white.opacity(isUnlocked ? 0.72 : 0.36)

        return VStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(
                        isCurrent
                            ? Color.teal.opacity(0.24)
                            : isUnlocked
                                ? Color.white.opacity(0.16)
                                : Color.white.opacity(0.07)
                    )
                    .frame(width: diameter, height: diameter)

                Circle()
                    .strokeBorder(
                        isCurrent ? Color.teal : Color.white.opacity(isUnlocked ? 0.4 : 0.2),
                        lineWidth: isCurrent ? 2 : 1
                    )
                    .frame(width: diameter, height: diameter)

                tierStatusIcon(
                    capacity: capacity,
                    isCurrent: isCurrent,
                    isUnlocked: isUnlocked
                )
            }
            .overlay {
                if isCurrent {
                    Circle()
                        .strokeBorder(Color.teal.opacity(0.55), lineWidth: 1.5)
                        .frame(width: min(diameter + 6, tierColumnWidth - 4), height: min(diameter + 6, tierColumnWidth - 4))
                }
            }
            .frame(height: tierRowHeight, alignment: .bottom)

            VStack(spacing: 2) {
                Text("\(capacity)")
                    .font(.system(size: capacityNumberSize(for: capacity), weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(labelColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Group {
                    if !isUnlocked {
                        HStack(spacing: 2) {
                            Image(systemName: "drop.fill")
                                .font(.system(size: 7, weight: .bold))
                            Text("\(Aquarium.tierThresholds[tier])")
                                .font(.system(size: 9, weight: .bold))
                                .monospacedDigit()
                        }
                        .foregroundStyle(.cyan.opacity(0.8))
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
        .frame(width: tierColumnWidth)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tierAccessibilityLabel(tier, isCurrent: isCurrent, isUnlocked: isUnlocked))
    }

    @ViewBuilder
    private func tierStatusIcon(capacity: Int, isCurrent: Bool, isUnlocked: Bool) -> some View {
        let size = statusIconSize(for: capacity)
        if !isUnlocked {
            Image(systemName: "lock.fill")
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(.white.opacity(0.6))
        } else if isCurrent && aquarium.isMaxTier {
            Image(systemName: "sparkles")
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(.yellow)
        } else if isCurrent {
            Image(systemName: "drop.fill")
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(.teal)
        } else {
            Image(systemName: "checkmark")
                .font(.system(size: size * 0.9, weight: .bold))
                .foregroundStyle(.white.opacity(0.75))
        }
    }

    // MARK: - Tier progress (not max)

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

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "drop.fill")
                        .font(.caption.weight(.bold))
                    Text("\(aquarium.totalDepartures)")
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
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
                }
                .foregroundStyle(.white.opacity(0.85))

                Spacer(minLength: 0)

                if let remaining = aquarium.departuresUntilNextTier, remaining > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.walk.departure")
                            .font(.caption.weight(.bold))
                        Text("\(remaining)")
                            .font(.subheadline.weight(.bold))
                            .monospacedDigit()
                    }
                    .foregroundStyle(.white.opacity(0.85))
                    .accessibilityLabel("あと\(remaining)回のオンタイム出発で水槽が大きくなります")
                }
            }
            .accessibilityLabel("オンタイム出発\(aquarium.totalDepartures)回。次の段階は\(Aquarium.tierThresholds[aquarium.sizeTier + 1])回")
        }
        .padding(.top, 4)
    }

    // MARK: - Fish occupancy

    private var fishOccupancySection: some View {
        let capacity = aquarium.fishCapacity
        return VStack(spacing: 8) {
            GeometryReader { geo in
                let fillWidth = max(8, geo.size.width * occupancyRatio)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.16))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: occupancyRatio >= 1 ? [.orange, .red] : [.teal, .cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: fillWidth)

                    Circle()
                        .fill(.white)
                        .frame(width: 8, height: 8)
                        .offset(x: max(0, fillWidth - 8))
                }
            }
            .frame(height: 10)
            .accessibilityLabel("水槽の\(Int((occupancyRatio * 100).rounded()))パーセントが埋まっています")

            HStack(spacing: 6) {
                Text("\(swimmingCount)")
                    .font(.system(size: capacityNumberSize(for: minCapacity), weight: .bold))
                    .monospacedDigit()

                Text("/")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.45))

                Text("\(capacity)")
                    .font(.system(size: capacityNumberSize(for: capacity), weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.85))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("\(swimmingCount)匹が泳いでいます。収容上限は\(aquarium.fishCapacity)匹")
        }
    }

    private var waitingIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(.orange)
            Image(systemName: "fish.fill")
                .font(.caption.weight(.bold))
            Text("\(waitingCount)")
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.orange.opacity(0.22), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.35), lineWidth: 1)
        }
        .accessibilityLabel("収容上限を超えて\(waitingCount)匹が待機中です。水槽を大きくすると泳がせられます")
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

#Preview("成長中") {
    AquariumUpgradeSheet(
        aquarium: Aquarium(totalDepartures: 45),
        swimmingCount: 8,
        totalSwimmableCount: 12,
        onDismiss: {}
    )
}

#Preview("最大段階") {
    AquariumUpgradeSheet(
        aquarium: Aquarium(totalDepartures: 200),
        swimmingCount: 6,
        totalSwimmableCount: 6,
        onDismiss: {}
    )
}
