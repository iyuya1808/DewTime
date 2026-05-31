import SwiftUI
import SwiftData

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
}

struct CollectionView: View {
    @Query(sort: \CollectedFish.recordedAt, order: .reverse) private var collected: [CollectedFish]
    @Query(sort: \ActiveFish.startedAt, order: .reverse) private var activeFishes: [ActiveFish]

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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    progressHeader
                        .padding(.horizontal)
                        .padding(.top, 12)

                    filterBar
                        .padding(.horizontal)

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
            .background(
                LinearGradient(
                    colors: [.aquariumTop, .aquariumBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
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
                                : AnyShapeStyle(.white.opacity(0.5)),
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

    private var progressHeader: some View {
        let unlocked = unlockedSpeciesCount
        let progress = Double(unlocked) / Double(max(FishSpecies.allCases.count, 1))
        let activeCount = activeFishes.filter { !$0.isCompleted }.count

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(.teal.opacity(0.16))
                    Image(systemName: "book.closed.fill")
                        .font(.title2)
                        .foregroundStyle(.teal)
                }
                .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 4) {
                    Text("魚のコレクション")
                        .font(.title3.weight(.bold))
                    Text("\(unlocked) / \(FishSpecies.allCases.count) 種を発見")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Spacer()

                if activeCount > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("育成中")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("\(activeCount)匹")
                            .font(.subheadline.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(.teal)
                    }
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.45))
                    Capsule()
                        .fill(LinearGradient(colors: [.teal, .cyan], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 10)
        }
        .padding(16)
        .background(.white.opacity(0.66), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func speciesCard(_ species: FishSpecies) -> some View {
        let snapshot = snapshot(for: species)

        return Button {
            selectedSpecies = species
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(snapshot.accentColor.opacity(snapshot.isUnlocked || snapshot.activeFish != nil ? 0.16 : 0.10))
                        Text(species.emoji)
                            .font(.system(size: 32))
                            .grayscale(snapshot.isUnlocked || snapshot.activeFish != nil ? 0 : 1)
                            .opacity(snapshot.isUnlocked || snapshot.activeFish != nil ? 1 : 0.5)
                    }
                    .frame(width: 58, height: 58)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(species.displayName)
                            .font(.headline)
                            .foregroundStyle(snapshot.isUnlocked || snapshot.activeFish != nil ? .primary : Color.gray.opacity(0.58))
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            stageBadge(stage: snapshot.currentStage, tint: snapshot.accentColor)
                            if snapshot.activeFish != nil {
                                Text("育成中")
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(snapshot.accentColor.opacity(0.14), in: Capsule())
                                    .foregroundStyle(snapshot.accentColor)
                            } else if snapshot.isUnlocked {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.teal)
                            } else {
                                Text(species.difficultyLabel)
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(.gray.opacity(0.14), in: Capsule())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(snapshot.progressSummary)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(snapshot.accentColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    compactGrowthLane(snapshot: snapshot)

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(snapshot.helperText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)

                        Spacer(minLength: 4)

                        Text("\(Int((snapshot.progress * 100).rounded()))%")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(snapshot.accentColor.opacity(0.9))
                            .monospacedDigit()
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 168, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [
                        .white.opacity(snapshot.activeFish != nil ? 0.84 : 0.76),
                        snapshot.accentColor.opacity(snapshot.activeFish != nil ? 0.10 : 0.04)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(snapshot.accentColor.opacity(snapshot.activeFish != nil ? 0.28 : 0.16), lineWidth: 1)
            }
            .shadow(color: snapshot.accentColor.opacity(snapshot.activeFish != nil ? 0.15 : 0.08), radius: 18, y: 10)
            .opacity(snapshot.isUnlocked || snapshot.activeFish != nil ? 1.0 : 0.92)
        }
        .buttonStyle(.plain)
    }

    private func stageBadge(stage: GrowthStage, tint: Color) -> some View {
        Label(stage.displayName, systemImage: stage.icon)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.12), in: Capsule())
            .foregroundStyle(tint)
    }

