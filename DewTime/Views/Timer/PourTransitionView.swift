import SwiftUI

/// 出発結果シートの先頭で再生する「タンクの水が水槽へ注ぎ込む」演出。
/// 上のタンクが空になりながら、下の水槽に水が満ち、魚がスケールアップする。
struct PourTransitionView: View {
    let waterLevel: Double          // 0.0 - 1.0（注ぎ込む残水量）
    let species: FishSpecies

    @State private var tankLevel: Double = 0
    @State private var bowlFill: Double = 0
    @State private var fishScale: CGFloat = 0
    @State private var streamOpacity: Double = 0

    private var theme: WaterLevelTheme { WaterLevelTheme(waterRatio: waterLevel) }

    var body: some View {
        VStack(spacing: 0) {
            // 上：水が抜けていくタンク
            WaterTankView(
                waterLevel: tankLevel,
                cornerRadius: 14,
                showBorder: true,
                showLevelText: false
            )
            .frame(width: 60, height: 66)

            // 中：流れ落ちる水流
            PourStreamView(colors: theme.gradientColors)
                .frame(width: 14, height: 26)
                .opacity(streamOpacity)

            // 下：水が満ちる水槽と育つ魚
            AquariumBowlView(
                fill: bowlFill,
                colors: theme.gradientColors,
                species: species,
                fishScale: fishScale
            )
            .frame(width: 132, height: 132)
        }
        .onAppear { runSequence() }
    }

    private func runSequence() {
        tankLevel = waterLevel

        withAnimation(.easeIn(duration: 0.3)) {
            streamOpacity = 1
        }
        withAnimation(.easeInOut(duration: 1.0).delay(0.15)) {
            tankLevel = 0
        }
        withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
            bowlFill = waterLevel
        }

        // 着水のハプティクス
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred()
        }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.55).delay(1.05)) {
            fishScale = 1.0
        }
        withAnimation(.easeOut(duration: 0.4).delay(1.1)) {
            streamOpacity = 0
        }
    }
}

/// タンクと水槽の間を流れ落ちる水の柱。きらめきを重ねる。
private struct PourStreamView: View {
    let colors: [Color]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 45.0)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                // 水の柱
                let column = Path(roundedRect: CGRect(x: size.width * 0.32, y: 0, width: size.width * 0.36, height: size.height), cornerRadius: size.width * 0.18)
                context.fill(column, with: .linearGradient(
                    Gradient(colors: colors),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 0, y: size.height)
                ))
                // 流れるきらめき
                for i in 0..<3 {
                    let phase = (t * 1.6 + Double(i) * 0.4).truncatingRemainder(dividingBy: 1)
                    let y = CGFloat(phase) * size.height
                    let r = size.width * 0.12
                    let rect = CGRect(x: size.width * 0.5 - r / 2, y: y - r / 2, width: r, height: r)
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.5)))
                }
            }
        }
    }
}

/// 水が下から満ちていく丸い水槽。中で魚が育つ。
private struct AquariumBowlView: View {
    let fill: Double
    let colors: [Color]
    let species: FishSpecies
    var fishScale: CGFloat

    var body: some View {
        GeometryReader { geo in
            let diameter = min(geo.size.width, geo.size.height)
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.06))

                // 水（下から満ちる）
                Rectangle()
                    .fill(
                        LinearGradient(colors: colors.map { $0.opacity(0.55) }, startPoint: .top, endPoint: .bottom)
                    )
                    .frame(height: diameter * CGFloat(max(0, min(1, fill))))
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .clipShape(Circle())

                // 魚
                FishArtworkView(species: species)
                    .frame(width: diameter * 0.62, height: diameter * 0.58)
                    .scaleEffect(fishScale)

                Circle()
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1.5)
            }
            .frame(width: diameter, height: diameter)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
