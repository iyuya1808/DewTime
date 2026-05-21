import SwiftUI

struct DepartureConfirmView: View {
    let waterLevel: Double
    let isOnTime: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @State private var emojiScale: CGFloat = 0.8

    var body: some View {
        VStack(spacing: 0) {
            DragHandle()
                .padding(.bottom, 28)

            // メインメッセージ
            VStack(spacing: 12) {
                Text(headerEmoji)
                    .font(.system(size: 60))
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
                    color: isOnTime ? .green : .orange
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

    private var headerEmoji: String {
        if waterLevel > 0.7 { return "🌊" }
        if waterLevel > 0.4 { return "💧" }
        return "🪣"
    }

    private var headline: String {
        if waterLevel > 0.7 { return "準備バッチリ！\n出発しますか？" }
        if waterLevel > 0.4 { return "まだ間に合います\n出発しますか？" }
        return "急いで！\nもう出発しますか？"
    }

    private var subtext: String {
        if waterLevel > 0.7 { return "タンクに水がたっぷり残っています\n植物が大喜びしそうです 🌿" }
        if waterLevel > 0.4 { return "そこそこ水が残っています\n植物はまあまあ育ちそうです" }
        return "水がほとんどありません\n次回はもう少し早めに！"
    }

    private var theme: WaterLevelTheme { WaterLevelTheme(waterRatio: waterLevel) }

    private var waterLevelColor: Color { theme.tintColor }
    private var confirmColors: [Color] { theme.gradientColors }
}

#Preview {
    Color.black.ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            DepartureConfirmView(waterLevel: 0.72, isOnTime: true, onConfirm: {}, onCancel: {})
                .presentationDetents([.medium])
                .presentationBackground(.clear)
        }
}
