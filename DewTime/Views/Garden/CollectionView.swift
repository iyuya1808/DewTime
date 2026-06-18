import SwiftUI
import StoreKit

private extension FishDifficulty {
    var lockedAccentColor: Color {
        switch self {
        case .veryEasy: return Color(hex: "#48C774")
        case .easy: return Color(hex: "#2EC4B6")
        case .normal: return Color(hex: "#3FA7FF")
        case .hard: return Color(hex: "#8B80F9")
        case .veryHard: return Color(hex: "#F06595")
        }
    }
}

private struct SpeciesGrowthSnapshot {
    let species: FishSpecies
    let unlockedRecordCount: Int
    let bestUnlockedRatio: Double

    var isUnlocked: Bool {
        unlockedRecordCount > 0
    }

    var accentColor: Color {
        if isUnlocked {
            return WaterLevelTheme(waterRatio: bestUnlockedRatio).tintColor
        }
        return species.difficulty.lockedAccentColor
    }

    var helperText: String {
        if isUnlocked {
            return L10n.Collection.fishAcquired(unlockedRecordCount)
        }
        return L10n.Collection.aquariumLevelMin(species.requiredAquariumTier + 1)
    }

    var statusTitle: String {
        if isUnlocked { return L10n.Collection.fishCount(unlockedRecordCount) }
        return L10n.Collection.undiscovered
    }

    var statusIcon: String {
        if isUnlocked { return "checkmark.seal.fill" }
        return "lock.fill"
    }
}

struct CollectionView: View {
    @Environment(AppDataStore.self) private var store
    @Environment(\.requestReview) private var requestReview

