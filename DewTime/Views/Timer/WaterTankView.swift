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
                    let visualLevel = level * 0.95
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    let colors = tankColors
                    let surface = TankSurface(
                        gravity: motion.gravity,
                        size: size,
                        waterLevel: visualLevel
                    )

                    drawWaterBody(
                        context: context,
                        size: size,
                        level: visualLevel,
                        time: time,
                        colors: colors,
                        surface: surface
                    )
                    drawCaustics(context: context, size: size, time: time, surface: surface)
                    drawBubbles(context: context, size: size, level: visualLevel, time: time, surface: surface)
                    drawFoam(context: context, size: size, level: visualLevel, time: time, surface: surface)
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

    private func waterPath(size: CGSize, level: Double, time: TimeInterval, surface: TankSurface) -> Path {
        var path = Path()
        let samples = surface.sampledSurface(level: level, time: time)
        guard let first = samples.first, let last = samples.last else { return path }

        path.move(to: first)
        for point in samples.dropFirst() {
            path.addLine(to: point)
        }

        let far = surface.down * (surface.extent * 2.4)
        path.addLine(to: last + far)
        path.addLine(to: first + far)
        path.closeSubpath()
        return path
    }

    private func drawWaterBody(
        context: GraphicsContext,
        size: CGSize,
        level: Double,
        time: TimeInterval,
        colors: (top: Color, middle: Color, bottom: Color, glow: Color),
        surface: TankSurface
    ) {
        let path = waterPath(size: size, level: level, time: time, surface: surface)
        let surfaceCenter = surface.centerPoint
        let deepPoint = surfaceCenter + surface.down * surface.extent
        context.fill(
            path,
            with: .linearGradient(
                Gradient(colors: [colors.top.opacity(0.94), colors.middle.opacity(0.92), colors.bottom]),
                startPoint: surfaceCenter,
                endPoint: deepPoint
            )
        )

        var glowContext = context
        glowContext.clip(to: path)
        glowContext.fill(
            Path(ellipseIn: CGRect(
                x: surfaceCenter.x - size.width * 0.68,
                y: surfaceCenter.y - size.height * 0.18,
                width: size.width * 1.36,
                height: size.height * 0.36
            )),
            with: .color(colors.glow.opacity(0.16))
        )
    }

    private func drawFoam(context: GraphicsContext, size: CGSize, level: Double, time: TimeInterval, surface: TankSurface) {
        guard level > 0.02 else { return }
        let samples = surface.sampledSurface(level: level, time: time)
        guard let first = samples.first else { return }

        var highlight = Path()
        var shadow = Path()
        highlight.move(to: first)
        shadow.move(to: first + surface.down * 8)

        for point in samples.dropFirst() {
            highlight.addLine(to: point)
            shadow.addLine(to: point + surface.down * 8)
        }

        context.stroke(highlight, with: .color(.white.opacity(0.62)), lineWidth: max(2, size.height * 0.004))
        context.stroke(shadow, with: .color(.white.opacity(0.18)), lineWidth: max(1, size.height * 0.002))
    }

    private func drawCaustics(context: GraphicsContext, size: CGSize, time: TimeInterval, surface: TankSurface) {
        let lineCount = 9
        for index in 0..<lineCount {
            let progress = CGFloat(index) / CGFloat(max(1, lineCount - 1))
            let distance = 36 + progress * max(40, surface.extent * 0.55)
            let center = surface.centerPoint + surface.down * distance
            var path = Path()
            var s = -surface.extent
            let start = center + surface.tangent * s
            path.move(to: start)
            while s <= surface.extent {
                let drift = CGFloat(sin(Double(s / 34) + time * 0.8 + Double(index))) * 8
                path.addLine(to: center + surface.tangent * s + surface.down * drift)
                s += 18
            }
            context.stroke(path, with: .color(.white.opacity(0.035 + Double(progress) * 0.025)), lineWidth: 1.2)
        }
    }

    private func drawBubbles(context: GraphicsContext, size: CGSize, level: Double, time: TimeInterval, surface: TankSurface) {
        guard level > 0.06 else { return }
        let count = 26
        let depthLimit = surface.extent * 0.95

        for index in 0..<count {
            let seed = CGFloat(index)
            let sBase = -surface.extent * 0.76 + CGFloat((index * 47) % 100) / 100 * surface.extent * 1.52
            let cycle = CGFloat((time * (0.08 + Double(index % 5) * 0.018)).truncatingRemainder(dividingBy: 1))
            let depth = max(10, (1 - cycle) * depthLimit)
            let sway = sin(CGFloat(time) * (0.7 + seed * 0.03) + seed) * (8 + seed.truncatingRemainder(dividingBy: 9))
            let point = surface.pointOnSurface(s: sBase + sway, level: level, time: time, base: surface.centerPoint) + surface.down * depth
            let radius = CGFloat(2 + (index % 5)) * (size.width > 220 ? 1.0 : 0.75)

            guard point.x > -radius, point.x < size.width + radius, point.y > -radius, point.y < size.height + radius else { continue }
            let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
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

private struct TankSurface {
    let gravity: CGVector
    let size: CGSize
    let waterLevel: Double

    var down: CGVector {
        let raw = CGVector(dx: gravity.dx, dy: -gravity.dy)
        let length = max(0.001, hypot(raw.dx, raw.dy))
        return CGVector(dx: raw.dx / length, dy: raw.dy / length)
    }

    var tangent: CGVector {
        CGVector(dx: -down.dy, dy: down.dx)
    }

    var extent: CGFloat {
        hypot(size.width, size.height)
    }

    var centerPoint: CGPoint {
        center + down * threshold
    }

    private var center: CGPoint {
        CGPoint(x: size.width / 2, y: size.height / 2)
    }

    private var threshold: CGFloat {
        let target = CGFloat(waterLevel) * size.width * size.height
        let corners = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: size.width, y: 0),
            CGPoint(x: size.width, y: size.height),
            CGPoint(x: 0, y: size.height)
        ].map { projection($0) }
        var low = (corners.min() ?? -extent) - extent
        var high = (corners.max() ?? extent) + extent

        for _ in 0..<26 {
            let mid = (low + high) / 2
            let area = waterArea(threshold: mid)
            if area > target {
                low = mid
            } else {
                high = mid
            }
        }

        return (low + high) / 2
    }

    private func projection(_ point: CGPoint) -> CGFloat {
        let relative = point - center
        return relative.dx * down.dx + relative.dy * down.dy
    }

    private func waterArea(threshold: CGFloat) -> CGFloat {
        let polygon = clippedRectangle(threshold: threshold)
        guard polygon.count >= 3 else { return 0 }

        var sum: CGFloat = 0
        for index in polygon.indices {
            let next = polygon[(index + 1) % polygon.count]
            sum += polygon[index].x * next.y - next.x * polygon[index].y
        }
        return abs(sum) * 0.5
    }

    private func clippedRectangle(threshold: CGFloat) -> [CGPoint] {
        let corners = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: size.width, y: 0),
            CGPoint(x: size.width, y: size.height),
            CGPoint(x: 0, y: size.height)
        ]
        var output: [CGPoint] = []

        for index in corners.indices {
            let current = corners[index]
            let next = corners[(index + 1) % corners.count]
            let currentValue = projection(current) - threshold
            let nextValue = projection(next) - threshold
            let currentInside = currentValue >= 0
            let nextInside = nextValue >= 0

            if currentInside && nextInside {
                output.append(next)
            } else if currentInside && !nextInside {
                output.append(intersection(from: current, to: next, currentValue: currentValue, nextValue: nextValue))
            } else if !currentInside && nextInside {
                output.append(intersection(from: current, to: next, currentValue: currentValue, nextValue: nextValue))
                output.append(next)
            }
        }

        return output
    }

    private func intersection(from current: CGPoint, to next: CGPoint, currentValue: CGFloat, nextValue: CGFloat) -> CGPoint {
        let denominator = currentValue - nextValue
        let amount = abs(denominator) > 0.0001 ? currentValue / denominator : 0
        return CGPoint(
            x: current.x + (next.x - current.x) * amount,
            y: current.y + (next.y - current.y) * amount
        )
    }

    func waveOffset(s: CGFloat, level: Double, time: TimeInterval) -> CGFloat {
        let amplitude = max(2, min(18, size.height * 0.025) * CGFloat(level))
        let primary = sin((s / max(extent, 1)) * .pi * 3.4 + time * 1.45)
        let secondary = sin((s / max(extent, 1)) * .pi * 8.2 - time * 1.0)
        return -amplitude * primary - amplitude * 0.38 * secondary
    }

    func pointOnSurface(s: CGFloat, level: Double, time: TimeInterval, base: CGPoint) -> CGPoint {
        base + tangent * s + down * waveOffset(s: s, level: level, time: time)
    }

    func sampledSurface(level: Double, time: TimeInterval) -> [CGPoint] {
        let step: CGFloat = 4
        let base = centerPoint
        var points: [CGPoint] = []
        var s = -extent

        while s <= extent {
            points.append(pointOnSurface(s: s, level: level, time: time, base: base))
            s += step
        }

        points.append(pointOnSurface(s: extent, level: level, time: time, base: base))
        return points
    }
}

private func + (lhs: CGPoint, rhs: CGVector) -> CGPoint {
    CGPoint(x: lhs.x + rhs.dx, y: lhs.y + rhs.dy)
}

private func - (lhs: CGPoint, rhs: CGPoint) -> CGVector {
    CGVector(dx: lhs.x - rhs.x, dy: lhs.y - rhs.y)
}

private func * (lhs: CGVector, rhs: CGFloat) -> CGVector {
    CGVector(dx: lhs.dx * rhs, dy: lhs.dy * rhs)
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
