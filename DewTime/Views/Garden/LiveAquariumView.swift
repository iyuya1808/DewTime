import SwiftUI

// MARK: - シミュレーション要素

/// 水槽内を泳ぐ1匹の魚。座標は 0...1 の正規化空間で保持し、描画時にサイズへスケールする。
private struct SwimmingFish: Identifiable {
    var id: UUID
    var name: String
    var species: FishSpecies
    /// 描画サイズ（pt）。
    var size: CGFloat
    /// 巡航速度（正規化単位/秒）。
    var speed: CGFloat
    /// コレクション未取得のサンプル魚（薄く描画）。
    var ghost: Bool

    var x: CGFloat
    var y: CGFloat
    /// 進行方向（ラジアン）。
    var heading: CGFloat
    /// 上下のゆらぎ位相。
    var bobPhase: CGFloat
    /// ヒレのはためき位相。
    var finPhase: CGFloat
    /// タップされて喜んでいる残り時間。
    var happy: CGFloat = 0
    /// 進行方向が右向きか。
    var facingRight: Bool = true
}

/// 立ち上る泡。
private struct Bubble: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var rise: CGFloat
    var wobblePhase: CGFloat
}

/// タップで落とすエサ。
private struct FoodPellet: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var sink: CGFloat
    var wobblePhase: CGFloat
}

/// 魚タップ時に立ち上るハート。
private struct Heart: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var life: CGFloat
    var drift: CGFloat
}

/// 投入する魚の仕様（ビュー側で `FishSpecies` から生成）。
private struct FishSpec {
    var id: UUID
    var name: String
    var species: FishSpecies
    var size: CGFloat
    var speed: CGFloat
    var ghost: Bool
}

/// 水槽の物理シミュレーション本体。`@Observable` にせず、`TimelineView(.animation)` の
/// 再描画にあわせて毎フレーム `step` を呼び、その結果を `Canvas` で描く。
private final class AquariumEngine {
    var fish: [SwimmingFish] = []
    var bubbles: [Bubble] = []
    var food: [FoodPellet] = []
    var hearts: [Heart] = []

    private var lastTime: TimeInterval?
    private var bubbleTimer: CGFloat = 0

    /// 種構成が変わったときだけ作り直す。
    func populate(_ specs: [FishSpec]) {
        let signature = specs.map { "\($0.id.uuidString)\($0.name)\($0.species.rawValue)\($0.ghost)" }.joined()
        guard signature != currentSignature else { return }
        currentSignature = signature

        fish = specs.map { spec in
            SwimmingFish(
                id: spec.id,
                name: spec.name,
                species: spec.species,
                size: spec.size,
                speed: spec.speed,
                ghost: spec.ghost,
                x: .random(in: 0.15...0.85),
                y: .random(in: 0.2...0.78),
                heading: .random(in: 0...(2 * .pi)),
                bobPhase: .random(in: 0...(2 * .pi)),
                finPhase: .random(in: 0...(2 * .pi))
            )
        }
    }
    private var currentSignature = ""

    func step(time: TimeInterval) {
        guard let last = lastTime else { lastTime = time; return }
        // バックグラウンド復帰などの巨大な dt でワープしないようクランプ。
        let dt = CGFloat(min(max(time - last, 0), 1.0 / 30.0))
        lastTime = time
        guard dt > 0 else { return }

        stepFish(dt: dt)
        stepBubbles(dt: dt)
        stepFood(dt: dt)
        stepHearts(dt: dt)
    }

