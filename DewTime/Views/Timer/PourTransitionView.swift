import SwiftUI

/// 出発結果シートの先頭で再生する「タンクの水が水槽へ注ぎ込む」演出。
struct PourTransitionView: View {
    let waterLevel: Double
    let aquariumTier: Int

    @State private var tankLevel: Double = 0
    @State private var bowlFill: Double = 0
    @State private var iconScale: CGFloat = 0
    @State private var streamOpacity: Double = 0

    private var theme: WaterLevelTheme { WaterLevelTheme(waterRatio: waterLevel) }

    var body: some View {
        VStack(spacing: 0) {
            WaterTankView(
                waterLevel: tankLevel,
                cornerRadius: 14,
                showBorder: true
            )
            .frame(width: 60, height: 66)

            PourStreamView(colors: theme.gradientColors)
                .frame(width: 14, height: 26)
                .opacity(streamOpacity)

            AquariumBowlView(
                fill: bowlFill,
                colors: theme.gradientColors,
                aquariumTier: aquariumTier,
                iconScale: iconScale
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

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred()
        }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.55).delay(1.05)) {
            iconScale = 1.0
        }
        withAnimation(.easeOut(duration: 0.4).delay(1.1)) {
            streamOpacity = 0
        }
    }
}

struct PourStreamView: View {
    let colors: [Color]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 45.0)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let column = Path(roundedRect: CGRect(x: size.width * 0.2, y: 0, width: size.width * 0.6, height: size.height), cornerRadius: size.width * 0.3)
                context.fill(column, with: .linearGradient(
                    Gradient(colors: colors),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 0, y: size.height)
                ))
                context.fill(column, with: .color(.white.opacity(0.12)))
                for i in 0..<5 {
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

private struct AquariumBowlView: View {
    let fill: Double
    let colors: [Color]
    let aquariumTier: Int
    var iconScale: CGFloat

    var body: some View {
        GeometryReader { geo in
            let diameter = min(geo.size.width, geo.size.height)
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.06))

                Rectangle()
                    .fill(
                        LinearGradient(colors: colors.map { $0.opacity(0.55) }, startPoint: .top, endPoint: .bottom)
                    )
                    .frame(height: diameter * CGFloat(max(0, min(1, fill))))
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .clipShape(Circle())

                Image(systemName: aquariumTier >= Aquarium.maxTier ? "sparkles" : "drop.fill")
                    .font(.system(size: diameter * 0.28, weight: .bold))
                    .foregroundStyle(aquariumTier >= Aquarium.maxTier ? .yellow : .cyan)
                    .scaleEffect(iconScale)

                Circle()
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1.5)
            }
            .frame(width: diameter, height: diameter)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
