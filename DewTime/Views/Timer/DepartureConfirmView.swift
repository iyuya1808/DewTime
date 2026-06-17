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
                            let progress = requiredDepartures > 0
                                ? Double(departuresAfter) / Double(requiredDepartures)
                                : 0
                            let reached = stage.thresholdProgress <= progress
                            Image(systemName: stage.icon)
                                .font(.title3)
                                .foregroundStyle(reached ? stageColor : .white.opacity(0.22))
                                .scaleEffect(stage == growthStage ? 1.25 : 1.0)
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 28)

                    // インジケーターバッジ
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
                        // しずく進捗
                        dropProgressView(
                            before: departuresBefore,
                            after: departuresAfter,
                            required: requiredDepartures
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

    private func dropProgressView(before: Int, after: Int, required: Int) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "drop.fill")
                .foregroundStyle(stageColor)
                .font(.title2)

            // しずく粒アイコン列
            HStack(spacing: 4) {
                ForEach(0..<max(1, required), id: \.self) { index in
                    Image(systemName: index < after ? "drop.fill" : (index < before ? "drop.fill" : "drop"))
                        .font(.system(size: 10))
                        .foregroundStyle(
                            index < after ? stageColor : (index < before ? stageColor.opacity(0.5) : .white.opacity(0.22))
                        )
                }
            }
            .frame(height: 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityLabel("\(after)/\(required)しずく")
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
                departuresBefore: 2,
                departuresAfter: 3,
                requiredDepartures: 5,
                growthStage: .juvenile,
                completesGrowth: false,
                onConfirm: {},
                onCancel: {}
            )
            .presentationDetents([.medium])
            .presentationBackground(.clear)
        }
}