    private func stepFish(dt: CGFloat) {
        let margin: CGFloat = 0.06
        for index in fish.indices {
            var f = fish[index]
            f.bobPhase += dt * 2.2
            f.finPhase += dt * (f.happy > 0 ? 16 : 8)
            if f.happy > 0 { f.happy = max(0, f.happy - dt) }

            // 最寄りのエサへ向かう。なければ緩やかにさまよう。
            var speed = f.speed
            if let target = nearestFood(to: f) {
                let desired = atan2(target.y - f.y, target.x - f.x)
                f.heading = lerpAngle(f.heading, desired, dt * 4)
                speed = f.speed * 2.4
                // 口元まで来たら食べる。
                if hypot(target.x - f.x, target.y - f.y) < 0.04 {
                    food.removeAll { $0.id == target.id }
                    f.happy = 1.1
                    spawnBubbles(at: CGPoint(x: f.x, y: f.y), count: 3)
                }
            } else {
                f.heading += .random(in: -1...1) * dt * 1.4
            }

            let vx = cos(f.heading) * speed
            let vy = sin(f.heading) * speed * 0.5
            f.x += vx * dt
            f.y += vy * dt

            // 壁で反射。
            if f.x < margin { f.x = margin; f.heading = .pi - f.heading }
            if f.x > 1 - margin { f.x = 1 - margin; f.heading = .pi - f.heading }
            if f.y < 0.12 { f.y = 0.12; f.heading = -f.heading }
            if f.y > 0.86 { f.y = 0.86; f.heading = -f.heading }

            if abs(vx) > 0.0005 { f.facingRight = vx > 0 }
            fish[index] = f
        }
    }

    private func stepBubbles(dt: CGFloat) {
        bubbleTimer -= dt
        if bubbleTimer <= 0 {
            bubbleTimer = .random(in: 0.25...0.6)
            if bubbles.count < 40 {
                bubbles.append(Bubble(
                    x: .random(in: 0.08...0.92),
                    y: 0.96,
                    size: .random(in: 3...9),
                    rise: .random(in: 0.07...0.16),
                    wobblePhase: .random(in: 0...(2 * .pi))
                ))
            }
        }
        for index in bubbles.indices {
            bubbles[index].y -= bubbles[index].rise * dt
            bubbles[index].wobblePhase += dt * 3
        }
        bubbles.removeAll { $0.y < 0.04 }
    }

    private func stepFood(dt: CGFloat) {
        for index in food.indices {
            food[index].y += food[index].sink * dt
            food[index].wobblePhase += dt * 2.5
        }
        // 底に着いたら溶ける。
        food.removeAll { $0.y > 0.9 }
    }

    private func stepHearts(dt: CGFloat) {
        for index in hearts.indices {
            hearts[index].y -= dt * 0.18
            hearts[index].life -= dt
            hearts[index].x += sin(hearts[index].life * 6 + hearts[index].drift) * dt * 0.05
        }
        hearts.removeAll { $0.life <= 0 }
    }

    // MARK: 操作

    /// タップ位置に最寄りの魚がいれば喜ばせ、いなければエサを落とす。
    func tap(at p: CGPoint) -> UUID? {
        if let index = nearestFishIndex(to: p, within: 0.09) {
            fish[index].happy = 1.4
            hearts.append(Heart(x: p.x, y: p.y - 0.02, life: 1.3, drift: .random(in: 0...3)))
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
            return fish[index].id
        } else {
            guard food.count < 12 else { return nil }
            food.append(FoodPellet(x: p.x, y: max(0.06, p.y), sink: .random(in: 0.06...0.1), wobblePhase: 0))
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred()
            return nil
        }
    }

    private func spawnBubbles(at p: CGPoint, count: Int) {
        for _ in 0..<count where bubbles.count < 40 {
            bubbles.append(Bubble(
                x: p.x + .random(in: -0.02...0.02),
                y: p.y,
                size: .random(in: 2...5),
                rise: .random(in: 0.1...0.18),
                wobblePhase: .random(in: 0...(2 * .pi))
            ))
        }
    }

    private func nearestFood(to f: SwimmingFish) -> FoodPellet? {
        food.min { hypot($0.x - f.x, $0.y - f.y) < hypot($1.x - f.x, $1.y - f.y) }
    }

