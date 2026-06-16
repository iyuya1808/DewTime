import SwiftUI

// MARK: - StartSheet
// 出発時刻は「水位を上下にスワイプして設定」するインタラクティブUI。
// テキストラベルを排除し、数字とアイコンのみで操作できる。

struct StartSheet: View {

    // MARK: - Props
    let scheduleName: String
    let currentTime: Date
    let aquariumTier: Int
    let onSelectSpecies: (FishSpecies) -> Void
    let onStart: (Date) -> Void
    let onCancel: () -> Void

    // MARK: - State
    @State private var draftLevel: Double = 0.5    // 0.0-1.0 → 0-maxMinutes
    @State private var selectedSpecies: FishSpecies
    @State private var appear = false

    // MARK: - Constants
    private static let maxMinutes = 60
    private let presets = [15, 30, 45, 60]

    // MARK: - Init
    init(
        scheduleName: String,
        currentTime: Date,
        selectedSpecies: FishSpecies,
        aquariumTier: Int,
        onSelectSpecies: @escaping (FishSpecies) -> Void,
        onStart: @escaping (Date) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.scheduleName = scheduleName
        self.currentTime = currentTime
        self.aquariumTier = aquariumTier
        self.onSelectSpecies = onSelectSpecies
        self.onStart = onStart
        self.onCancel = onCancel
        _selectedSpecies = State(initialValue: selectedSpecies)

        // 既存の出発時刻を「今から何分後か」に変換してドラフト水位へ反映
        let minutesFromNow = Int(currentTime.timeIntervalSince(.now) / 60)
        let clamped = max(5, min(Self.maxMinutes, minutesFromNow))
        _draftLevel = State(initialValue: Double(clamped) / Double(Self.maxMinutes))
    }

    // MARK: - Derived
    private var draftMinutes: Int {
        max(5, Int((draftLevel * Double(Self.maxMinutes)).rounded()))
    }

    private var departureDate: Date {
        Date.now.addingTimeInterval(TimeInterval(draftMinutes * 60))
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            LinearGradient.dewTimeSheet
                .ignoresSafeArea()

            auroraLayer
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                dragHandle

                // 大きな残り時間数字（分）
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(draftMinutes)")
                        .font(.system(size: 80, weight: .ultraLight, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: draftMinutes)
                    Text("min")
                        .font(.system(size: 20, weight: .thin, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.bottom, 8)
                }
                .opacity(appear ? 1 : 0)
                .padding(.top, 4)

                // 水槽（ドラッグで水位設定）+ プリセット
                HStack(alignment: .center, spacing: 16) {
                    WaterTankView(
                        waterLevel: draftLevel,
                        isDraggable: true,
                        onLevelChanged: { level in
                            withAnimation(.interactiveSpring(response: 0.2)) {
                                draftLevel = level
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    )
                    .frame(maxWidth: .infinity)

                    // プリセット縦ボタン（数字のみ）
                    VStack(spacing: 12) {
                        ForEach(presets.reversed(), id: \.self) { min in
                            presetButton(minutes: min)
                        }
                    }
                    .frame(width: 50)
                }
                .frame(height: 240)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .opacity(appear ? 1 : 0)

                // 魚選択（横スクロール）
                fishScrollSection
                    .padding(.top, 16)
                    .opacity(appear ? 1 : 0)

                // アクションボタン（再生 + ✕）
                HStack(spacing: 40) {
                    Button { onCancel() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("キャンセル")

                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onStart(departureDate)
                    } label: {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(Color.dewBlue)
                            .shadow(color: Color.dewBlue.opacity(0.55), radius: 14, y: 4)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("スタート")

                    Color.clear.frame(width: 48, height: 48)
                }
                .padding(.top, 20)
                .padding(.bottom, 24)
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 20)
            }
            .safeAreaPadding(.bottom, 12)
        }
        .foregroundStyle(.white)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                appear = true
            }
        }
    }

    // MARK: - Preset Button
    private func presetButton(minutes: Int) -> some View {
        let isSelected = draftMinutes == minutes
        let ratio = Double(minutes) / Double(Self.maxMinutes)
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                draftLevel = ratio
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            VStack(spacing: 3) {
                // 水位ミニビジュアル
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.white.opacity(0.10))
                        .frame(width: 30, height: 36)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.dewBlue : .white.opacity(0.3))
                        .frame(width: 30, height: max(4, 36 * ratio))
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(isSelected ? Color.dewBlue : .white.opacity(0.15), lineWidth: 1)
                )

                Text("\(minutes)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? Color.dewBlue : .white.opacity(0.55))
                    .monospacedDigit()
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.08 : 1.0)
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isSelected)
        .accessibilityLabel("\(minutes)分")
    }

    // MARK: - Fish Scroll
    private var fishScrollSection: some View {
        let unlocked = FishSpecies.allCases
            .sorted { $0.requiredWaterRatio < $1.requiredWaterRatio }
            .filter { $0.isUnlocked(aquariumTier: aquariumTier) }

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(unlocked) { species in
                    fishIcon(species)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func fishIcon(_ species: FishSpecies) -> some View {
        let isSelected = selectedSpecies == species
        return Button {
            withAnimation(.spring(response: 0.3)) {
                selectedSpecies = species
            }
            onSelectSpecies(species)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            ZStack {
                Circle()
                    .fill(isSelected ? Color.dewBlue.opacity(0.28) : .white.opacity(0.08))
                    .frame(width: 56, height: 56)
                if isSelected {
                    Circle()
                        .strokeBorder(Color.dewBlue, lineWidth: 2)
                        .frame(width: 56, height: 56)
                }
                FishArtworkView(species: species)
                    .frame(width: 38, height: 34)
            }
            .scaleEffect(isSelected ? 1.08 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.28), value: isSelected)
        .accessibilityLabel(species.displayName)
    }

    // MARK: - Aurora Layer
    private var auroraLayer: some View {
        ZStack {
            Circle()
                .fill(Color.dewBlue.opacity(0.14))
                .frame(width: 340, height: 340)
                .blur(radius: 72)
                .offset(x: 90, y: -160)
            Circle()
                .fill(Color(red: 0.48, green: 0.40, blue: 1.0).opacity(0.10))
                .frame(width: 280, height: 280)
                .blur(radius: 60)
                .offset(x: -100, y: -90)
            Circle()
                .fill(Color(red: 0.10, green: 0.60, blue: 1.0).opacity(0.07))
                .frame(width: 200, height: 200)
                .blur(radius: 50)
                .offset(x: -30, y: 200)
        }
    }

    // MARK: - Drag Handle
    private var dragHandle: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [Color.dewBlue.opacity(0.5), .white.opacity(0.22)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: 38, height: 4)
            .padding(.top, 14)
            .padding(.bottom, 8)
    }
}

// MARK: - Preview

#Preview {
    StartSheet(
        scheduleName: "通勤",
        currentTime: Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: .now)!,
        selectedSpecies: .medaka,
        aquariumTier: 0,
        onSelectSpecies: { _ in },
        onStart: { _ in },
        onCancel: {}
    )
}
