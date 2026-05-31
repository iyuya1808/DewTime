import SwiftUI
import Combine
import CoreMotion

struct WaterTankView: View {
    var waterLevel: Double   // 0.0 - 1.0
    var isOverdue: Bool = false
    var cornerRadius: CGFloat = 36
    var showBorder: Bool = true
    var showLevelText: Bool = true

    @StateObject private var motion = TankMotionManager()

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.02, green: 0.07, blue: 0.18),
                            Color(red: 0.03, green: 0.14, blue: 0.27)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            if showBorder {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.18), lineWidth: 1.5)
                    )
            }

            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                Canvas { context, size in
                    let level = max(0, min(1, waterLevel))
                    let waterTop = max(size.height * 0.015, size.height * (1 - level))
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    let colors = tankColors
                    let tilt = TankTilt(
                        gravity: motion.gravity,
                        size: size,
                        waterLevel: level
                    )

                    drawWaterBody(
                        context: context,
                        size: size,
                        waterTop: waterTop,
                        level: level,
                        time: time,
                        colors: colors,
                        tilt: tilt
                    )
                    drawCaustics(context: context, size: size, waterTop: waterTop, time: time, tilt: tilt)
                    drawBubbles(context: context, size: size, waterTop: waterTop, level: level, time: time, tilt: tilt)
                    drawFoam(context: context, size: size, waterTop: waterTop, level: level, time: time, tilt: tilt)
                    drawGlassShine(context: context, size: size)
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
        .onAppear { motion.start() }
        .onDisappear { motion.stop() }
    }

    private var tankColors: (top: Color, middle: Color, bottom: Color, glow: Color) {
        if isOverdue {
            return (
                Color.dewTankOverdueTop,
                Color(red: 0.98, green: 0.24, blue: 0.20),
                Color.dewTankOverdueBottom,
                Color.orange
            )
        }
        return (
            Color(red: 0.42, green: 0.94, blue: 1.0),
            Color.dewTankWaterTop,
            Color.dewTankWaterBottom,
            Color.dewBlue
        )
    }

    private func waveY(
        x: CGFloat,
        waterTop: CGFloat,
        width: CGFloat,
        amplitude: CGFloat,
        time: TimeInterval,
        tilt: TankTilt
    ) -> CGFloat {
        let primary = sin((x / max(width, 1)) * .pi * 2.1 + time * 1.45)
        let secondary = sin((x / max(width, 1)) * .pi * 5.4 - time * 1.0)
        return waterTop + tilt.surfaceOffset(x: x) - amplitude * primary - amplitude * 0.38 * secondary
    }

    private func waterPath(size: CGSize, waterTop: CGFloat, level: Double, time: TimeInterval, tilt: TankTilt) -> Path {
        var path = Path()
        let amplitude = max(2, min(18, size.height * 0.025) * CGFloat(level))
        path.move(to: CGPoint(x: 0, y: waveY(x: 0, waterTop: waterTop, width: size.width, amplitude: amplitude, time: time, tilt: tilt)))

        var x: CGFloat = 0
        while x <= size.width {
            path.addLine(
                to: CGPoint(
                    x: x,
                    y: waveY(x: x, waterTop: waterTop, width: size.width, amplitude: amplitude, time: time, tilt: tilt)
                )
            )
            x += 4
        }

        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.addLine(to: CGPoint(x: 0, y: size.height))
        path.closeSubpath()
        return path
    }

    private func drawWaterBody(
        context: GraphicsContext,
        size: CGSize,
        waterTop: CGFloat,
        level: Double,
        time: TimeInterval,
        colors: (top: Color, middle: Color, bottom: Color, glow: Color),
        tilt: TankTilt
    ) {
        let path = waterPath(size: size, waterTop: waterTop, level: level, time: time, tilt: tilt)
        let leftSurface = waterTop + tilt.surfaceOffset(x: 0)
        let rightSurface = waterTop + tilt.surfaceOffset(x: size.width)
        context.fill(
            path,
            with: .linearGradient(
                Gradient(colors: [colors.top.opacity(0.94), colors.middle.opacity(0.92), colors.bottom]),
                startPoint: CGPoint(x: size.width / 2, y: min(leftSurface, rightSurface)),
                endPoint: CGPoint(x: size.width / 2, y: size.height)
            )
        )

        var glowContext = context
        glowContext.clip(to: path)
        glowContext.fill(
            Path(ellipseIn: CGRect(
                x: -size.width * 0.18,
                y: waterTop - size.height * 0.08,
                width: size.width * 1.36,
                height: size.height * 0.35
            )),
            with: .color(colors.glow.opacity(0.16))
        )
    }

    private func drawFoam(context: GraphicsContext, size: CGSize, waterTop: CGFloat, level: Double, time: TimeInterval, tilt: TankTilt) {
        guard level > 0.02 else { return }
        let amplitude = max(2, min(18, size.height * 0.025) * CGFloat(level))
        var highlight = Path()
        var shadow = Path()

        var x: CGFloat = 0
        highlight.move(to: CGPoint(x: 0, y: waveY(x: 0, waterTop: waterTop, width: size.width, amplitude: amplitude, time: time, tilt: tilt)))
        shadow.move(to: CGPoint(x: 0, y: waveY(x: 0, waterTop: waterTop + 8, width: size.width, amplitude: amplitude * 0.7, time: time + 0.8, tilt: tilt)))

        while x <= size.width {
            highlight.addLine(to: CGPoint(x: x, y: waveY(x: x, waterTop: waterTop, width: size.width, amplitude: amplitude, time: time, tilt: tilt)))
            shadow.addLine(to: CGPoint(x: x, y: waveY(x: x, waterTop: waterTop + 8, width: size.width, amplitude: amplitude * 0.7, time: time + 0.8, tilt: tilt)))
            x += 4
        }

        context.stroke(highlight, with: .color(.white.opacity(0.62)), lineWidth: max(2, size.height * 0.004))
        context.stroke(shadow, with: .color(.white.opacity(0.18)), lineWidth: max(1, size.height * 0.002))
    }

    private func drawCaustics(context: GraphicsContext, size: CGSize, waterTop: CGFloat, time: TimeInterval, tilt: TankTilt) {
        let lineCount = 9
        for index in 0..<lineCount {
            let progress = CGFloat(index) / CGFloat(max(1, lineCount - 1))
            let y = waterTop + tilt.surfaceOffset(x: size.width * 0.5) + 36 + progress * max(0, size.height - waterTop - 60)
            var path = Path()
            var x: CGFloat = -40
            path.move(to: CGPoint(x: x, y: y))
            while x <= size.width + 40 {
                let drift = sin(x / 34 + time * 0.8 + Double(index)) * 8
                path.addLine(to: CGPoint(x: x, y: y + CGFloat(drift)))
                x += 18
            }
            context.stroke(path, with: .color(.white.opacity(0.035 + Double(progress) * 0.025)), lineWidth: 1.2)
        }
    }

    private func drawBubbles(context: GraphicsContext, size: CGSize, waterTop: CGFloat, level: Double, time: TimeInterval, tilt: TankTilt) {
        guard level > 0.06 else { return }
        let count = 26
        let waterHeight = max(1, size.height - waterTop)

        for index in 0..<count {
            let seed = CGFloat(index)
            let xBase = CGFloat((index * 47) % max(1, Int(size.width)))
            let cycle = CGFloat((time * (0.08 + Double(index % 5) * 0.018)).truncatingRemainder(dividingBy: 1))
            let y = size.height - cycle * waterHeight
            let sway = sin(CGFloat(time) * (0.7 + seed * 0.03) + seed) * (8 + seed.truncatingRemainder(dividingBy: 9))
            let x = xBase + sway - tilt.normalizedX * cycle * size.width * 0.22
            let radius = CGFloat(2 + (index % 5)) * (size.width > 220 ? 1.0 : 0.75)

            guard y > waterTop + tilt.surfaceOffset(x: x) + radius, x > -radius, x < size.width + radius else { continue }
            let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
            context.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(0.16)), lineWidth: 1)
            context.fill(Path(ellipseIn: rect.insetBy(dx: radius * 0.62, dy: radius * 0.62)), with: .color(.white.opacity(0.22)))
        }
    }

    private func drawGlassShine(context: GraphicsContext, size: CGSize) {
        let shine = Path(roundedRect: CGRect(
            x: size.width * 0.08,
            y: size.height * 0.04,
            width: size.width * 0.11,
            height: size.height * 0.72
        ), cornerRadius: size.width * 0.08)
        context.fill(shine, with: .linearGradient(
            Gradient(colors: [.white.opacity(0.18), .white.opacity(0.02)]),
            startPoint: CGPoint(x: size.width * 0.08, y: 0),
            endPoint: CGPoint(x: size.width * 0.20, y: size.height)
        ))
    }
}

