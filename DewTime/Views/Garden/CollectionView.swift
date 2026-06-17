import SwiftUI
import StoreKit

private enum UnlockFilter: String, CaseIterable {
    case all = "すべて"
    case unlocked = "解放済み"
    case locked = "未解放"
}

private enum DifficultyFilter: String, CaseIterable {
    case all = "すべて"
    case easy = "やさしい"
    case normal = "ふつう"
    case hard = "むずかしい"
}

private enum SpeciesSortOrder: String, CaseIterable {
    case `default` = "デフォルト"
    case name = "名前順"
    case difficulty = "難易度順"
    case achievement = "達成率順"
}

private struct SpeciesGrowthSnapshot {
    let species: FishSpecies
    let activeFish: ActiveFish?
    let unlockedRecordCount: Int
    let bestUnlockedRatio: Double

    var isUnlocked: Bool {
        unlockedRecordCount > 0
    }

    var requiredTotalWater: Double {
        activeFish?.requiredTotalWater ?? species.averageRequiredTotalWater
    }

    var currentWater: Double {
        activeFish?.receivedWater ?? 0
    }

    var progress: Double {
        if activeFish != nil {
            guard requiredTotalWater > 0 else { return 0 }
            return min(1.0, max(0.0, currentWater / requiredTotalWater))
        }
        if isUnlocked {
            return 1.0
        }
        return 0.0
    }

    var currentStage: GrowthStage {
        GrowthStage.stage(for: progress)
    }

    var nextStage: GrowthStage? {
        GrowthStage.nextStage(after: progress)
    }

    var remainingWaterToNextStage: Int {
        guard let nextStage else { return 0 }
        let remaining = species.targetWaterAmount(for: nextStage, requiredTotalWater: requiredTotalWater) - currentWater
        return max(0, Int(ceil(remaining)))
    }

    var currentStageWater: Int {
        Int(species.targetWaterAmount(for: currentStage, requiredTotalWater: requiredTotalWater).rounded())
    }

    var accentColor: Color {
        if let activeFish {
            return WaterLevelTheme(waterRatio: activeFish.progress).tintColor
        }
        if isUnlocked {
            return WaterLevelTheme(waterRatio: bestUnlockedRatio).tintColor
        }
        switch species.difficultyLabel {
        case "かんたん": return Color(hex: "#48C774")
        case "やさしい": return Color(hex: "#2EC4B6")
        case "ふつう": return Color(hex: "#3FA7FF")
        case "むずかしい": return Color(hex: "#8B80F9")
        default: return Color(hex: "#F06595")
        }
    }

