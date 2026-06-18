import SwiftUI

/// 水槽の成長段階と魚の収容上限を確認できるシート。
struct AquariumUpgradeSheet: View {
    let aquarium: Aquarium
    let swimmingCount: Int
    let overflowFishCount: Int
    let onDismiss: () -> Void

    private let minCapacity = 5
    private let maxCapacity = 100

    private var waitingCount: Int {
        overflowFishCount
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
            sectionDivider(icon: "drop.fill", title: "水槽の成長")

            AquariumGrowthStageView(aquarium: aquarium)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(cardBackground)
        .padding(.horizontal, 20)
    }

    private var occupancyCard: some View {
        VStack(spacing: 10) {
            sectionDivider(icon: "fish.fill", title: "魚の収容")

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

    private func sectionDivider(icon: String, title: String) -> some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(Color.white.opacity(0.22))
                .frame(height: 1)
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption2.weight(.bold))
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.white.opacity(0.7))
            Rectangle()
                .fill(Color.white.opacity(0.22))
                .frame(height: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }

    // MARK: - Fish occupancy visuals

    private func capacityScale(_ capacity: Int) -> CGFloat {
        let span = CGFloat(max(1, maxCapacity - minCapacity))
        let t = CGFloat(capacity - minCapacity) / span
        return 0.28 + t * 0.72
    }

    private func capacityNumberSize(for capacity: Int) -> CGFloat {
        9 + capacityScale(capacity) * 6
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
                Label {
                    Text("\(swimmingCount)")
                        .font(.system(size: capacityNumberSize(for: minCapacity), weight: .bold))
                        .monospacedDigit()
                } icon: {
                    Image(systemName: "fish.fill")
                        .font(.caption.weight(.bold))
                }
                .labelStyle(.titleAndIcon)

                Text("/")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.45))

                Label {
                    Text("\(capacity)")
                        .font(.system(size: capacityNumberSize(for: capacity), weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.85))
                } icon: {
                    Text("上限")
                        .font(.caption2.weight(.semibold))
                }
                .labelStyle(.titleAndIcon)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("\(swimmingCount)匹が泳いでいます。収容上限は\(aquarium.fishCapacity)匹")
        }
    }

    private var waitingIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: "archivebox.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(.orange)
            Text("図鑑に保管")
                .font(.subheadline.weight(.semibold))
            Image(systemName: "fish.fill")
                .font(.caption.weight(.bold))
            Text("\(waitingCount)匹")
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
        .accessibilityLabel("収容上限を超えて\(waitingCount)匹が図鑑に保管されています")
    }
}

#Preview("成長中") {
    AquariumUpgradeSheet(
        aquarium: Aquarium(totalDepartures: 45, bonusFeedStock: 2),
        swimmingCount: 8,
        overflowFishCount: 4,
        onDismiss: {}
    )
}

#Preview("最大段階") {
    AquariumUpgradeSheet(
        aquarium: Aquarium(totalDepartures: 200, bonusFeedStock: 0),
        swimmingCount: 6,
        overflowFishCount: 0,
        onDismiss: {}
    )
}
