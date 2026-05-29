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

    @State private var emojiScale: CGFloat = 0.8

    var body: some View {
        VStack(spacing: 0) {
            DragHandle()
                .padding(.bottom, 28)

            // メインメッセージ
            VStack(spacing: 12) {
                Text(selectedSpecies.emoji)
                    .font(.system(size: 58))
                    .scaleEffect(emojiScale)
                    .animation(.spring(response: 0.4, dampingFraction: 0.5), value: emojiScale)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { emojiScale = 1.0 }
                    }

                Text(headline)
                    .font(AppFont.confirmTitle)
                    .multilineTextAlignment(.center)

                Text(subtext)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(.bottom, 32)

            // 水量バッジ
            HStack(spacing: 12) {
                badgeView(
                    value: "\(Int(waterLevel * 100))%",
                    label: "タンク残量",
                    icon: "drop.fill",
                    color: waterLevelColor
                )
                badgeView(
                    value: isOnTime ? "オンタイム" : "遅延あり",
                    label: "スケジュール",
                    icon: isOnTime ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
                    color: isOnTime ? .teal : .orange
                )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)

            HStack(spacing: 12) {
                badgeView(
                    value: "\(Int(totalWaterBefore.rounded()))/\(Int(requiredTotalWater.rounded()))pt",
                    label: "現在の育成水量",
                    icon: selectedSpecies.icon,
                    color: stageColor
                )
                badgeView(
                    value: "+\(Int(waterAmount.rounded()))pt",
                    label: "今回の水やり",
                    icon: "drop.fill",
                    color: waterLevelColor
                )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)

            // ボタン
            VStack(spacing: 10) {
                Button(action: onConfirm) {
                    HStack(spacing: 10) {
                        Text("いってきます！")
                            .font(AppFont.actionButton)
                        Image(systemName: "figure.walk.departure")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(colors: confirmColors, startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: confirmColors.first!.opacity(0.4), radius: 10, y: 4)
                }

                Button(action: onCancel) {
                    Text("まだもう少し…戻る")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.45))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
        .foregroundStyle(.white)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(LinearGradient.dewTimeSheet)
                .ignoresSafeArea()
        )
    }

    private func badgeView(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title3)
            Text(value)
                .font(AppFont.badgeValue)
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var headline: String {
        if completesGrowth { return "\(selectedSpecies.displayName)が成魚になりそうです\n出発しますか？" }
        return "\(growthStage.message)\n出発しますか？"
    }

    private var subtext: String {
        "今回 +\(Int(waterAmount.rounded()))pt で、合計 \(Int(totalWaterAfter.rounded()))/\(Int(requiredTotalWater.rounded()))pt になります。"
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