    private func compactGrowthLane(snapshot: SpeciesGrowthSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(snapshot.accentColor.opacity(0.10))
                        .frame(height: 8)

                    Capsule()
                        .fill(snapshot.progressGradient)
                        .frame(width: snapshot.progress > 0 ? max(18, width * snapshot.progress) : 0, height: 8)

                    ForEach(Array(GrowthStage.allCases.enumerated()), id: \.offset) { _, stage in
                        Circle()
                            .fill(stage.thresholdProgress <= snapshot.progress ? AnyShapeStyle(snapshot.accentColor) : AnyShapeStyle(.white.opacity(0.95)))
                            .frame(width: 10, height: 10)
                            .overlay {
                                Circle()
                                    .strokeBorder(snapshot.accentColor.opacity(stage.thresholdProgress <= snapshot.progress ? 0 : 0.26), lineWidth: 1)
                            }
                            .position(x: width * stage.thresholdProgress, y: 4)
                    }
                }
            }
            .frame(height: 8)

            HStack(spacing: 6) {
                Text(snapshot.currentStage.displayName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(snapshot.accentColor)

                Spacer(minLength: 0)

                if let nextStage = snapshot.nextStage {
                    Text("次: \(nextStage.displayName)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("成魚")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
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
                                Text(emoji(for: fish))
                                    .font(.system(size: 28))
                                    .grayscale(fish.succeeded ? 0 : 1)
                                Text(fish.recordedAt, format: .dateTime.month().day())
                                    .font(.caption2.weight(.semibold))
                                Text("\(Int(fish.waterRatio * 100))%")
                                    .font(.caption2.bold())
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 76, height: 88)
                            .background(.white.opacity(0.68), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var unlockedSpeciesCount: Int {
        FishSpecies.allCases.filter { !records(for: $0).isEmpty }.count
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

    private func emoji(for fish: CollectedFish) -> String {
        FishSpecies(rawValue: fish.speciesId)?.emoji ?? "🐟"
    }
}

private struct SpeciesDetailSheet: View {
    let species: FishSpecies
    let fishes: [CollectedFish]
    let snapshot: SpeciesGrowthSnapshot
    let onSelectFish: (CollectedFish) -> Void

    @Environment(\.dismiss) private var dismiss
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
                    growthGuideCard

                    if fishes.isEmpty {
                        lockedState
                    } else {
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
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(LinearGradient(colors: [.aquariumTop, .aquariumBottom], startPoint: .top, endPoint: .bottom))
                .ignoresSafeArea()
        )
    }

    private var header: some View {
        let unlocked = !fishes.isEmpty

        return VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(snapshot.accentColor.opacity(unlocked || snapshot.activeFish != nil ? 0.14 : 0.10))
                Text(species.emoji)
                    .font(.system(size: 58))
                    .grayscale(unlocked || snapshot.activeFish != nil ? 0 : 1)
                    .opacity(unlocked || snapshot.activeFish != nil ? 1 : 0.4)
            }
            .frame(width: 112, height: 112)

            Text(species.displayName)
                .font(.title2.weight(.bold))
                .foregroundStyle(unlocked || snapshot.activeFish != nil ? .primary : Color.gray.opacity(0.55))

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
        .background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var lockedState: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("まだ解放されていません")
                    .font(.headline)
                Text("条件を満たすと図鑑に登録されます")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                Text("解放条件")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 12) {
                    unlockConditionBadge(
                        icon: "drop.fill",
                        label: "必要水量",
                        value: species.requiredWaterPercentText + " 以上"
                    )
                    unlockConditionBadge(
                        icon: "chart.bar.fill",
                        label: "難易度",
                        value: species.difficultyLabel
                    )
                }
            }

            Text("朝のルーティンを頑張って\n水タンクをいっぱいにしよう！")
                .font(.caption)
                .foregroundStyle(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(.white.opacity(0.56), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func unlockConditionBadge(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func fishTile(_ fish: CollectedFish) -> some View {
        VStack(spacing: 6) {
            Text(species.emoji)
                .font(.system(size: 28))
            Text(fish.recordedAt, format: .dateTime.month().day())
                .font(.caption2.weight(.semibold))
            Text("\(Int(fish.waterRatio * 100))%")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
        .modelContainer(for: [UserSchedule.self, RoutineItem.self, CollectedFish.self, ActiveFish.self, FishCareRecord.self, Aquarium.self], inMemory: true)
}
