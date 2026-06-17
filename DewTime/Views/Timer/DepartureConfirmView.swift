import SwiftUI

struct DepartureConfirmView: View {
    let waterLevel: Double
    let isOnTime: Bool
    let selectedSpecies: FishSpecies
    let departuresBefore: Int
    let departuresAfter: Int
    let requiredDepartures: Int
    let growthStage: GrowthStage
    let completesGrowth: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @State private var fishScale: CGFloat = 0.85

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

                        growthTimeline

                        dropGainSection
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
        Image(systemName: isOnTime ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
            .font(.system(size: 52))
            .foregroundStyle(isOnTime ? Color.teal : Color.orange)
            .shadow(color: (isOnTime ? Color.teal : Color.orange).opacity(0.45), radius: 14, y: 4)
            .accessibilityLabel(isOnTime ? "オンタイム" : "遅延あり")
    }

    private var heroSection: some View {
        HStack(alignment: .center, spacing: 20) {
            ZStack {
                if completesGrowth {
                    Circle()
                        .fill(waterLevelColor.opacity(0.22))
                        .frame(width: 118, height: 118)
                        .blur(radius: 16)
                }
                FishArtworkView(species: selectedSpecies)
                    .frame(width: 96, height: 90)
                    .scaleEffect(fishScale)
                    .animation(.spring(response: 0.4, dampingFraction: 0.5), value: fishScale)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { fishScale = 1.0 }
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

    private var growthTimeline: some View {
        HStack(spacing: 0) {
            ForEach(Array(GrowthStage.allCases.enumerated()), id: \.element) { index, stage in
                let progress = requiredDepartures > 0
                    ? Double(departuresAfter) / Double(requiredDepartures)
                    : 0
                let reached = stage.thresholdProgress <= progress

                if index > 0 {
                    Rectangle()
                        .fill(reached ? stageColor.opacity(0.7) : .white.opacity(0.15))
                        .frame(height: 3)
                        .frame(maxWidth: .infinity)
                }

                VStack(spacing: 8) {
                    Image(systemName: stage.icon)
                        .font(.system(size: stage == growthStage ? 28 : 22, weight: .semibold))
                        .foregroundStyle(reached ? stageColor : .white.opacity(0.22))
                        .scaleEffect(stage == growthStage ? 1.15 : 1.0)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(stage == growthStage ? stageColor.opacity(0.18) : .white.opacity(0.06))
                        )
                }
                .accessibilityLabel(stage.displayName)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 16)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var dropGainSection: some View {
        HStack(spacing: 16) {
            dropCluster(count: departuresBefore, highlightUpTo: departuresBefore)
                .accessibilityLabel("現在 \(departuresBefore)しずく")

            Image(systemName: "arrow.right")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white.opacity(0.45))

            dropCluster(count: departuresAfter, highlightUpTo: departuresAfter, emphasizeNewFrom: departuresBefore)
                .accessibilityLabel("あと \(departuresAfter)しずく")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func dropCluster(count: Int, highlightUpTo: Int, emphasizeNewFrom: Int = 0) -> some View {
        HStack(spacing: 5) {
            ForEach(0..<max(1, requiredDepartures), id: \.self) { index in
                let filled = index < highlightUpTo
                let isNew = index >= emphasizeNewFrom && index < highlightUpTo

                Image(systemName: filled ? "drop.fill" : "drop")
                    .font(.system(size: isNew ? 18 : 14, weight: .semibold))
                    .foregroundStyle(
                        filled
                            ? (isNew ? stageColor : stageColor.opacity(0.75))
                            : .white.opacity(0.22)
                    )
                    .scaleEffect(isNew ? 1.2 : 1.0)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.white.opacity(0.40))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("戻る")

            Button(action: onConfirm) {
                Image(systemName: "figure.walk.departure")
                    .font(.system(size: 32, weight: .semibold))
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

    private var stageColor: Color {
        completesGrowth ? theme.tintColor : .orange
    }
}

#Preview {
    Color.black.ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            DepartureConfirmView(
                waterLevel: 0.72,
                isOnTime: true,
                selectedSpecies: .dolphin,
                departuresBefore: 2,
                departuresAfter: 3,
                requiredDepartures: 5,
                growthStage: .juvenile,
                completesGrowth: false,
                onConfirm: {},
                onCancel: {}
            )
            .presentationDetents([.large])
        }
}