private struct TankTilt {
    let gravity: CGVector
    let size: CGSize
    let waterLevel: Double

    var normalizedX: CGFloat {
        let screenDown = max(0.30, abs(gravity.dy))
        return max(-1, min(1, gravity.dx / screenDown))
    }

    private var maxRise: CGFloat {
        let waterHeight = size.height * CGFloat(waterLevel)
        let airHeight = size.height - waterHeight
        let availableSpace = max(10, min(waterHeight, airHeight + size.height * 0.12))
        return min(size.height * 0.16, availableSpace * 0.55)
    }

    func surfaceOffset(x: CGFloat) -> CGFloat {
        let centeredX = (x / max(size.width, 1)) - 0.5
        return -normalizedX * centeredX * maxRise * 2
    }
}

@MainActor
private final class TankMotionManager: ObservableObject {
    @Published private(set) var gravity = CGVector(dx: 0, dy: -1)

    private let manager = CMMotionManager()
    private let queue = OperationQueue()

    init() {
        queue.name = "DewTime.TankMotion"
        queue.qualityOfService = .userInteractive
    }

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }

        manager.deviceMotionUpdateInterval = 1.0 / 45.0
        manager.startDeviceMotionUpdates(to: queue) { [weak self] motion, _ in
            guard let motion else { return }
            let nextGravity = CGVector(dx: motion.gravity.x, dy: motion.gravity.y)

            Task { @MainActor [weak self] in
                guard let self else { return }
                gravity = CGVector(
                    dx: gravity.dx * 0.82 + nextGravity.dx * 0.18,
                    dy: gravity.dy * 0.82 + nextGravity.dy * 0.18
                )
            }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
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
