import SwiftUI

enum AquariumStatusGuideKind: Identifiable {
    case level
    case feed

    var id: Self { self }
}

/// 水槽ステータス（レベル・餌）タップ時に表示する説明シート。
struct AquariumStatusGuideSheet: View {
    let kind: AquariumStatusGuideKind
    let aquarium: Aquarium
    let swimmingCount: Int
    let onDismiss: () -> Void

    private var eligibleSpeciesCount: Int {
        FishGachaService.eligibleSpecies(tier: aquarium.sizeTier).count
    }

    private var nextTierEligibleSpeciesCount: Int? {
        guard !aquarium.isMaxTier else { return nil }
        return FishGachaService.eligibleSpecies(tier: aquarium.sizeTier + 1).count
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    heroHeader

                    if kind == .level {
                        growthStageCard
                    }

                    benefitsCard
                    howToCard
                    closeButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 28)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            LinearGradient.dewTimeSheet
                .ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
        .presentationDetents(kind == .level ? [.fraction(0.94)] : [.medium])
        .presentationContentInteraction(kind == .level ? .scrolls : .automatic)
        .presentationDragIndicator(.visible)
    }

    // MARK: - Sections

    private var closeButton: some View {
        Button(action: onDismiss) {
            Text("閉じる")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.teal, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    private var topBar: some View {
        HStack {
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("閉じる")
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    private var heroHeader: some View {
        VStack(spacing: 10) {
            switch kind {
            case .level:
                ZStack {
                    Circle()
                        .fill(Color.cyan.opacity(0.14))
                        .frame(width: 56, height: 56)
                    Image(systemName: aquarium.isMaxTier ? "sparkles" : "drop.fill")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(aquarium.isMaxTier ? .yellow : .cyan)
                }

                Text("水槽レベル \(aquarium.sizeTier + 1)")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                VStack(spacing: 4) {
                    Text(aquarium.sizeName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.92))
                    Text("泳がせられる魚 \(swimmingCount)/\(aquarium.fishCapacity)匹")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.82))
                }
            case .feed:
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.16))
                        .frame(width: 56, height: 56)
                    FeedPelletGlyph(size: 22)
                }

                Text("餌について")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                Text("所持 \(aquarium.bonusFeedStock)個")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))
            }
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .padding(.vertical, 4)
    }

    private var growthStageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("成長ステージ")
            AquariumGrowthStageView(aquarium: aquarium)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var benefitsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(kind == .level ? "レベルを上げると" : "餌をあげると")

            switch kind {
            case .level:
                benefitRow(
                    icon: "fish.fill",
                    tint: .white,
                    title: "泳がせられる魚が増える",
                    detail: levelCapacityDetail
                )
                benefitRow(
                    icon: "sparkles",
                    tint: .yellow,
                    title: "出会える魚種が増える",
                    detail: levelSpeciesDetail
                )
            case .feed:
                benefitRow(
                    icon: "hand.tap.fill",
                    tint: .cyan,
                    title: "画面をタップして餌を落とせる",
                    detail: "水槽の好きな場所をタップすると、餌が落ちて魚が集まります。"
                )
                benefitRow(
                    icon: "fish.fill",
                    tint: .white,
                    title: "新しい魚が仲間入りする",
                    detail: "魚が餌を食べたタイミングで、ランダムな魚種が1匹加わります。"
                )
                benefitRow(
                    icon: "book.fill",
                    tint: .purple,
                    title: "図鑑に魚種が記録される",
                    detail: "はじめて出会った魚種は図鑑に登録され、コレクションが広がります。"
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var howToCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(kind == .level ? "レベルの上げ方" : "餌の入手方法")

            switch kind {
            case .level:
                benefitRow(
                    icon: "drop.fill",
                    tint: .cyan,
                    title: "オンタイム出発を重ねる",
                    detail: "出発時刻ぴったりに出発するとしずくが貯まり、水槽が成長します。"
                )
            case .feed:
                benefitRow(
                    icon: "clock.badge.checkmark.fill",
                    tint: .cyan,
                    title: "オンタイム出発で +1",
                    detail: "タイマーで出発時刻ぴったりに出発すると、餌を1個獲得できます。"
                )
                benefitRow(
                    icon: "trophy.fill",
                    tint: .orange,
                    title: "実績解除で獲得",
                    detail: "プロフィールの実績を達成すると、餌がもらえることがあります。"
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    // MARK: - Helpers

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.white.opacity(0.14))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
            )
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.headline.weight(.bold))
            .foregroundStyle(.white)
    }

    private func benefitRow(icon: String, tint: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var levelCapacityDetail: String {
        if aquarium.isMaxTier {
            return "現在の上限は\(aquarium.fishCapacity)匹。これ以上は増えません。"
        }
        let nextCapacity = Aquarium.fishCapacity(for: aquarium.sizeTier + 1)
        return "次のレベルでは\(nextCapacity)匹まで泳がせられます（現在\(aquarium.fishCapacity)匹）。"
    }

    private var levelSpeciesDetail: String {
        if let nextCount = nextTierEligibleSpeciesCount, nextCount > eligibleSpeciesCount {
            return "餌やりで出る魚種が\(eligibleSpeciesCount)種から\(nextCount)種に増え、レアな魚にも出会えます。"
        }
        return "餌やりで\(eligibleSpeciesCount)種類の魚が出るようになっています。"
    }
}

#Preview("Level") {
    AquariumStatusGuideSheet(
        kind: .level,
        aquarium: Aquarium(totalDepartures: 12),
        swimmingCount: 8,
        onDismiss: {}
    )
}

#Preview("Feed") {
    AquariumStatusGuideSheet(
        kind: .feed,
        aquarium: Aquarium(bonusFeedStock: 3),
        swimmingCount: 5,
        onDismiss: {}
    )
}