    var progressGradient: LinearGradient {
        LinearGradient(
            colors: [accentColor, accentColor.opacity(0.55)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var progressSummary: String {
        if let nextStage {
            if activeFish == nil {
                return "\(nextStage.displayName)まで約 \(remainingWaterToNextStage)pt"
            }
            return "\(nextStage.displayName)まであと \(remainingWaterToNextStage)pt"
        }
        return activeFish == nil ? "成魚までの目安を達成" : "成魚まで育成完了"
    }

    var helperText: String {
        if let activeFish {
            return "育成中 \(Int(activeFish.receivedWater.rounded())) / \(Int(activeFish.requiredTotalWater.rounded()))pt"
        }
        if isUnlocked {
            return "\(unlockedRecordCount)回発見 / 最高 \(Int(bestUnlockedRatio * 100))%"
        }
        return "成魚目安 \(Int(requiredTotalWater.rounded()))pt"
    }

    var isVisible: Bool {
        isUnlocked || activeFish != nil
    }

    var statusTitle: String {
        if activeFish != nil { return "育成中" }
        if isUnlocked { return "\(unlockedRecordCount)回" }
        return "未解放"
    }

    var statusIcon: String {
        if activeFish != nil { return "drop.fill" }
        if isUnlocked { return "checkmark.seal.fill" }
        return "lock.fill"
    }
}

struct CollectionView: View {
    @Environment(AppDataStore.self) private var store
    @Environment(\.requestReview) private var requestReview

    @State private var selectedSpecies: FishSpecies?
    @State private var selectedFish: CollectedFish?
    @State private var unlockFilter: UnlockFilter = .all
    @State private var difficultyFilter: DifficultyFilter = .all
    @State private var sortOrder: SpeciesSortOrder = .default

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)

    private var filteredSpecies: [FishSpecies] {
        var result = FishSpecies.allCases

        switch unlockFilter {
        case .all: break
        case .unlocked: result = result.filter { !records(for: $0).isEmpty }
        case .locked: result = result.filter { records(for: $0).isEmpty }
        }

        switch difficultyFilter {
        case .all: break
        case .easy: result = result.filter { $0.difficultyLabel == "やさしい" }
        case .normal: result = result.filter { $0.difficultyLabel == "ふつう" }
        case .hard: result = result.filter { $0.difficultyLabel == "むずかしい" }
        }

        switch sortOrder {
        case .default:
            break
        case .name:
            result = result.sorted { $0.displayName < $1.displayName }
        case .difficulty:
            result = result.sorted { $0.requiredWaterRatio < $1.requiredWaterRatio }
        case .achievement:
            result = result.sorted {
                snapshot(for: $0).progress > snapshot(for: $1).progress
            }
        }

        return result
    }

    private var isFiltering: Bool {
        unlockFilter != .all || difficultyFilter != .all || sortOrder != .default
    }

    private var collected: [CollectedFish] {
        store.collectedFishes.sorted { $0.recordedAt > $1.recordedAt }
    }

    private var activeFishes: [ActiveFish] {
        store.activeFishes.sorted { $0.startedAt > $1.startedAt }
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

                    if !collected.isEmpty {
                        latestFishes
                    }
                }
                .padding(.bottom, 24)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("並び順", selection: $sortOrder) {
                            ForEach(SpeciesSortOrder.allCases, id: \.self) { order in
                                Text(order.rawValue).tag(order)
                            }
                        }
                    } label: {
                        Image(systemName: sortOrder == .default ? "arrow.up.arrow.down" : "arrow.up.arrow.down.circle.fill")
                            .foregroundStyle(sortOrder == .default ? Color.secondary : Color.teal)
                    }
                }
            }
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
        .sheet(item: $selectedFish) { fish in
            FishDetailSheet(fish: fish)
                .presentationDetents([.medium])
                .presentationBackground(.clear)
                .presentationDragIndicator(.hidden)
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                iconFilterChip(icon: "square.grid.2x2", isSelected: unlockFilter == .all) {
                    withAnimation(.spring(duration: 0.2)) { unlockFilter = .all }
                }
                .accessibilityLabel("すべて")
                iconFilterChip(icon: "checkmark.seal.fill", isSelected: unlockFilter == .unlocked) {
                    withAnimation(.spring(duration: 0.2)) { unlockFilter = .unlocked }
                }
                .accessibilityLabel("解放済み")
                iconFilterChip(icon: "lock.fill", isSelected: unlockFilter == .locked) {
                    withAnimation(.spring(duration: 0.2)) { unlockFilter = .locked }
                }
                .accessibilityLabel("未解放")

                Rectangle()
                    .fill(.secondary.opacity(0.25))
                    .frame(width: 1, height: 20)
                    .padding(.horizontal, 2)

                filterChip(isSelected: difficultyFilter == .all, accessibilityLabel: "難易度すべて") {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 14))
                } action: {
                    withAnimation(.spring(duration: 0.2)) { difficultyFilter = .all }
                }

                filterChip(isSelected: difficultyFilter == .easy, accessibilityLabel: "やさしい") {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                } action: {
                    withAnimation(.spring(duration: 0.2)) { difficultyFilter = .easy }
                }

                filterChip(isSelected: difficultyFilter == .normal, accessibilityLabel: "ふつう") {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                        Image(systemName: "star.fill")
                    }
                    .font(.system(size: 10))
                } action: {
                    withAnimation(.spring(duration: 0.2)) { difficultyFilter = .normal }
                }

                filterChip(isSelected: difficultyFilter == .hard, accessibilityLabel: "むずかしい") {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                        Image(systemName: "star.fill")
                        Image(systemName: "star.fill")
                    }
                    .font(.system(size: 10))
                } action: {
                    withAnimation(.spring(duration: 0.2)) { difficultyFilter = .hard }
                }

                if isFiltering {
                    Button {
                        withAnimation(.spring(duration: 0.25)) {
                            unlockFilter = .all
                            difficultyFilter = .all
                            sortOrder = .default
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.leading, 4)
                    }
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityLabel("フィルターをリセット")
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func filterChip<Content: View>(isSelected: Bool, accessibilityLabel: String, @ViewBuilder content: () -> Content, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            content()
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(
                    isSelected
                        ? AnyShapeStyle(Color.teal.opacity(0.85))
                        : AnyShapeStyle(Color.dewSurfaceSoft),
                    in: Capsule()
                )
                .foregroundStyle(isSelected ? .white : .secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private func iconFilterChip(icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        filterChip(isSelected: isSelected, accessibilityLabel: "", content: {
            Image(systemName: icon)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
        }, action: action)
    }

    private var emptyFilterResult: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.title2)
                .foregroundStyle(.secondary)
            Button {
                withAnimation(.spring(duration: 0.25)) {
                    unlockFilter = .all
                    difficultyFilter = .all
                    sortOrder = .default
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.teal)
            }
            .accessibilityLabel("フィルターをリセット")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func speciesCard(_ species: FishSpecies) -> some View {
        let snapshot = snapshot(for: species)
        let isUnlocked = snapshot.isUnlocked
        let isGrowing = snapshot.activeFish != nil

        return Button {
            selectedSpecies = species
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            isUnlocked
                                ? snapshot.accentColor.opacity(0.12)
                                : isGrowing
                                    ? Color.blue.opacity(0.08)
                                    : Color.black.opacity(0.04)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .strokeBorder(
                                    isUnlocked
                                        ? snapshot.accentColor.opacity(0.35)
                                        : isGrowing
                                            ? Color.blue.opacity(0.25)
                                            : Color.primary.opacity(0.06),
                                    lineWidth: 1
                                )
                        }

                    FishArtworkView(
                        species: species,
                        tint: isUnlocked || isGrowing ? nil : .secondary,
                        isLocked: !(isUnlocked || isGrowing)
                    )
                    .frame(width: 96, height: 96)
                    .shadow(color: isUnlocked ? snapshot.accentColor.opacity(0.35) : isGrowing ? .blue.opacity(0.2) : .clear, radius: isUnlocked ? 8 : 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if !isUnlocked && !isGrowing {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(7)
                            .background(Color.white.opacity(0.85), in: Circle())
                            .padding(8)
                    } else if isGrowing {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(7)
                            .background(Color.blue, in: Circle())
                            .padding(8)
                    }
                }
                .frame(height: 120)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(isUnlocked || isGrowing ? species.displayName : "???")
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundStyle(isUnlocked || isGrowing ? Color.primary : Color.secondary.opacity(0.7))
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if isUnlocked || isGrowing {
                            Image(systemName: snapshot.currentStage.icon)
                                .font(.caption2)
                                .foregroundStyle(isGrowing ? Color.blue : snapshot.accentColor)
                        } else {
                            difficultyStars(for: species)
                        }
                    }

                    if isUnlocked || isGrowing {
                        compactGrowthLane(snapshot: snapshot)
                    } else {
                        HStack(spacing: 8) {
                            HStack(spacing: 3) {
                                Image(systemName: "drop.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.cyan)
                                Text("水 \(species.requiredWaterPercentText)")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.cyan.opacity(0.08), in: Capsule())

                            Spacer()
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(.horizontal, 4)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(isUnlocked || isGrowing ? .ultraThinMaterial : .thinMaterial)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(
                        isUnlocked
                            ? snapshot.accentColor.opacity(0.2)
                            : isGrowing
                                ? Color.blue.opacity(0.15)
                                : Color.white.opacity(0.1),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(isUnlocked || isGrowing ? 0.05 : 0.02), radius: 15, y: 6)
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
        
        HStack(spacing: 1) {
            ForEach(0..<count, id: \.self) { _ in
                Image(systemName: "star.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.orange)
            }
        }
    }

    private func compactGrowthLane(snapshot: SpeciesGrowthSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.07))
                        .frame(height: 12)

                    Capsule()
                        .fill(snapshot.progressGradient)
                        .frame(width: snapshot.progress > 0 ? max(18, width * snapshot.progress) : 0, height: 12)
                        .animation(.spring(duration: 0.6, bounce: 0.2), value: snapshot.progress)

                    ForEach(GrowthStage.allCases) { stage in
                        let isReached = stage.thresholdProgress <= snapshot.progress
                        Image(systemName: stage.icon)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(isReached ? .white : Color.secondary.opacity(0.5))
                            .frame(width: 14, height: 14)
                            .background(
                                Circle()
                                    .fill(isReached ? snapshot.accentColor : Color.white.opacity(0.9))
                            )
                            .overlay {
                                Circle()
                                    .strokeBorder(snapshot.accentColor.opacity(isReached ? 0 : 0.26), lineWidth: 0.8)
                            }
                            .position(x: max(7, min(width - 7, width * stage.thresholdProgress)), y: 6)
                            .animation(.spring(duration: 0.4), value: isReached)
                    }
                }
            }
            .frame(height: 12)
        }
    }


    private var latestFishes: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .accessibilityLabel("最近育った魚")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(collected.prefix(16))) { fish in
                        Button {
                            selectedFish = fish
                        } label: {
                            VStack(spacing: 6) {
                                FishArtworkView(
                                    species: species(for: fish),
                                    tint: fish.succeeded ? nil : .secondary,
                                    isLocked: !fish.succeeded
                                )
                                .frame(width: 44, height: 40)
                                Text(fish.name)
                                    .font(.caption2.weight(.semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)
                            }
                            .frame(width: 76, height: 84)
                            .background(Color.dewSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func records(for species: FishSpecies) -> [CollectedFish] {
        collected.filter { $0.speciesId == species.rawValue && $0.succeeded }
    }

    private func activeFish(for species: FishSpecies) -> ActiveFish? {
        activeFishes.first { $0.speciesId == species.rawValue && !$0.isCompleted }
    }

    private func snapshot(for species: FishSpecies) -> SpeciesGrowthSnapshot {
        let speciesRecords = records(for: species)
        return SpeciesGrowthSnapshot(
            species: species,
            activeFish: activeFish(for: species),
            unlockedRecordCount: speciesRecords.count,
            bestUnlockedRatio: speciesRecords.map(\.waterRatio).max() ?? 0
        )
    }

    private func species(for fish: CollectedFish) -> FishSpecies {
        FishSpecies(rawValue: fish.speciesId) ?? .medaka
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
        let isGrowing = snapshot.activeFish != nil

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
                            : isGrowing
                                ? AnyShapeStyle(Color.blue.opacity(0.18))
                                : AnyShapeStyle(Color.white.opacity(0.08))
                    )
                    .overlay {
                        Circle()
                            .strokeBorder(
                                unlocked
                                    ? snapshot.accentColor.opacity(0.48)
                                    : isGrowing
                                        ? Color.blue.opacity(0.32)
                                        : Color.white.opacity(0.15),
                                lineWidth: 1
                            )
                    }

                FishArtworkView(
                    species: species,
                    tint: unlocked || isGrowing ? nil : .secondary,
                    isLocked: !(unlocked || isGrowing)
                )
                .frame(width: 100, height: 96)
                .shadow(color: unlocked ? snapshot.accentColor.opacity(0.5) : .clear, radius: unlocked ? 14 : 0)

                if !unlocked && !isGrowing {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(9)
                        .background(Color.black.opacity(0.4), in: Circle())
                        .offset(x: 40, y: 40)
                } else if isGrowing {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(9)
                        .background(Color.blue, in: Circle())
                        .offset(x: 40, y: 40)
                }
            }
            .frame(width: 130, height: 130)

            Text(unlocked || isGrowing ? species.displayName : "???")
                .font(.title2.weight(.bold))
                .foregroundStyle(unlocked || isGrowing ? .primary : .secondary)
        }
    }

    private var growthGuideCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 0) {
                ForEach(Array(GrowthStage.allCases.enumerated()), id: \.offset) { index, stage in
                    let isCurrent = stage == snapshot.currentStage
                    let isPassed = stage.thresholdProgress <= snapshot.progress
                    
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(isPassed ? snapshot.accentColor : Color.secondary.opacity(0.12))
                                .frame(width: 38, height: 38)
                                .shadow(color: isCurrent ? snapshot.accentColor.opacity(0.4) : .clear, radius: 6)
                            
                            Image(systemName: stage.icon)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(isPassed ? .white : .secondary)
                        }
                        .overlay {
                            if isCurrent {
                                Circle()
                                    .strokeBorder(snapshot.accentColor, lineWidth: 2)
                                    .scaleEffect(1.15)
                            }
                        }
                        
                        Text(stage.displayNameHiragana)
                            .font(.system(size: 9, weight: isCurrent ? .bold : .medium))
                            .foregroundStyle(isCurrent ? snapshot.accentColor : Color.secondary)
                    }
                    
                    if index < GrowthStage.allCases.count - 1 {
                        let nextStage = GrowthStage.allCases[index + 1]
                        let isNextPassed = nextStage.thresholdProgress <= snapshot.progress
                        
                        Rectangle()
                            .fill(isNextPassed ? snapshot.accentColor : Color.secondary.opacity(0.15))
                            .frame(height: 3)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 4)
                    }
                }
            }
            .padding(.vertical, 8)
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
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.cyan.opacity(0.1))
                            .frame(width: 54, height: 54)
                        Image(systemName: "drop.fill")
                            .font(.title3)
                            .foregroundStyle(.cyan)
                    }
                    Text("ひつような水")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                    Text(species.requiredWaterPercentText)
                        .font(.system(.title3, design: .rounded).bold())
                        .foregroundStyle(.cyan)
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
                    Text("むずかしさ")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                    difficultyStarsDetail(for: species)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.dewSurfaceSoft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
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

    private func stageDetailText(_ stage: GrowthStage) -> String {
        let water = Int(species.targetWaterAmount(for: stage, requiredTotalWater: snapshot.requiredTotalWater).rounded())
        if stage == .adult {
            return "\(water)pt で成魚"
        }
        if stage == snapshot.currentStage, let nextStage = snapshot.nextStage {
            return "\(nextStage.displayName)まであと \(snapshot.remainingWaterToNextStage)pt"
        }
        return "\(water)pt が目安"
    }
}

#Preview {
    CollectionView()
        .environment(AppDataStore())
}
