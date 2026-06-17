import SwiftUI

struct DepartureResultView: View {
    let waterLevel: Double
    let elapsedFormatted: String
    let totalSeconds: Int
    let delaySeconds: Int
    let scheduleName: String
    let selectedSpecies: FishSpecies
    let earnedDrop: Bool
    let departuresAfter: Int
    let requiredDepartures: Int
    let growthStage: GrowthStage
    let completedGrowth: Bool
    let onDismiss: () -> Void

    @State private var waterFill: Double = 0

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            VStack(spacing: 0) {
                DragHandle()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // ヘッダー：成長アイコン群（テキストなし）
                        HStack(spacing: 20) {
                            ForEach(GrowthStage.allCases, id: \.self) { stage in
                                let progress = requiredDepartures > 0
                                    ? Double(departuresAfter) / Double(requiredDepartures)
                                    : 0
                                let reached = stage.thresholdProgress <= progress
                                Image(systemName: stage.icon)
                                    .font(.title2)
                                    .foregroundStyle(reached ? fishColor : .white.opacity(0.20))
                                    .scaleEffect(stage == growthStage ? 1.35 : 1.0)
                            }
                        }
                        .padding(.top, 24)

                        // 注水演出（ビジュアルとして維持）
                        PourTransitionView(waterLevel: waterLevel, species: selectedSpecies)
                            .frame(height: 232)

                        // 残水量ゲージ（数字あり）
                        VStack(spacing: 10) {
                            HStack {
                                Image(systemName: "drop.fill")
                                    .foregroundStyle(gaugeColors.first ?? .cyan)
                                    .font(.caption)
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

                        // しずく進捗
                        dropProgressRow

                        // 統計（アイコン + 数字のみ）
                        statsGrid

                        // 閉じるボタン（魚アイコン）
                        Button {
                            onDismiss()
                        } label: {
                            Image(systemName: completedGrowth ? "star.circle.fill" : "fish.fill")
                                .font(.system(size: 52))
                                .foregroundStyle(
                                    LinearGradient(colors: gaugeColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .shadow(color: gaugeColors.first!.opacity(0.45), radius: 12, y: 4)
                        }
                        .padding(.bottom, 16)
                        .accessibilityLabel("完了")
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
        }
    }

    // MARK: - Sub views

    private var dropProgressRow: some View {
        HStack(spacing: 8) {
            Image(systemName: earnedDrop ? "drop.fill" : "drop")
                .font(.title3)
                .foregroundStyle(earnedDrop ? fishColor : .white.opacity(0.35))

            HStack(spacing: 4) {
                ForEach(0..<max(1, requiredDepartures), id: \.self) { index in
                    Image(systemName: index < departuresAfter ? "drop.fill" : "drop")
                        .font(.system(size: 12))
                        .foregroundStyle(index < departuresAfter ? fishColor : .white.opacity(0.22))
                }
            }

            Spacer()

            Text("\(departuresAfter)/\(requiredDepartures)")
                .font(AppFont.badgeValue)
                .monospacedDigit()
                .foregroundStyle(fishColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityLabel("\(departuresAfter)/\(requiredDepartures)しずく")
    }

    private var statsGrid: some View {
        HStack(spacing: 12) {
            statCard(
                icon: "clock.fill",
                value: elapsedFormatted,
                color: .cyan
            )
            statCard(
                icon: "calendar.badge.clock",
                value: plannedFormatted,
                color: .indigo
            )
            statCard(
                icon: delaySeconds > 0 ? "tortoise.fill" : "hare.fill",
                value: delaySeconds > 0 ? "+\(delaySeconds / 60):\(String(format: "%02d", delaySeconds % 60))" : "✓",
                color: delaySeconds > 0 ? .orange : .green
            )
        }
    }

    private func statCard(icon: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title3)
            Text(value)
                .font(AppFont.statValue)
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Helpers

    private var plannedFormatted: String {
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return s == 0 ? "\(m)'" : String(format: "%d:%02d", m, s)
    }

    private var theme: WaterLevelTheme { WaterLevelTheme(waterRatio: waterLevel) }
    private var gaugeColors: [Color] { theme.gradientColors }
    private var fishColor: Color { completedGrowth ? theme.tintColor : .orange }

    private var background: some View { LinearGradient.dewTimeSheet }
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
                earnedDrop: true,
                departuresAfter: 5,
                requiredDepartures: 5,
                growthStage: .adult,
                completedGrowth: true,
                onDismiss: {}
            )
            .presentationDetents([.large])
            .presentationBackground(.clear)
        }
}
