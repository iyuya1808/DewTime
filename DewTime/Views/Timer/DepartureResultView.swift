import SwiftUI

struct DepartureResultView: View {
    let waterLevel: Double
    let elapsedFormatted: String
    let totalSeconds: Int
    let delaySeconds: Int
    let scheduleName: String
    let selectedSpecies: FishSpecies
    let waterAmount: Double
    let totalWaterAfter: Double
    let requiredTotalWater: Double
    let growthStage: GrowthStage
    let completedGrowth: Bool
    let onDismiss: () -> Void

    @State private var waterFill: Double = 0
    @State private var fishScale: CGFloat = 0

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

                        // 魚プレビュー
                        ZStack {
                            Circle()
                                .fill(fishBgColor.opacity(0.18))
                                .frame(width: 120, height: 120)
                            Text(selectedSpecies.emoji)
                                .font(.system(size: 62))
                                .scaleEffect(fishScale)
                                .animation(.spring(response: 0.5, dampingFraction: 0.5).delay(0.3), value: fishScale)
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

                        HStack(spacing: 10) {
                            fishMetric(
                                icon: selectedSpecies.icon,
                                value: "\(Int(totalWaterAfter.rounded()))/\(Int(requiredTotalWater.rounded()))pt",
                                label: "合計水量",
                                tint: fishColor
                            )
                            fishMetric(
                                icon: growthStage.icon,
                                value: growthStage.displayName,
                                label: "成長段階",
                                tint: fishColor
                            )
                        }

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
                            Text("また明日！ 🐟")
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
            if completedGrowth {
                let generator = UINotificationFeedbackGenerator()
                generator.prepare()
                generator.notificationOccurred(.success)
            } else {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.prepare()
                generator.impactOccurred()
            }

            withAnimation(.easeOut(duration: 1.2).delay(0.15)) {
                waterFill = waterLevel
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.5).delay(0.3)) {
                fishScale = 1.0
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

    private func fishMetric(icon: String, value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
                .symbolRenderingMode(.hierarchical)
            Text(value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(2)
                .multilineTextAlignment(.center)
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
        if completedGrowth { return "\(selectedSpecies.displayName)が成魚になりました！" }
        return growthStage.message
    }

    private var fishBgColor: Color {
        completedGrowth ? fishColor : .orange
    }

    private var theme: WaterLevelTheme { WaterLevelTheme(waterRatio: waterLevel) }
    private var gaugeColors: [Color] { theme.gradientColors }
    private var fishColor: Color { completedGrowth ? theme.tintColor : .orange }

    private var background: some View { LinearGradient.dewTimeSheet }

    private var motivationMessage: String {
        if completedGrowth {
            return "今回 +\(Int(waterAmount.rounded()))pt で必要水量に届きました。図鑑に成魚として登録されます。"
        }
        return "今回 +\(Int(waterAmount.rounded()))pt。合計 \(Int(totalWaterAfter.rounded()))/\(Int(requiredTotalWater.rounded()))pt まで育ちました。"
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
                selectedSpecies: .dolphin,
                waterAmount: 72,
                totalWaterAfter: 240,
                requiredTotalWater: 240,
                growthStage: .adult,
                completedGrowth: true,
                onDismiss: {}
            )
            .presentationDetents([.large])
            .presentationBackground(.clear)
        }
}
