import SwiftUI

struct DepartureConfirmView: View {
    let waterLevel: Double
    let isOnTime: Bool
    let selectedSpecies: FishSpecies
    let waterAmount: Double
    let totalWaterBefore: Double
    let totalWaterAfter: Double
    let requiredTotalWater: Double
    let growthStage: GrowthStage
    let completesGrowth: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @State private var fishScale: CGFloat = 0.8

    var body: some View {
        ZStack {
            LinearGradient.dewTimeSheet
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // 魚アートワーク（成魚達成時は輝きエフェクト）
                    ZStack {
                        if completesGrowth {
                            Circle()
                                .fill(waterLevelColor.opacity(0.20))
                                .frame(width: 140, height: 140)
                                .blur(radius: 18)
                        }
                        FishArtworkView(species: selectedSpecies)
                            .frame(width: 100, height: 94)
                            .scaleEffect(fishScale)
                            .animation(.spring(response: 0.4, dampingFraction: 0.5), value: fishScale)
                    }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { fishScale = 1.0 }
                    }
                    .padding(.top, 24)

                    // 成長段階アイコン群
                    HStack(spacing: 16) {
                        ForEach(GrowthStage.allCases, id: \.self) { stage in
                            let reached = stage.thresholdProgress <= (totalWaterAfter / max(1, requiredTotalWater))
                            Image(systemName: stage.icon)
                                .font(.title3)
                                .foregroundStyle(reached ? stageColor : .white.opacity(0.22))
                                .scaleEffect(stage == growthStage ? 1.25 : 1.0)
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 28)

                    // インジケーターバッジ（アイコン + ビジュアル充填のみ）
                    HStack(spacing: 12) {
                        indicatorView(
                            icon: "drop.fill",
                            ratio: waterLevel,
                            color: waterLevelColor,
                            accessibilityText: "残水量 \(Int(waterLevel * 100))%"
                        )
                        indicatorView(
                            icon: isOnTime ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
                            ratio: isOnTime ? 1.0 : 0.3,
                            color: isOnTime ? .teal : .orange,
                            accessibilityText: isOnTime ? "オンタイム" : "遅延あり"
                        )
                        indicatorView(
                            icon: selectedSpecies.icon,
                            ratio: min(1.0, totalWaterAfter / max(1, requiredTotalWater)),
                            color: stageColor,
                            accessibilityText: "育成水量 \(Int(totalWaterAfter.rounded()))pt"
                        )
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)

                    // ボタン（アイコンのみ）
                    VStack(spacing: 14) {
                        Button(action: onConfirm) {
                            Image(systemName: "figure.walk.departure")
                                .font(.system(size: 38, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                                .background(
                                    LinearGradient(colors: confirmColors, startPoint: .leading, endPoint: .trailing)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .shadow(color: confirmColors.first!.opacity(0.4), radius: 10, y: 4)
                        }
                        .accessibilityLabel("いってきます")

                        Button(action: onCancel) {
                            Image(systemName: "arrow.uturn.backward.circle")
                                .font(.system(size: 28))
                                .foregroundStyle(.white.opacity(0.45))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .accessibilityLabel("戻る")
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .foregroundStyle(.white)
    }

    private func indicatorView(icon: String, ratio: Double, color: Color, accessibilityText: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title2)

            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.white.opacity(0.12))
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color.opacity(0.75))
                        .frame(height: geo.size.height * max(0.05, min(1.0, ratio)))
                }
            }
            .frame(height: 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityLabel(accessibilityText)
    }

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
                waterAmount: 72,
                totalWaterBefore: 120,
                totalWaterAfter: 192,
                requiredTotalWater: 320,
                growthStage: .juvenile,
                completesGrowth: false,
                onConfirm: {},
                onCancel: {}
            )
                .presentationDetents([.medium])
                .presentationBackground(.clear)
        }
}
