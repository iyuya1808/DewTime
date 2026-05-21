import SwiftUI

struct DepartureResultView: View {
    let waterLevel: Double
    let elapsedFormatted: String
    let totalSeconds: Int
    let delaySeconds: Int
    let scheduleName: String
    let onDismiss: () -> Void

    @State private var waterFill: Double = 0
    @State private var plantScale: CGFloat = 0

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            VStack(spacing: 0) {
                DragHandle()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        // タイトル
                        VStack(spacing: 6) {
                            Text("お疲れさまでした！")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.55))
                                .padding(.top, 24)
                            Text(scheduleName)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.35))
                            Text(resultTitle)
                                .font(AppFont.sheetTitle)
                                .multilineTextAlignment(.center)
                        }

                        // 植物プレビュー
                        ZStack {
                            Circle()
                                .fill(plantBgColor.opacity(0.18))
                                .frame(width: 120, height: 120)
                            Text(plantEmoji)
                                .font(.system(size: 64))
                                .scaleEffect(plantScale)
                                .animation(.spring(response: 0.5, dampingFraction: 0.5).delay(0.3), value: plantScale)
                        }

                        // 水量ゲージ
                        VStack(spacing: 10) {
                            HStack {
                                Text("残水量")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.55))
                                Spacer()
                                Text("\(Int(waterFill * 100))%")
                                    .font(AppFont.badgeValue)
                                    .monospacedDigit()
                                    .contentTransition(.numericText())
                            }

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(.white.opacity(0.12))
                                        .frame(height: 14)
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: gaugeColors,
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geo.size.width * waterFill, height: 14)
                                        .animation(.easeOut(duration: 1.2).delay(0.2), value: waterFill)
                                }
                            }
                            .frame(height: 14)
                        }
                        .padding(.horizontal, 4)

                        // 統計カード
                        statsGrid

                        // メッセージ
                        Text(motivationMessage)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.65))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)

                        // 閉じるボタン
                        Button {
                            onDismiss()
                        } label: {
                            Text("また明日！ 🌱")
                                .font(AppFont.actionButton)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(
                                    LinearGradient(colors: gaugeColors, startPoint: .leading, endPoint: .trailing)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .padding(.bottom, 16)
                    }
                    .padding(.horizontal, 24)
                }
            }
            .foregroundStyle(.white)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2).delay(0.15)) {
                waterFill = waterLevel
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.5).delay(0.3)) {
                plantScale = 1.0
            }
        }
    }

    // MARK: - Sub views

    private var statsGrid: some View {
        HStack(spacing: 12) {
            statCard(
                icon: "clock.fill",
                value: elapsedFormatted,
                label: "経過時間",
                color: .cyan
            )
            statCard(
                icon: "calendar.badge.clock",
                value: plannedFormatted,
                label: "予定時間",
                color: .indigo
            )
            statCard(
                icon: delaySeconds > 0 ? "tortoise.fill" : "hare.fill",
                value: delaySeconds > 0 ? "+\(delaySeconds / 60)分\(delaySeconds % 60)秒" : "ジャスト",
                label: delaySeconds > 0 ? "遅延" : "スケジュール通り！",
                color: delaySeconds > 0 ? .orange : .green
            )
        }
    }

    private func statCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title3)
            Text(value)
                .font(AppFont.statValue)
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(AppFont.statLabel)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Helpers

    private var plannedFormatted: String {
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return s == 0 ? "\(m)分" : String(format: "%02d:%02d", m, s)
    }

    private var resultTitle: String {
        if waterLevel > 0.8 { return "今日も完璧な朝だ！ 🌟" }
        if waterLevel > 0.5 { return "いい感じの朝でした！ 🌤" }
        if waterLevel > 0.2 { return "明日はもう少し早めに！ ☁️" }
        return "お急ぎでしたね 😅\n次は余裕で出発しよう！"
    }

    private var plantEmoji: String {
        if waterLevel > 0.8 { return "🌸" }
        if waterLevel > 0.6 { return "🌼" }
        if waterLevel > 0.4 { return "🌿" }
        if waterLevel > 0.2 { return "🌱" }
        return "🥀"
    }

    private var plantBgColor: Color {
        if waterLevel > 0.6 { return .pink }
        if waterLevel > 0.3 { return .green }
        return .orange
    }

    private var theme: WaterLevelTheme { WaterLevelTheme(waterRatio: waterLevel) }
    private var gaugeColors: [Color] { theme.gradientColors }

    private var background: some View { LinearGradient.dewTimeSheet }

    private var motivationMessage: String {
        if waterLevel > 0.8 { return "たっぷり水が残りました！\n植物が大きく育ちますように 🌿" }
        if waterLevel > 0.5 { return "まずまずの水量です\n明日はさらに余裕で出発できるかも！" }
        if waterLevel > 0.2 { return "少し水が足りなかったけど大丈夫\n早起きの練習、続けましょう ✨" }
        return "今日は大変でしたね\n明日は少し早めにスタートしてみましょう ☀️"
    }
}

#Preview {
    Color.black.ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            DepartureResultView(
                waterLevel: 0.72,
                elapsedFormatted: "18:34",
                totalSeconds: 1320,
                delaySeconds: 0,
                scheduleName: "平日通常モード",
                onDismiss: {}
            )
            .presentationDetents([.large])
            .presentationBackground(.clear)
        }
}
