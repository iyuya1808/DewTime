import SwiftUI

// MARK: - 単体魚の物理エンジン

private final class TimerFishEngine {
    struct Fish {
        var x: CGFloat = 0.5
        var y: CGFloat = 0.6
        var heading: CGFloat = 0
        var bobPhase: CGFloat = 0
        var finPhase: CGFloat = 0
        var facingRight: Bool = true
    }

    var fish = Fish()
    private var lastTime: TimeInterval?

    init() {
        fish.x = CGFloat.random(in: 0.2...0.8)
        fish.y = CGFloat.random(in: 0.45...0.75)
        fish.heading = CGFloat.random(in: 0...(2 * .pi))
        fish.bobPhase = CGFloat.random(in: 0...(2 * .pi))
        fish.finPhase = CGFloat.random(in: 0...(2 * .pi))
    }

    func step(time: TimeInterval, waterLevel: Double) {
        guard let last = lastTime else { lastTime = time; return }
        let dt = CGFloat(min(max(time - last, 0), 1.0 / 30.0))
        lastTime = time
        guard dt > 0 else { return }

        fish.bobPhase += dt * 2.0
        fish.finPhase += dt * 7.5
        fish.heading += CGFloat.random(in: -1...1) * dt * 1.2

        let speed: CGFloat = 0.09
        let vx = cos(fish.heading) * speed
        let vy = sin(fish.heading) * speed * 0.4
        fish.x += vx * dt
        fish.y += vy * dt

        // 水面ラインより少し下・底より上で反射
        // WaterTankView は visualLevel = waterLevel * 0.95 で描画するので同じ係数を使う
        let surfaceY = CGFloat(1.0 - waterLevel * 0.95) + 0.06
        let clamped = max(0.20, CGFloat(waterLevel))
        let bottomY = CGFloat(1.0 - (1.0 - clamped) * 0.95) - 0.05

        let margin: CGFloat = 0.09
        if fish.x < margin        { fish.x = margin;        fish.heading = .pi - fish.heading }
        if fish.x > 1 - margin    { fish.x = 1 - margin;    fish.heading = .pi - fish.heading }
        if fish.y < surfaceY      { fish.y = surfaceY;      fish.heading = -fish.heading }
        if fish.y > bottomY       { fish.y = max(surfaceY, bottomY - 0.01); fish.heading = -fish.heading }

        if abs(vx) > 0.0005 { fish.facingRight = vx > 0 }
    }
}

// MARK: - オーバーレイビュー

/// タイマータブ用の単体魚アニメーション。水位内に収まって泳ぐ。純粋ビジュアルのみ（タッチ非遮断）。
struct TimerFishOverlay: View {
    let species: FishSpecies
    let waterLevel: Double

    @State private var engine = TimerFishEngine()

    private var renderSize: CGFloat { species.displaySize(for: .timer) }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            Canvas { context, size in
                engine.step(
                    time: timeline.date.timeIntervalSinceReferenceDate,
                    waterLevel: waterLevel
                )
                let f = engine.fish
                let fishSize = renderSize
                let bob = sin(f.bobPhase) * (fishSize * 0.055)
                let x = f.x * size.width
                let y = f.y * size.height + bob
                let wiggle = sin(f.finPhase) * 5.0

                var ctx = context
                ctx.translateBy(x: x, y: y)
                ctx.rotate(by: .degrees(Double(wiggle)))
                ctx.scaleBy(x: f.facingRight ? 1 : -1, y: 1)
                FishArtworkRenderer.draw(
                    species,
                    in: CGRect(x: -fishSize / 2, y: -fishSize / 2,
                               width: fishSize, height: fishSize),
                    context: &ctx
                )
            }
        }
        .allowsHitTesting(false)
    }
}
