import SwiftUI

struct WaterTankView: View {
    var waterLevel: Double   // 0.0 – 1.0
    var isOverdue: Bool = false
    var cornerRadius: CGFloat = 36
    var showBorder: Bool = true
    var showLevelText: Bool = true

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if showBorder {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1.5)
                        )
                }

                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                    Canvas { context, size in
                        let level = max(0, min(1, waterLevel))
                        let baseY = max(size.height * 0.01, size.height * (1 - level))
                        let amp: CGFloat = level > 0.02 ? 6 : 1
                        let wavelength: CGFloat = size.width * 0.85
                        let phase = timeline.date.timeIntervalSinceReferenceDate * 1.4

                        // メイン波
                        var path = Path()
                        path.move(to: CGPoint(x: 0, y: baseY))
                        var x: CGFloat = 0
                        while x <= size.width {
                            let y = baseY - amp * sin(2 * .pi * x / wavelength + phase)
                            path.addLine(to: CGPoint(x: x, y: CGFloat(y)))
                            x += 3
                        }
                        path.addLine(to: CGPoint(x: size.width, y: size.height))
                        path.addLine(to: CGPoint(x: 0, y: size.height))
                        path.closeSubpath()

                        let topColor    = isOverdue ? Color.dewTankOverdueTop    : Color.dewTankWaterTop
                        let bottomColor = isOverdue ? Color.dewTankOverdueBottom : Color.dewTankWaterBottom

                        context.fill(path, with: .linearGradient(
                            Gradient(colors: [topColor, bottomColor]),
                            startPoint: CGPoint(x: size.width / 2, y: baseY),
                            endPoint: CGPoint(x: size.width / 2, y: size.height)
                        ))

                        // ハイライト波
                        var hl = Path()
                        hl.move(to: CGPoint(x: 0, y: baseY))
                        x = 0
                        while x <= size.width {
                            let y = baseY - amp * sin(2 * .pi * x / wavelength + phase)
                            hl.addLine(to: CGPoint(x: x, y: CGFloat(y)))
                            x += 3
                        }
                        context.stroke(hl, with: .color(Color.white.opacity(0.45)), lineWidth: 1.5)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

                if showLevelText {
                    VStack(spacing: 2) {
                        Text("\(Int(waterLevel * 100))")
                            .font(AppFont.waterDisplay)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text("%")
                            .font(AppFont.waterUnit)
                    }
                    .foregroundStyle(.white.opacity(0.85))
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                }
            }
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        WaterTankView(waterLevel: 0.75)
            .frame(width: 140, height: 280)
        WaterTankView(waterLevel: 0.2, isOverdue: true)
            .frame(width: 140, height: 280)
    }
    .padding()
    .background(Color(red: 0.07, green: 0.10, blue: 0.22))
}
