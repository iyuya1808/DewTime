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
        guard requiredTotalWater > 0 else { return 0 }
        return min(1.0, max(0.0, currentWater / requiredTotalWater))
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
            .navigationTitle("図鑑")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("並び順", selection: $sortOrder) {
                            ForEach(SpeciesSortOrder.allCases, id: \.self) { order in
                                Text(order.rawValue).tag(order)
                            }
                        }
                    } label: {
                        Label("並び替え", systemImage: sortOrder == .default ? "arrow.up.arrow.down" : "arrow.up.arrow.down.circle.fill")
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
                snapshot: snapshot(for: species),
                onSelectFish: { fish in
                    selectedSpecies = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        selectedFish = fish
                    }
                }
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
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    filterChipGroup(label: "解放", items: UnlockFilter.allCases, selection: $unlockFilter)

                    Rectangle()
                        .fill(.secondary.opacity(0.25))
                        .frame(width: 1, height: 20)
                        .padding(.horizontal, 2)

                    filterChipGroup(label: "難易度", items: DifficultyFilter.allCases, selection: $difficultyFilter)

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
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func filterChipGroup<T: RawRepresentable & Hashable & CaseIterable>(
        label: String,
        items: T.AllCases,
        selection: Binding<T>
    ) -> some View where T.RawValue == String {
        HStack(spacing: 6) {
            ForEach(Array(items), id: \.self) { item in
                let isSelected = selection.wrappedValue == item
                Button {
                    withAnimation(.spring(duration: 0.2)) {
                        selection.wrappedValue = item
                    }
                } label: {
                    Text(item.rawValue)
                        .font(.caption.weight(isSelected ? .semibold : .regular))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(
                            isSelected
                                ? AnyShapeStyle(Color.teal.opacity(0.85))
                                : AnyShapeStyle(Color.dewSurfaceSoft),
                            in: Capsule()
                        )
                        .foregroundStyle(isSelected ? .white : .secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(label) \(item.rawValue)")
            }
        }
    }

    private var emptyFilterResult: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("条件に合う魚がいません")
                .font(.headline)
                .foregroundStyle(.secondary)
            Button {
                withAnimation(.spring(duration: 0.25)) {
                    unlockFilter = .all
                    difficultyFilter = .all
                    sortOrder = .default
                }
            } label: {
                Text("フィルターをリセット")
                    .font(.subheadline)
                    .foregroundStyle(.teal)
            }
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
            VStack(alignment: .leading, spacing: 14) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            isUnlocked
                                ? snapshot.accentColor.opacity(0.15)
                                : isGrowing
                                    ? Color.blue.opacity(0.12)
                                    : Color.black.opacity(0.06)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(
                                    isUnlocked
                                        ? snapshot.accentColor.opacity(0.48)
                                        : isGrowing
                                            ? Color.blue.opacity(0.32)
                                            : Color.white.opacity(0.18),
                                    lineWidth: 0.8
                                )
                        }

                    FishArtworkView(
                        species: species,
                        tint: isUnlocked || isGrowing ? nil : .secondary,
                        isLocked: !(isUnlocked || isGrowing)
                    )
                    .frame(width: 72, height: 72)
                    .shadow(color: isUnlocked ? snapshot.accentColor.opacity(0.45) : isGrowing ? .blue.opacity(0.25) : .clear, radius: isUnlocked ? 8 : 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    statusPill(snapshot: snapshot, species: species)
                        .padding(8)
                }
                .frame(height: 94)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(species.displayName)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(isUnlocked || isGrowing ? .primary : .secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)

                        Spacer(minLength: 4)

                        if isUnlocked || isGrowing {
                            Text("\(Int((snapshot.progress * 100).rounded()))%")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(isGrowing ? Color.blue : snapshot.accentColor)
                                .monospacedDigit()
                        } else {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary.opacity(0.72))
                        }
                    }

                    if isUnlocked || isGrowing {
                        compactGrowthLane(snapshot: snapshot)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "drop.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("目安 \(Int(snapshot.requiredTotalWater.rounded()))pt")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            Image(systemName: "chart.bar.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(species.difficultyLabel)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)
                    }
                }

                HStack(spacing: 6) {
                    if isUnlocked || isGrowing {
                        Image(systemName: snapshot.currentStage.icon)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(isGrowing ? Color.blue : snapshot.accentColor)

                        Text(snapshot.progressSummary)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    } else {
                        Image(systemName: "info.circle")
                            .font(.caption2)
                            .foregroundStyle(.secondary.opacity(0.8))
                        Text("朝の出発で成魚になると解放")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary.opacity(0.8))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }

                    Spacer(minLength: 0)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(isUnlocked || isGrowing ? .ultraThinMaterial : .thinMaterial)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        isUnlocked
                            ? snapshot.accentColor.opacity(0.3)
                            : isGrowing
                                ? Color.blue.opacity(0.25)
                                : Color.white.opacity(0.15),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(isUnlocked || isGrowing ? 0.08 : 0.03), radius: 20, y: 10)
            .shadow(color: isUnlocked
                        ? snapshot.accentColor.opacity(0.18)
                        : isGrowing
                            ? Color.blue.opacity(0.12)
                            : .clear,
                    radius: 14, y: 8)
            .opacity(isUnlocked || isGrowing ? 1.0 : 0.65)
        }
        .buttonStyle(.plain)
    }

    private func statusPill(snapshot: SpeciesGrowthSnapshot, species: FishSpecies) -> some View {
        let isUnlocked = snapshot.isUnlocked
        let isGrowing = snapshot.activeFish != nil

        return Group {
            if isUnlocked {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("\(snapshot.unlockedRecordCount)回")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .lineLimit(1)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    LinearGradient(
                        colors: [snapshot.accentColor, snapshot.accentColor.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Capsule()
                )
                .shadow(color: snapshot.accentColor.opacity(0.3), radius: 3, y: 1)
            } else if isGrowing {
                HStack(spacing: 4) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("育成中")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .lineLimit(1)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Capsule()
                )
                .shadow(color: Color.blue.opacity(0.3), radius: 3, y: 1)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text(species.difficultyLabel)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .lineLimit(1)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.white.opacity(0.15), in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(Color.secondary.opacity(0.24), lineWidth: 0.8)
                }
            }
        }
    }

    private func compactGrowthLane(snapshot: SpeciesGrowthSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.07))
                        .frame(height: 6)

                    Capsule()
                        .fill(snapshot.progressGradient)
                        .frame(width: snapshot.progress > 0 ? max(14, width * snapshot.progress) : 0, height: 6)

                    ForEach(Array(GrowthStage.allCases.enumerated()), id: \.offset) { _, stage in
                        Circle()
                            .fill(stage.thresholdProgress <= snapshot.progress ? AnyShapeStyle(snapshot.accentColor) : AnyShapeStyle(.white.opacity(0.9)))
                            .frame(width: 8, height: 8)
                            .overlay {
                                Circle()
                                    .strokeBorder(snapshot.accentColor.opacity(stage.thresholdProgress <= snapshot.progress ? 0 : 0.26), lineWidth: 1)
                            }
                            .position(x: width * stage.thresholdProgress, y: 3)
                    }
                }
            }
            .frame(height: 6)

            HStack(spacing: 6) {
                Text(snapshot.currentStage.displayName)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(snapshot.accentColor)

                Spacer(minLength: 0)

                Text(snapshot.helperText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
    }

    private var latestFishes: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("最近育った魚")
                .font(.headline)
                .padding(.horizontal)

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
                                .frame(width: 38, height: 34)
                                Text(fish.name)
                                    .font(.caption2.weight(.semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)
                                Text("\(Int(fish.waterRatio * 100))%")
                                    .font(.caption2.bold())
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 76, height: 88)
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
    let onSelectFish: (CollectedFish) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

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
                                        onSelectFish(fish)
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
                .frame(width: 80, height: 76)
                .shadow(color: unlocked ? snapshot.accentColor.opacity(0.5) : .clear, radius: unlocked ? 12 : 0)

                if !unlocked && !isGrowing {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.4), in: Circle())
                        .offset(x: 36, y: 36)
                }
            }
            .frame(width: 112, height: 112)

            VStack(spacing: 6) {
                Text(species.displayName)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(unlocked || isGrowing ? .primary : .secondary)

                if unlocked {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text("登録済")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(
                        LinearGradient(
                            colors: [snapshot.accentColor, snapshot.accentColor.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: Capsule()
                    )
                    .shadow(color: snapshot.accentColor.opacity(0.25), radius: 3, y: 1.5)
                } else if isGrowing {
                    HStack(spacing: 4) {
                        Image(systemName: "drop.fill")
                            .font(.caption.weight(.bold))
                        Text("現在育成中")
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.75)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: Capsule()
                    )
                    .shadow(color: Color.blue.opacity(0.2), radius: 4, y: 2)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.caption.weight(.bold))
                        Text("未解放")
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.12), in: Capsule())
                    .overlay {
                        Capsule()
                            .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 0.8)
                    }
                }
            }

            Text(snapshot.helperText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private var growthGuideCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("成長ガイド")
                        .font(.headline)
                    Text(snapshot.progressSummary)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(snapshot.accentColor)
                        .monospacedDigit()
                }
                Spacer()
                Label(snapshot.currentStage.displayName, systemImage: snapshot.currentStage.icon)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(snapshot.accentColor.opacity(0.12), in: Capsule())
                    .foregroundStyle(snapshot.accentColor)
            }

            VStack(spacing: 10) {
                ForEach(Array(GrowthStage.allCases.enumerated()), id: \.offset) { index, stage in
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(stage.thresholdProgress <= snapshot.progress ? snapshot.accentColor : .white.opacity(0.9))
                                .frame(width: 12, height: 12)
                            Circle()
                                .strokeBorder(snapshot.accentColor.opacity(stage.thresholdProgress <= snapshot.progress ? 0 : 0.34), lineWidth: 1.5)
                                .frame(width: 12, height: 12)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(stage.displayName)
                                .font(.subheadline.weight(stage == snapshot.currentStage ? .bold : .semibold))
                            Text(stageDetailText(stage))
                                .font(.caption)
                                .foregroundStyle(stage == snapshot.currentStage ? snapshot.accentColor : .secondary)
                                .monospacedDigit()
                        }

                        Spacer()

                        if stage == snapshot.currentStage {
                            Text("いまここ")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(snapshot.accentColor.opacity(0.14), in: Capsule())
                                .foregroundStyle(snapshot.accentColor)
                        }
                    }

                    if index < GrowthStage.allCases.count - 1 {
                        Rectangle()
                            .fill(snapshot.accentColor.opacity(0.12))
                            .frame(width: 1.5, height: 12)
                            .padding(.leading, 5)
                    }
                }
            }
        }
        .padding(18)
        .background(Color.dewSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var unlockedStateHeader: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(snapshot.accentColor.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(snapshot.accentColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("解放した記録")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                    Text("これまでに育成して図鑑に登録された記録の一覧です。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 4)

            Divider()
                .background(Color.white.opacity(0.25))
        }
    }

    private var lockedState: some View {
        VStack(spacing: 18) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.secondary.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("未解放の魚")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                    Text("条件をクリアして朝の出発を行うと解放されます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 4)

            Divider()
                .background(Color.white.opacity(0.25))

            VStack(spacing: 10) {
                Text("解放条件")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 12) {
                    unlockConditionBadge(
                        icon: "drop.fill",
                        label: "必要水量",
                        value: species.requiredWaterPercentText + " 以上",
                        tint: .cyan
                    )
                    unlockConditionBadge(
                        icon: "chart.bar.fill",
                        label: "難易度",
                        value: species.difficultyLabel,
                        tint: .orange
                    )
                }
            }

            Text("朝の準備をスムーズに進めて\n水タンクに十分な水を残して出発しましょう！")
                .font(.caption2)
                .foregroundStyle(.secondary.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.dewSurfaceSoft)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8)
        }
    }

    private func unlockConditionBadge(icon: String, label: String, value: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(tint)
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.primary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.08))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(tint.opacity(0.18), lineWidth: 0.8)
        }
    }

    private func fishTile(_ fish: CollectedFish) -> some View {
        let theme = WaterLevelTheme(waterRatio: fish.waterRatio)
        return VStack(spacing: 6) {
            FishArtworkView(species: species)
                .frame(width: 42, height: 36)
                .shadow(color: theme.tintColor.opacity(0.3), radius: 4)
            Text(fish.name)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.primary.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text("\(Int(fish.waterRatio * 100))%")
                .font(.caption2.bold())
                .foregroundStyle(theme.tintColor)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.tintColor.opacity(0.1))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(theme.tintColor.opacity(0.32), lineWidth: 0.8)
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