    private func nearestFishIndex(to p: CGPoint, within radius: CGFloat) -> Int? {
        var best: Int?
        var bestDist = radius
        for index in fish.indices {
            let d = hypot(fish[index].x - p.x, fish[index].y - p.y)
            if d < bestDist { bestDist = d; best = index }
        }
        return best
    }

    private func lerpAngle(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        var diff = b - a
        while diff > .pi { diff -= 2 * .pi }
        while diff < -.pi { diff += 2 * .pi }
        return a + diff * min(1, t)
    }
}

// MARK: - 水槽画面

struct LiveAquariumView: View {
    @Environment(AppDataStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(AppPreferences.Key.aquariumTheme.rawValue) private var aquariumTheme = AquariumTheme.dewBlue.rawValue

    @State private var engine = AquariumEngine()
    @State private var showRecords = false
    @State private var selectedFish: CollectedFish?
    @State private var canvasSize: CGSize = .zero

    private var collected: [CollectedFish] {
        store.collectedFishes.sorted { $0.recordedAt > $1.recordedAt }
    }

    private var aquarium: Aquarium? { store.aquariums.first }

    /// コレクション済みの魚（成功記録のある種）を遊泳メンバーに変換する。
    /// 1種につき最大3匹、合計18匹まで。
    private var specs: [FishSpec] {
        let succeeded = collected.filter(\.succeeded)
        var counts: [String: Int] = [:]
        var result: [FishSpec] = []

        for fish in succeeded {
            guard counts[fish.speciesId, default: 0] < 3,
                  let species = FishSpecies(rawValue: fish.speciesId) else {
                continue
            }
            counts[fish.speciesId, default: 0] += 1
            result.append(spec(for: fish, species: species, ghost: false))
            if result.count >= 18 { break }
        }

        return result
    }

    private func spec(for fish: CollectedFish, species: FishSpecies, ghost: Bool) -> FishSpec {
        let ratio = species.requiredWaterRatio
        return FishSpec(
            id: fish.id,
            name: fish.name,
            species: species,
            size: 30 + ratio * 46,          // 小型魚ほど小さく、大型魚ほど大きく
            speed: 0.13 - ratio * 0.07,     // 小型魚ほど速く泳ぐ
            ghost: ghost
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                aquariumScene
                if activeFishCount == 0 {
                    emptyAquariumHint
                }
                topBar
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showRecords) {
            AquariumView()
        }
        .sheet(item: $selectedFish) { fish in
            FishDetailSheet(fish: fish)
                .presentationDetents([.medium])
                .presentationBackground(.clear)
                .presentationDragIndicator(.hidden)
        }
        .onAppear { engine.populate(specs) }
        .onChange(of: collected.map { "\($0.id.uuidString):\($0.name):\($0.succeeded)" }) { _, _ in
            engine.populate(specs)
        }
    }

    // MARK: シーン

    private var aquariumScene: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            Canvas { context, size in
                canvasSize = size
                engine.step(time: timeline.date.timeIntervalSinceReferenceDate)

                drawWater(context: context, size: size)
                drawLightRays(context: context, size: size, time: timeline.date.timeIntervalSinceReferenceDate)
                drawSeaweed(context: context, size: size, time: timeline.date.timeIntervalSinceReferenceDate)
                drawSand(context: context, size: size)
                drawFood(context: context, size: size)
                drawBubbles(context: context, size: size)
                drawFish(context: context, size: size)
                drawHearts(context: context, size: size)
            }
            .ignoresSafeArea()
        }
        .contentShape(Rectangle())
        .onTapGesture(coordinateSpace: .local) { location in
            guard canvasSize.width > 0 else { return }
            if let fishId = engine.tap(at: CGPoint(x: location.x / canvasSize.width, y: location.y / canvasSize.height)),
               let fish = collected.first(where: { $0.id == fishId }) {
                selectedFish = fish
            }
        }
    }

    // MARK: 描画ヘルパー

    private func drawWater(context: GraphicsContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)
        let theme = AquariumTheme(rawValue: aquariumTheme) ?? .dewBlue
        let colors = theme.liveAquariumColors(isDark: colorScheme == .dark)
        let gradient = Gradient(colors: colors)
        context.fill(
            Path(rect),
            with: .linearGradient(gradient, startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height))
        )
    }

    private func drawLightRays(context: GraphicsContext, size: CGSize, time: TimeInterval) {
        var ctx = context
        ctx.blendMode = .softLight
        let theme = AquariumTheme(rawValue: aquariumTheme) ?? .dewBlue
        let rayColor = theme.liveAquariumLightRayColor(isDark: colorScheme == .dark)
        for index in 0..<4 {
            let phase = sin(time * 0.3 + Double(index)) * 0.04
            let topX = size.width * (0.15 + Double(index) * 0.22 + phase)
            let path = Path { p in
                p.move(to: CGPoint(x: topX, y: 0))
                p.addLine(to: CGPoint(x: topX + size.width * 0.08, y: 0))
                p.addLine(to: CGPoint(x: topX + size.width * 0.22, y: size.height))
                p.addLine(to: CGPoint(x: topX + size.width * 0.06, y: size.height))
                p.closeSubpath()
            }
            ctx.fill(path, with: .color(rayColor))
        }
    }

    private func drawSeaweed(context: GraphicsContext, size: CGSize, time: TimeInterval) {
        let theme = AquariumTheme(rawValue: aquariumTheme) ?? .dewBlue
        let hues = theme.liveAquariumSeaweedColors(isDark: colorScheme == .dark)
        let blades: [(x: CGFloat, height: CGFloat, hue: Color)] = [
            (0.12, 0.32, hues[0]),
            (0.18, 0.22, hues[1]),
            (0.80, 0.30, hues[2]),
            (0.88, 0.20, hues[3]),
            (0.50, 0.16, hues[4])
        ]
        for (i, blade) in blades.enumerated() {
            let baseX = blade.x * size.width
            let baseY = size.height * 0.95
            let topY = baseY - blade.height * size.height
            let sway = sin(time * 1.2 + Double(i)) * (size.width * 0.03)
            let path = Path { p in
                p.move(to: CGPoint(x: baseX, y: baseY))
                p.addQuadCurve(
                    to: CGPoint(x: baseX + sway, y: topY),
                    control: CGPoint(x: baseX + sway * 0.5, y: (baseY + topY) / 2)
                )
            }
            context.stroke(
                path,
                with: .color(blade.hue.opacity(0.85)),
                style: StrokeStyle(lineWidth: 9, lineCap: .round)
            )
        }
    }

    private func drawSand(context: GraphicsContext, size: CGSize) {
        let sandTop = size.height * 0.9
        let path = Path { p in
            p.move(to: CGPoint(x: 0, y: size.height))
            p.addLine(to: CGPoint(x: 0, y: sandTop + 14))
            p.addQuadCurve(
                to: CGPoint(x: size.width, y: sandTop + 14),
                control: CGPoint(x: size.width * 0.5, y: sandTop - 12)
            )
            p.addLine(to: CGPoint(x: size.width, y: size.height))
            p.closeSubpath()
        }
        let theme = AquariumTheme(rawValue: aquariumTheme) ?? .dewBlue
        let colors = theme.liveAquariumSandColors(isDark: colorScheme == .dark)
        context.fill(
            path,
            with: .linearGradient(
                Gradient(colors: colors),
                startPoint: CGPoint(x: 0, y: sandTop),
                endPoint: CGPoint(x: 0, y: size.height)
            )
        )
    }

    private func drawFood(context: GraphicsContext, size: CGSize) {
        for pellet in engine.food {
            let x = pellet.x * size.width + sin(pellet.wobblePhase) * 3
            let y = pellet.y * size.height
            let r: CGFloat = 4
            context.fill(
                Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                with: .color(Color(red: 0.85, green: 0.55, blue: 0.25))
            )
        }
    }

    private func drawBubbles(context: GraphicsContext, size: CGSize) {
        for bubble in engine.bubbles {
            let x = bubble.x * size.width + sin(bubble.wobblePhase) * 4
            let y = bubble.y * size.height
            let r = bubble.size
            let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
            context.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(0.45)), lineWidth: 1)
            context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.12)))
        }
    }

    private func drawFish(context: GraphicsContext, size: CGSize) {
        for f in engine.fish {
            let bob = sin(f.bobPhase) * (f.size * 0.06)
            let x = f.x * size.width
            let y = f.y * size.height + bob
            let wiggle = sin(f.finPhase) * (f.happy > 0 ? 12 : 6)
            let pop: CGFloat = f.happy > 0 ? 1.0 + sin(f.finPhase) * 0.06 : 1.0

            var ctx = context
            ctx.translateBy(x: x, y: y)
            ctx.rotate(by: .degrees(Double(wiggle)))
            ctx.scaleBy(x: f.facingRight ? pop : -pop, y: pop)
            ctx.opacity = f.ghost ? 0.4 : 1.0
            FishArtworkRenderer.draw(
                f.species,
                in: CGRect(x: -f.size / 2, y: -f.size / 2, width: f.size, height: f.size),
                context: &ctx
            )

            if f.happy > 0, !f.ghost {
                let labelOpacity = min(1, f.happy)
                let labelWidth = min(max(CGFloat(f.name.count) * 9 + 18, 44), 120)
                let labelRect = CGRect(
                    x: min(max(x - labelWidth / 2, 10), size.width - labelWidth - 10),
                    y: max(y - f.size * 0.85 - 26, 60),
                    width: labelWidth,
                    height: 24
                )
                context.fill(
                    Path(roundedRect: labelRect, cornerRadius: 12),
                    with: .color(.black.opacity(0.34 * labelOpacity))
                )
                context.draw(
                    Text(f.name)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white),
                    at: CGPoint(x: labelRect.midX, y: labelRect.midY),
                    anchor: .center
                )
            }
        }
    }

    private func drawHearts(context: GraphicsContext, size: CGSize) {
        for heart in engine.hearts {
            var ctx = context
            ctx.opacity = min(1, heart.life)
            ctx.draw(
                Text("💕").font(.system(size: 20)),
                at: CGPoint(x: heart.x * size.width, y: heart.y * size.height),
                anchor: .center
            )
        }
    }

    // MARK: トップバー

    private var topBar: some View {
        VStack {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(aquarium?.sizeName ?? "ミニ水槽")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                    Text("\(activeFishCount)匹が泳いでいます")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                        .monospacedDigit()
                }
                .shadow(color: .black.opacity(0.25), radius: 3, y: 1)

                Spacer()

                Button {
                    showRecords = true
                } label: {
                    Image(systemName: "calendar")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(.white.opacity(0.22), in: Circle())
                        .overlay(Circle().strokeBorder(.white.opacity(0.4), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Spacer()

            Label("水面をタップでエサ・魚をタップで名前編集", systemImage: "hand.tap.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.black.opacity(0.22), in: Capsule())
                .padding(.bottom, 14)
        }
    }

    private var emptyAquariumHint: some View {
        VStack(spacing: 8) {
            Image(systemName: "fish")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
            Text("まだ魚はいません")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
            Text("成魚になった魚がここで泳ぎます")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.78))
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.22), lineWidth: 1)
        }
    }

    private var activeFishCount: Int {
        let succeeded = collected.filter(\.succeeded).count
        return min(succeeded, 18)
    }
}

#Preview {
    LiveAquariumView()
        .environment(AppDataStore())
}
