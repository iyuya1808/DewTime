import SwiftUI

struct DepartureConfirmView: View {
    let waterLevel: Double
    let isOnTime: Bool
    let departuresBefore: Int
    let departuresAfter: Int
    let aquariumTierBefore: Int
    let aquariumTierAfter: Int
    let bonusFeedWillAward: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @State private var bowlScale: CGFloat = 0.85

    var body: some View {
        ZStack {
            LinearGradient.dewTimeSheet
                .ignoresSafeArea()

            VStack(spacing: 0) {
                DragHandle()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        statusBadge
                            .padding(.top, 12)

                        heroSection

                        tierTimeline

                        dropGainSection

                        if bonusFeedWillAward {
                            bonusFeedBadge
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }

                actionButtons
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
        }
        .foregroundStyle(.white)
    }

    // MARK: - Sections

    private var statusBadge: some View {
        VStack(spacing: 8) {
            Image(systemName: isOnTime ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 52))
                .foregroundStyle(isOnTime ? Color.teal : Color.orange)
                .shadow(color: (isOnTime ? Color.teal : Color.orange).opacity(0.45), radius: 14, y: 4)
            Text(isOnTime ? "オンタイム" : "遅刻")
                .font(.headline.weight(.bold))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isOnTime ? "オンタイム" : "遅刻")
    }

    private var heroSection: some View {
        HStack(alignment: .center, spacing: 20) {
            ZStack {
                if aquariumTierAfter > aquariumTierBefore {
                    Circle()
                        .fill(waterLevelColor.opacity(0.22))
                        .frame(width: 118, height: 118)
                        .blur(radius: 16)
                }
                aquariumBowlIcon(tier: aquariumTierAfter)
                    .scaleEffect(bowlScale)
                    .animation(.spring(response: 0.4, dampingFraction: 0.5), value: bowlScale)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { bowlScale = 1.0 }
            }

            VStack(spacing: 10) {
                WaterTankView(waterLevel: waterLevel, cornerRadius: 24)
                    .frame(width: 96, height: 148)

                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text("\(Int(waterLevel * 100))")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("%")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.bottom, 4)
                }
                .foregroundStyle(waterLevelColor)
                .accessibilityLabel("残水量 \(Int(waterLevel * 100))パーセント")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var tierTimeline: some View {
        HStack(spacing: 0) {
            ForEach(0...Aquarium.maxTier, id: \.self) { tier in
                let reached = tier <= aquariumTierAfter

                if tier > 0 {
                    Rectangle()
                        .fill(reached ? Color.teal.opacity(0.7) : .white.opacity(0.15))
                        .frame(height: 3)
                        .frame(maxWidth: .infinity)
                }

                VStack(spacing: 8) {
                    Image(systemName: tier == aquariumTierAfter ? "drop.fill" : "circle.fill")
                        .font(.system(size: tier == aquariumTierAfter ? 22 : 14, weight: .semibold))
                        .foregroundStyle(reached ? Color.teal : .white.opacity(0.22))
                        .scaleEffect(tier == aquariumTierAfter ? 1.15 : 1.0)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(tier == aquariumTierAfter ? Color.teal.opacity(0.18) : .white.opacity(0.06))
                        )
                }
                .accessibilityLabel("水槽レベル\(tier + 1)")
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 16)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var dropGainSection: some View {
        HStack(spacing: 16) {
            shizukuCluster(count: departuresBefore, emphasizeNewFrom: 0)
                .accessibilityLabel("現在 \(departuresBefore)しずく")

            Image(systemName: "arrow.right")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white.opacity(0.45))

            shizukuCluster(count: departuresAfter, emphasizeNewFrom: departuresBefore)
                .accessibilityLabel("あと \(departuresAfter)しずく")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var bonusFeedBadge: some View {
        HStack(spacing: 10) {
            Image(systemName: FeedIcon.systemName)
                .font(.title3.weight(.bold))
                .foregroundStyle(.yellow)
                .scaleEffect(0.72)
            Image(systemName: "plus")
                .font(.caption.weight(.bold))
            Text("1")
                .font(.title3.weight(.bold))
                .monospacedDigit()
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.orange.opacity(0.22), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.yellow.opacity(0.4), lineWidth: 1)
        }
        .accessibilityLabel("餌を1個獲得")
    }

    private func shizukuCluster(count: Int, emphasizeNewFrom: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "drop.fill")
                .font(.system(size: count > emphasizeNewFrom ? 22 : 18, weight: .semibold))
                .foregroundStyle(count > emphasizeNewFrom ? waterLevelColor : waterLevelColor.opacity(0.75))
            Text("\(count)")
                .font(.title2.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
    }

    private func aquariumBowlIcon(tier: Int) -> some View {
        let diameter = 14 + CGFloat(tier) * 4
        return ZStack {
            Circle()
                .strokeBorder(.teal.opacity(0.8), lineWidth: 2)
                .frame(width: diameter + 40, height: diameter + 40)
            Image(systemName: tier >= Aquarium.maxTier ? "sparkles" : "drop.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(tier >= Aquarium.maxTier ? .yellow : .cyan)
        }
        .frame(width: 96, height: 96)
    }

    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button(action: onCancel) {
                Label("戻る", systemImage: "xmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(width: 100)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("戻る")

            Button(action: onConfirm) {
                Label("いってきます！", systemImage: "figure.walk.departure")
                    .font(.headline.weight(.semibold))
                    .labelStyle(.titleAndIcon)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(colors: confirmColors, startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: confirmColors.first!.opacity(0.45), radius: 12, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("いってきます")
        }
    }

    // MARK: - Helpers

    private var theme: WaterLevelTheme { WaterLevelTheme(waterRatio: waterLevel) }
    private var waterLevelColor: Color { theme.tintColor }
    private var confirmColors: [Color] { theme.gradientColors }
}

#Preview {
    Color.black.ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            DepartureConfirmView(
                waterLevel: 0.72,
                isOnTime: true,
                departuresBefore: 29,
                departuresAfter: 30,
                aquariumTierBefore: 1,
                aquariumTierAfter: 2,
                bonusFeedWillAward: true,
                onConfirm: {},
                onCancel: {}
            )
            .presentationDetents([.large])
        }
}
