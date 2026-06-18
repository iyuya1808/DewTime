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
            Text(L10n.Common.close)
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
            .accessibilityLabel(L10n.Common.close)
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

                Text(L10n.Aquarium.Guide.levelTitle(aquarium.sizeTier + 1))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                VStack(spacing: 4) {
                    Text(aquarium.sizeName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.92))
                    Text(L10n.Aquarium.Guide.swimmingCount(swimmingCount, aquarium.fishCapacity))
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

                Text(L10n.Aquarium.Guide.feedAbout)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                Text(L10n.Aquarium.Guide.feedOwned(aquarium.bonusFeedStock))
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
            sectionTitle(L10n.Aquarium.Guide.growthStage)
            AquariumGrowthStageView(aquarium: aquarium)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var benefitsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(kind == .level ? L10n.Aquarium.Guide.levelBenefits : L10n.Aquarium.Guide.feedBenefits)

            switch kind {
            case .level:
                benefitRow(
                    icon: "fish.fill",
                    tint: .white,
                    title: L10n.Aquarium.Guide.benefitMoreFish,
                    detail: levelCapacityDetail
                )
                benefitRow(
                    icon: "sparkles",
                    tint: .yellow,
                    title: L10n.Aquarium.Guide.benefitMoreSpecies,
                    detail: levelSpeciesDetail
                )
            case .feed:
                benefitRow(
                    icon: "hand.tap.fill",
                    tint: .cyan,
                    title: L10n.Aquarium.Guide.feedTap,
                    detail: L10n.Aquarium.Guide.feedTapDetail
                )
                benefitRow(
                    icon: "fish.fill",
                    tint: .white,
                    title: L10n.Aquarium.Guide.feedNewFish,
                    detail: L10n.Aquarium.Guide.feedNewFishDetail
                )
                benefitRow(
                    icon: "book.fill",
                    tint: .purple,
                    title: L10n.Aquarium.Guide.feedDex,
                    detail: L10n.Aquarium.Guide.feedDexDetail
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var howToCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(kind == .level ? L10n.Aquarium.Guide.levelHow : L10n.Aquarium.Guide.feedHow)

            switch kind {
            case .level:
                benefitRow(
                    icon: "drop.fill",
                    tint: .cyan,
                    title: L10n.Aquarium.Guide.levelHowDepart,
                    detail: L10n.Aquarium.Guide.levelHowDepartDetail
                )
            case .feed:
                benefitRow(
                    icon: "clock.badge.checkmark.fill",
                    tint: .cyan,
                    title: L10n.Aquarium.Guide.feedHowOnTime,
                    detail: L10n.Aquarium.Guide.feedHowOnTimeDetail
                )
                benefitRow(
                    icon: "trophy.fill",
                    tint: .orange,
                    title: L10n.Aquarium.Guide.feedHowAchievement,
                    detail: L10n.Aquarium.Guide.feedHowAchievementDetail
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
            return L10n.Aquarium.Guide.levelCapacityMax(aquarium.fishCapacity)
        }
        let nextCapacity = Aquarium.fishCapacity(for: aquarium.sizeTier + 1)
        return L10n.Aquarium.Guide.levelCapacityNext(next: nextCapacity, current: aquarium.fishCapacity)
    }

    private var levelSpeciesDetail: String {
        if let nextCount = nextTierEligibleSpeciesCount, nextCount > eligibleSpeciesCount {
            return L10n.Aquarium.Guide.levelSpeciesMore(from: eligibleSpeciesCount, to: nextCount)
        }
        return L10n.Aquarium.Guide.levelSpeciesCurrent(eligibleSpeciesCount)
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
