import SwiftUI

/// 水槽の成長段階と魚の収容上限を、テキストラベルなしで確認できるシート。
struct AquariumUpgradeSheet: View {
    let aquarium: Aquarium
    let swimmingCount: Int
    let totalSwimmableCount: Int
    let onDismiss: () -> Void

    private var waitingCount: Int {
        max(0, totalSwimmableCount - aquarium.fishCapacity)
    }

    var body: some View {
        ZStack {
            LinearGradient.dewTimeSheet
                .ignoresSafeArea()

            VStack(spacing: 22) {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("閉じる")
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                tierLadder
                    .padding(.horizontal, 12)

                progressSection
                    .padding(.horizontal, 24)

                if waitingCount > 0 {
                    waitingIndicator
                        .padding(.horizontal, 24)
                }

                Spacer(minLength: 0)
            }
            .padding(.bottom, 24)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Tier ladder

    private var tierLadder: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(0...Aquarium.maxTier, id: \.self) { tier in
                    tierColumn(tier)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("水槽の成長段階")
    }

    private func tierColumn(_ tier: Int) -> some View {
        let isCurrent = tier == aquarium.sizeTier
        let isUnlocked = tier <= aquarium.sizeTier
        let bowlSize = 34 + CGFloat(tier) * 8

        return VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        isCurrent
                            ? Color.teal.opacity(0.28)
                            : isUnlocked
                                ? Color.white.opacity(0.14)
                                : Color.white.opacity(0.06)
                    )
                    .frame(width: bowlSize + 18, height: bowlSize + 18)

                Circle()
                    .strokeBorder(
                        isCurrent ? Color.teal : Color.white.opacity(isUnlocked ? 0.35 : 0.15),
                        lineWidth: isCurrent ? 2.5 : 1
                    )
                    .frame(width: bowlSize, height: bowlSize)

                if !isUnlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.55))
                } else if isCurrent {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.teal)
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            HStack(spacing: 3) {
                Image(systemName: "fish.fill")
                    .font(.caption2.weight(.bold))
                Text("\(Aquarium.fishCapacity(for: tier))")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
            }
            .foregroundStyle(isCurrent ? .white : .white.opacity(0.72))

            Text("\(tier + 1)")
                .font(.caption2.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(isCurrent ? .teal : .white.opacity(0.45))
                .frame(width: 22, height: 22)
                .background(
                    Circle()
                        .fill(isCurrent ? Color.white.opacity(0.18) : Color.white.opacity(0.08))
                )
        }
        .frame(width: max(56, bowlSize + 20))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tierAccessibilityLabel(tier, isCurrent: isCurrent, isUnlocked: isUnlocked))
    }

    // MARK: - Progress

    private var progressSection: some View {
        VStack(spacing: 14) {
            if aquarium.isMaxTier {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundStyle(.yellow)
                    Image(systemName: "fish.fill")
                        .font(.title3)
                        .foregroundStyle(.teal)
                    Text("\(Aquarium.fishCapacity(for: Aquarium.maxTier))")
                        .font(.title.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }
                .accessibilityLabel("最大段階。魚を\(Aquarium.fishCapacity(for: Aquarium.maxTier))匹まで泳がせられます")
            } else {
                VStack(spacing: 10) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.14))
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
                    .frame(height: 12)
                    .accessibilityLabel("次の段階まで\(Int((aquarium.progressToNextTier * 100).rounded()))パーセント")

                    HStack(spacing: 16) {
                        HStack(spacing: 5) {
                            Image(systemName: "drop.fill")
                                .font(.subheadline.weight(.bold))
                            Text("\(aquarium.totalDepartures)")
                                .font(.title3.weight(.bold))
                                .monospacedDigit()
                        }
                        .foregroundStyle(.cyan)

                        Image(systemName: "arrow.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.45))

                        HStack(spacing: 5) {
                            Image(systemName: "drop.fill")
                                .font(.subheadline.weight(.bold))
                            Text("\(Aquarium.tierThresholds[aquarium.sizeTier + 1])")
                                .font(.title3.weight(.bold))
                                .monospacedDigit()
                        }
                        .foregroundStyle(.white.opacity(0.85))
                    }
                    .accessibilityLabel("オンタイム出発\(aquarium.totalDepartures)回。次の段階は\(Aquarium.tierThresholds[aquarium.sizeTier + 1])回")

                    if let remaining = aquarium.departuresUntilNextTier, remaining > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "figure.walk.departure")
                                .font(.subheadline.weight(.bold))
                            Text("\(remaining)")
                                .font(.headline.weight(.bold))
                                .monospacedDigit()
                        }
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.1), in: Capsule())
                        .accessibilityLabel("あと\(remaining)回のオンタイム出発で水槽が大きくなります")
                    }
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "fish.fill")
                    .font(.subheadline.weight(.bold))
                Text("\(swimmingCount)")
                    .font(.headline.weight(.bold))
                    .monospacedDigit()
                Text("/")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white.opacity(0.5))
                Text("\(aquarium.fishCapacity)")
                    .font(.headline.weight(.bold))
                    .monospacedDigit()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.18), in: Capsule())
            .accessibilityLabel("\(swimmingCount)匹が泳いでいます。収容上限は\(aquarium.fishCapacity)匹")
        }
    }

    private var waitingIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.title3)
                .foregroundStyle(.orange)
            Image(systemName: "fish.fill")
                .font(.subheadline.weight(.bold))
            Text("\(waitingCount)")
                .font(.title3.weight(.bold))
                .monospacedDigit()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color.orange.opacity(0.22), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
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
        return "未解放の段階\(tier + 1)、\(name)。魚を\(capacity)匹まで泳がせられます"
    }
}

#Preview {
    AquariumUpgradeSheet(
        aquarium: Aquarium(totalDepartures: 45),
        swimmingCount: 8,
        totalSwimmableCount: 12,
        onDismiss: {}
    )
}