    @State private var selectedSpecies: FishSpecies?
    @State private var unlockFilter: UnlockFilterBand = .all
    @State private var difficultyFilter: DifficultyFilterBand = .all

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)

    private var filteredSpecies: [FishSpecies] {
        var result = FishSpecies.allCases

        switch unlockFilter {
        case .all: break
        case .unlocked: result = result.filter { !records(for: $0).isEmpty }
        case .locked: result = result.filter { records(for: $0).isEmpty }
        }

        if difficultyFilter != .all {
            result = result.filter { $0.difficulty.filterBand == difficultyFilter }
        }

        return result
    }

    private var isFiltering: Bool {
        unlockFilter != .all || difficultyFilter != .all
    }

    private var collected: [CollectedFish] {
        store.collectedFishes.sorted { $0.recordedAt > $1.recordedAt }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    filterBar
                        .padding(.horizontal)
                        .padding(.top, 12)

                    if filteredSpecies.isEmpty {
                        emptyFilterResult
                            .padding(.horizontal)
                    } else {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(filteredSpecies) { species in
                                speciesCard(species)
                            }
                        }
                        .padding(.horizontal)
                        .animation(.spring(duration: 0.3), value: filteredSpecies.map(\.id))
                    }
                }
                .padding(.bottom, 24)
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image(systemName: "book.closed.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.teal)
                        Text(L10n.Collection.title)
                            .font(.system(.title2, design: .rounded).weight(.bold))
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(L10n.Collection.title)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .dewAppBackground()
        .onAppear {
            guard !ReviewRequestManager.shared.hasRequestedThisSession else { return }
            Task {
                try? await Task.sleep(for: .seconds(3))
                ReviewRequestManager.shared.tryRequest(for: .collectionTab) { requestReview() }
            }
        }
        }
        .sheet(item: $selectedSpecies) { species in
            SpeciesDetailSheet(
                species: species,
                fishes: records(for: species),
                snapshot: snapshot(for: species)
            )
            .presentationDetents([.large])
            .presentationBackground(.clear)
            .presentationDragIndicator(.hidden)
        }
    }

    private var filterBar: some View {
        HStack(spacing: 10) {
            filterSegmentGroup {
                ForEach(UnlockFilterBand.selectableCases, id: \.self) { filter in
                    filterSegmentButton(
                        icon: filter.icon,
                        title: filter.displayName,
                        isSelected: unlockFilter == filter,
                        accessibilityLabel: filter.displayName
                    ) {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            unlockFilter = unlockFilter == filter ? .all : filter
                        }
                    }
                }
            }

            filterSegmentGroup {
                ForEach(DifficultyFilterBand.selectableCases, id: \.self) { filter in
                    difficultySegmentButton(
                        filter: filter,
                        isSelected: difficultyFilter == filter
                    ) {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            difficultyFilter = difficultyFilter == filter ? .all : filter
                        }
                    }
                }
            }

            if isFiltering {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        unlockFilter = .all
                        difficultyFilter = .all
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                        .background(Color.primary.opacity(0.06), in: Circle())
                }
                .buttonStyle(.plain)
                .transition(.opacity)
                .accessibilityLabel(L10n.Collection.filterResetA11y)
            }
        }
    }

    private func filterSegmentGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 2) {
            content()
        }
        .padding(3)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        }
    }

    private func filterSegmentButton(
        icon: String,
        title: String,
        isSelected: Bool,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                Text(title)
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            .frame(width: 52, height: 40)
            .background(
                isSelected ? Color.primary.opacity(0.1) : Color.clear,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func difficultySegmentButton(
        filter: DifficultyFilterBand,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                HStack(spacing: 2) {
                    ForEach(0..<filter.starCount, id: \.self) { _ in
                        Image(systemName: "star.fill")
                    }
                }
                .font(.system(size: 9, weight: .semibold))
                Text(filter.displayName)
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(isSelected ? Color.orange : Color.secondary.opacity(0.65))
            .frame(width: 52, height: 40)
            .background(
                isSelected ? Color.orange.opacity(0.12) : Color.clear,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(filter.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var emptyFilterResult: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(L10n.Collection.noResults)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    unlockFilter = .all
                    difficultyFilter = .all
                }
            } label: {
                Label(L10n.Common.reset, systemImage: "xmark.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel(L10n.Collection.filterResetA11y)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func speciesCard(_ species: FishSpecies) -> some View {
        let snapshot = snapshot(for: species)
        let isUnlocked = snapshot.isUnlocked

        return Button {
            selectedSpecies = species
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            isUnlocked
                                ? snapshot.accentColor.opacity(0.12)
                                : Color.black.opacity(0.04)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .strokeBorder(
                                    isUnlocked
                                        ? snapshot.accentColor.opacity(0.35)
                                        : Color.primary.opacity(0.06),
                                    lineWidth: 1
                                )
                        }

                    FishArtworkView(
                        species: species,
                        tint: isUnlocked ? nil : .secondary,
                        isLocked: !isUnlocked
                    )
                    .frame(width: 96, height: 96)
                    .shadow(color: isUnlocked ? snapshot.accentColor.opacity(0.35) : .clear, radius: isUnlocked ? 8 : 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if !isUnlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(8)
                            .background(Color.white.opacity(0.9), in: Circle())
                            .padding(8)
                    }
                }
                .frame(height: 120)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(isUnlocked ? species.displayName : "???")
                            .font(.system(.body, design: .rounded).weight(.bold))
                            .foregroundStyle(isUnlocked ? Color.primary : Color.secondary.opacity(0.7))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        Spacer()

                        if isUnlocked {
                            Image(systemName: snapshot.statusIcon)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(snapshot.accentColor)
                        } else {
                            difficultyStars(for: species)
                        }
                    }

                    HStack(spacing: 8) {
                        Image(systemName: isUnlocked ? "fish.fill" : "drop.fill")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(isUnlocked ? snapshot.accentColor : .cyan)
                        Text(snapshot.helperText)
                            .font(.system(.footnote, design: .rounded).weight(.bold))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background((isUnlocked ? snapshot.accentColor : Color.cyan).opacity(0.12), in: Capsule())
                }
                .padding(.horizontal, 4)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(isUnlocked ? .ultraThinMaterial : .thinMaterial)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(
                        isUnlocked
                            ? snapshot.accentColor.opacity(0.2)
                            : Color.white.opacity(0.1),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(isUnlocked ? 0.05 : 0.02), radius: 15, y: 6)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func difficultyStars(for species: FishSpecies) -> some View {
        let count: Int = {
            switch species.requiredWaterRatio {
            case ..<0.25: return 1
            case ..<0.50: return 2
            default: return 3
            }
        }()
        
        HStack(spacing: 2) {
            ForEach(0..<count, id: \.self) { _ in
                Image(systemName: "star.fill")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.orange)
            }
        }
    }

    private func records(for species: FishSpecies) -> [CollectedFish] {
        collected.filter { $0.speciesId == species.rawValue && $0.succeeded }
    }

    private func snapshot(for species: FishSpecies) -> SpeciesGrowthSnapshot {
        let speciesRecords = records(for: species)
        return SpeciesGrowthSnapshot(
            species: species,
            unlockedRecordCount: speciesRecords.count,
            bestUnlockedRatio: speciesRecords.map(\.waterRatio).max() ?? 0
        )
    }
}

private struct SpeciesDetailSheet: View {
    let species: FishSpecies
    let fishes: [CollectedFish]
    let snapshot: SpeciesGrowthSnapshot

    @State private var selectedFish: CollectedFish?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    init(species: FishSpecies, fishes: [CollectedFish], snapshot: SpeciesGrowthSnapshot) {
        self.species = species
        self.fishes = fishes
        self.snapshot = snapshot
        self._selectedFish = State(initialValue: nil)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(.secondaryLabel))
                        .frame(width: 30, height: 30)
                        .background(Color(.systemGray5), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.Common.close)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 4)

            ScrollView {
                VStack(spacing: 20) {
                    header

                    if fishes.isEmpty {
                        lockedState
                        growthGuideCard
                            .opacity(0.55)
                    } else {
                        growthGuideCard

                        VStack(spacing: 12) {
                            unlockedStateHeader

                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(fishes) { fish in
                                    Button {
                                        selectedFish = fish
                                    } label: {
                                        fishTile(fish)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    colorScheme == .dark
                        ? AnyShapeStyle(Color(red: 0.02, green: 0.06, blue: 0.10))
                        : AnyShapeStyle(LinearGradient(colors: [.aquariumTop, .aquariumBottom], startPoint: .top, endPoint: .bottom))
                )
                .ignoresSafeArea()
        )
        .sheet(item: $selectedFish) { fish in
            FishDetailSheet(fish: fish)
                .presentationDetents([.medium])
                .presentationBackground(.clear)
                .presentationDragIndicator(.hidden)
        }
    }

    private var header: some View {
        let unlocked = !fishes.isEmpty

        return VStack(spacing: 12) {
            ZStack {
                if unlocked {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [snapshot.accentColor.opacity(0.4), snapshot.accentColor.opacity(0.0)],
                                center: .center,
                                startRadius: 10,
                                endRadius: 70
                            )
                        )
                        .blur(radius: 8)
                }

                Circle()
                    .fill(
                        unlocked
                            ? AnyShapeStyle(snapshot.accentColor.opacity(0.24))
                            : AnyShapeStyle(Color.white.opacity(0.08))
                    )
                    .overlay {
                        Circle()
                            .strokeBorder(
                                unlocked
                                    ? snapshot.accentColor.opacity(0.48)
                                    : Color.white.opacity(0.15),
                                lineWidth: 1
                            )
                    }

                FishArtworkView(
                    species: species,
                    tint: unlocked ? nil : .secondary,
                    isLocked: !unlocked
                )
                .frame(width: 100, height: 96)
                .shadow(color: unlocked ? snapshot.accentColor.opacity(0.5) : .clear, radius: unlocked ? 14 : 0)

                if !unlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(9)
                        .background(Color.black.opacity(0.4), in: Circle())
                        .offset(x: 40, y: 40)
                }
            }
            .frame(width: 130, height: 130)

            Text(unlocked ? species.displayName : "???")
                .font(.title2.weight(.bold))
                .foregroundStyle(unlocked ? .primary : .secondary)
        }
    }

    private var growthGuideCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: fishes.isEmpty ? FeedIcon.systemName : "fish.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(fishes.isEmpty ? .orange : snapshot.accentColor)
                Text(fishes.isEmpty ? L10n.Collection.appearsOnFeed : L10n.Collection.fishAcquired(fishes.count))
                    .font(.headline.weight(.bold))
                Spacer()
            }
            if fishes.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "drop.fill")
                        .foregroundStyle(.cyan)
                    Text(L10n.Collection.aquariumLevelMin(species.requiredAquariumTier + 1))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .padding(20)
        .background(Color.dewSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var unlockedStateHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title3)
                    .foregroundStyle(snapshot.accentColor)
                
                Text(species.displayName)
                    .font(.headline.weight(.bold))
                
                Spacer()
            }
            .padding(.horizontal, 4)

            Divider()
                .background(Color.white.opacity(0.15))
        }
    }

    private var lockedState: some View {
        HStack(spacing: 16) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.teal.opacity(0.1))
                        .frame(width: 54, height: 54)
                    Image(systemName: "drop.fill")
                        .font(.title3)
                        .foregroundStyle(.teal)
                }
                Text(L10n.Collection.requiredAquarium)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                Text("Lv.\(species.requiredAquariumTier + 1)")
                    .font(.system(.title3, design: .rounded).bold())
                    .foregroundStyle(.teal)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.dewSurfaceSoft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.1))
                        .frame(width: 54, height: 54)
                    Image(systemName: "star.fill")
                        .font(.title3)
                        .foregroundStyle(.orange)
                }
                Text(L10n.Collection.difficulty)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                difficultyStarsDetail(for: species)
                Text(species.difficulty.displayName)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.dewSurfaceSoft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    @ViewBuilder
    private func difficultyStarsDetail(for species: FishSpecies) -> some View {
        let count: Int = {
            switch species.requiredWaterRatio {
            case ..<0.25: return 1
            case ..<0.50: return 2
            default: return 3
            }
        }()
        
        HStack(spacing: 2) {
            ForEach(0..<count, id: \.self) { _ in
                Image(systemName: "star.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.orange)
            }
        }
        .frame(height: 24)
    }

    private func fishTile(_ fish: CollectedFish) -> some View {
        let theme = WaterLevelTheme(waterRatio: fish.waterRatio)
        return VStack(spacing: 8) {
            FishArtworkView(species: species)
                .frame(width: 48, height: 42)
                .shadow(color: theme.tintColor.opacity(0.35), radius: 6)
            Text(fish.name)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.primary.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.tintColor.opacity(0.1))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(theme.tintColor.opacity(0.28), lineWidth: 1)
        }
    }
}

#Preview {
    CollectionView()
        .environment(AppDataStore())
}
