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
    var onFoodEaten: (() -> Void)?

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
    }

    private func stepFish(dt: CGFloat) {
        let margin: CGFloat = 0.06
        for index in fish.indices {
            var f = fish[index]
            f.bobPhase += dt * 2.2
            f.finPhase += dt * 8

            // 最寄りのエサへ向かう。なければ緩やかにさまよう。
            var speed = f.speed
            if let target = nearestFood(to: f) {
                let desired = atan2(target.y - f.y, target.x - f.x)
                f.heading = lerpAngle(f.heading, desired, dt * 4)
                speed = f.speed * 2.4
                // 口元まで来たら食べる。
                if hypot(target.x - f.x, target.y - f.y) < 0.04 {
                    food.removeAll { $0.id == target.id }
                    onFoodEaten?()
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

    /// タップ位置付近の魚 ID。詳細表示用。
    func fishId(at p: CGPoint, within radius: CGFloat = 0.09) -> UUID? {
        guard let index = nearestFishIndex(to: p, within: radius) else { return nil }
        return fish[index].id
    }

    /// タップ位置にエサを落とす。
    @discardableResult
    func dropFood(at p: CGPoint) -> Bool {
        guard food.count < 10 else { return false }
        food.append(
            FoodPellet(
                x: p.x,
                y: max(0.06, p.y),
                sink: .random(in: 0.06...0.1),
                wobblePhase: 0
            )
        )
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
        return true
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
    @Environment(\.appTabSelection) private var appTabSelection
    @AppStorage(AppPreferences.Key.aquariumTheme.rawValue) private var aquariumTheme = AquariumTheme.dewBlue.rawValue

    @State private var engine = AquariumEngine()
    @State private var showRecords = false
    @State private var statusGuide: AquariumStatusGuideKind?
    @State private var selectedFish: CollectedFish?
    @State private var canvasSize: CGSize = .zero
    @State private var gachaReveal: FishGachaReveal?
    @State private var lastFeedTapAt: Date = .distantPast
    @State private var showsCapacityFullNotice = false
    @State private var capacityFullNoticeTask: Task<Void, Never>?

    private var isAtFishCapacity: Bool {
        swimmingFishCount >= fishCapacity
    }

    private var aquariumFish: [CollectedFish] {
        store.aquariumFish()
    }

    private var aquarium: Aquarium { store.aquarium() }

    private var fishCapacity: Int {
        aquarium.fishCapacity
    }

    private var specs: [FishSpec] {
        aquariumFish.compactMap { fish in
            guard let species = FishSpecies(rawValue: fish.speciesId) else { return nil }
            return spec(for: fish, species: species, ghost: false)
        }
    }

    private var showsEmptyAquariumHint: Bool {
        aquariumFish.isEmpty
    }

    private var swimmingFishCount: Int {
        aquariumFish.count
    }

    private var aquariumSignature: String {
        "\(aquarium.totalDepartures)-\(aquarium.sizeTier)-\(fishCapacity)-\(aquarium.bonusFeedStock)-\(store.collectedFishes.map(\.id.uuidString).joined())"
    }

    private func spec(for fish: CollectedFish, species: FishSpecies, ghost: Bool) -> FishSpec {
        FishSpec(
            id: fish.id,
            name: fish.name,
            species: species,
            size: species.displaySize(for: .aquarium),
            speed: species.aquariumSwimSpeed,
            ghost: ghost
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                aquariumScene
                if showsEmptyAquariumHint {
                    emptyAquariumHint
                }
                topBar

                if showsCapacityFullNotice {
                    capacityFullNotice
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeOut(duration: 0.25), value: showsCapacityFullNotice)
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showRecords) {
            NavigationStack {
                MonthlyAquariumView()
            }
            .dewAppBackground()
        }
        .sheet(item: $statusGuide) { guide in
            AquariumStatusGuideSheet(
                kind: guide,
                aquarium: aquarium,
                swimmingCount: swimmingFishCount,
                onDismiss: { statusGuide = nil }
            )
        }
        .sheet(item: $selectedFish) { fish in
            FishDetailSheet(fish: fish)
                .presentationDetents([.medium])
                .presentationBackground(.clear)
                .presentationDragIndicator(.hidden)
        }
        .sheet(item: $gachaReveal) { reveal in
            FishGachaResultSheet(reveal: reveal) {
                gachaReveal = nil
            }
            .presentationDetents([.height(420)])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            engine.onFoodEaten = {
                Task { await handleFoodEaten() }
            }
            engine.populate(specs)
        }
        .onChange(of: aquariumSignature) { _, _ in
            engine.populate(specs)
        }
        .onDisappear {
            capacityFullNoticeTask?.cancel()
        }
    }

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
            }
            .ignoresSafeArea()
        }
        .contentShape(Rectangle())
        .onTapGesture(coordinateSpace: .local) { location in
            guard canvasSize.width > 0 else { return }
            let point = CGPoint(x: location.x / canvasSize.width, y: location.y / canvasSize.height)

            if let fishId = engine.fishId(at: point),
               let fish = aquariumFish.first(where: { $0.id == fishId }) {
                selectedFish = fish
                return
            }

            guard aquarium.bonusFeedStock > 0 else { return }

            let now = Date.now
            if isAtFishCapacity, now.timeIntervalSince(lastFeedTapAt) < 1.5 { return }
            lastFeedTapAt = now

            guard store.consumeBonusFeedIfAvailable() else { return }
            Task { await store.saveAll() }
            _ = engine.dropFood(at: point)
        }
    }

    // MARK: トップバー

    private var topBar: some View {
        VStack {
            HStack(alignment: .top, spacing: 10) {
                aquariumStatusBar

                Spacer(minLength: 0)

                Button {
                    showRecords = true
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "calendar")
                            .font(.system(size: 17, weight: .semibold))
                        Text("出発")
                            .font(.system(size: 9, weight: .semibold))
                        Text("記録")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(.white.opacity(0.22), lineWidth: 1)
                    )
                }
                .buttonStyle(AquariumStatusButtonStyle())
                .accessibilityLabel("出発記録")
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer()
        }
    }

    private var aquariumStatusBar: some View {
        HStack(spacing: 0) {
            statusSegment(
                title: "レベル",
                value: "\(aquarium.sizeTier + 1)",
                accent: .cyan,
                isHighlighted: aquarium.isMaxTier,
                accessibilityLabel: "水槽レベル\(aquarium.sizeTier + 1)。タップで説明を表示"
            ) {
                levelSegmentIcon
            } action: {
                statusGuide = .level
            }

            statusDivider

            statusSegment(
                title: "魚",
                value: "\(swimmingFishCount)/\(fishCapacity)",
                accent: swimmingFishCount >= fishCapacity ? .orange : .white,
                isHighlighted: swimmingFishCount >= fishCapacity,
                accessibilityLabel: "\(swimmingFishCount)匹が泳いでいます。タップで図鑑へ"
            ) {
                Image(systemName: "fish.fill")
                    .font(.system(size: 15, weight: .bold))
            } action: {
                appTabSelection?.wrappedValue = .collection
            }

            statusDivider

            statusSegment(
                title: "餌",
                value: "\(aquarium.bonusFeedStock)",
                accent: .orange,
                isHighlighted: aquarium.bonusFeedStock > 0,
                accessibilityLabel: "餌\(aquarium.bonusFeedStock)個。タップで説明を表示"
            ) {
                FeedPelletGlyph(size: 13)
            } action: {
                statusGuide = .feed
            }
        }
        .padding(4)
        .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
    }

    private var levelSegmentIcon: some View {
        ZStack {
            let bowl = 12 + CGFloat(aquarium.sizeTier) * 1.5
            Circle()
                .strokeBorder(.teal.opacity(0.85), lineWidth: 1.5)
                .frame(width: bowl, height: bowl)
            Image(systemName: aquarium.isMaxTier ? "sparkles" : "drop.fill")
                .font(.system(size: aquarium.isMaxTier ? 8 : 7, weight: .bold))
                .foregroundStyle(aquarium.isMaxTier ? .yellow : .cyan)
        }
        .frame(width: 22, height: 16)
    }

    private var statusDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.16))
            .frame(width: 1, height: 40)
            .padding(.vertical, 2)
    }

    private func statusSegment<Icon: View>(
        title: String,
        value: String,
        accent: Color,
        isHighlighted: Bool,
        accessibilityLabel: String,
        @ViewBuilder icon: () -> Icon,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)

                HStack(spacing: 5) {
                    icon()
                        .foregroundStyle(accent.opacity(isHighlighted ? 1 : 0.85))

                    Text(value)
                        .font(.system(size: 15, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(minWidth: 60)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(AquariumStatusButtonStyle())
        .accessibilityLabel(accessibilityLabel)
    }

    private var emptyAquariumHint: some View {
        VStack(spacing: 10) {
            if aquarium.bonusFeedStock > 0 {
                FeedPelletGlyph(size: 28)
                Text("餌")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Text("タップして餌をあげる")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
            } else {
                Image(systemName: "fish")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                Text("餌")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Text("オンタイム出発か実績解除で獲得できます")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
        .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.22), lineWidth: 1)
        }
        .accessibilityLabel(
            aquarium.bonusFeedStock > 0
                ? "タップして餌をあげると魚が増えます"
                : "餌がありません。オンタイム出発か実績解除で獲得できます"
        )
    }

    private func handleFoodEaten() async {
        guard let fish = await store.spawnFishFromFeed() else {
            if isAtFishCapacity {
                showCapacityFullFeedback()
            }
            return
        }
        guard let species = FishSpecies(rawValue: fish.speciesId) else { return }
        if AppPreferences.hapticsEnabled {
            ScheduleHaptics.playPhaseKnock()
        }
        let isNewSpecies = store.collectedFishes.filter { $0.speciesId == species.rawValue }.count == 1
        gachaReveal = FishGachaReveal(
            id: fish.id,
            fish: fish,
            isNewSpecies: isNewSpecies
        )
    }

    private var capacityFullNotice: some View {
        VStack {
            Spacer()
            VStack(spacing: 5) {
                HStack(spacing: 8) {
                    Image(systemName: "fish.fill")
                        .font(.subheadline.weight(.bold))
                    Text("水槽がいっぱいです")
                        .font(.subheadline.weight(.semibold))
                }
                Text(capacityFullHint)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.88))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.orange.opacity(0.55), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("水槽がいっぱいです。\(capacityFullHint)")
        }
        .allowsHitTesting(false)
    }

    private var capacityFullHint: String {
        if aquarium.isMaxTier {
            return "これ以上泳がせることはできません"
        }
        if let remaining = aquarium.departuresUntilNextTier, remaining > 0 {
            return "あと\(remaining)しずくで収容上限が増えます"
        }
        return "オンタイム出発で水槽を大きくしよう"
    }

    private func showCapacityFullFeedback() {
        showsCapacityFullNotice = true
        if AppPreferences.hapticsEnabled {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }

        capacityFullNoticeTask?.cancel()
        capacityFullNoticeTask = Task {
            try? await Task.sleep(for: .seconds(2.8))
            guard !Task.isCancelled else { return }
            showsCapacityFullNotice = false
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
            let wiggle = sin(f.finPhase) * 6

            var ctx = context
            ctx.translateBy(x: x, y: y)
            ctx.rotate(by: .degrees(Double(wiggle)))
            ctx.scaleBy(x: f.facingRight ? 1 : -1, y: 1)
            ctx.opacity = f.ghost ? 0.4 : 1.0
            FishArtworkRenderer.draw(
                f.species,
                in: CGRect(x: -f.size / 2, y: -f.size / 2, width: f.size, height: f.size),
                context: &ctx
            )
        }
    }
}

// MARK: - ステータスバー部品

private struct AquariumStatusButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview {
    LiveAquariumView()
        .environment(AppDataStore())
}
