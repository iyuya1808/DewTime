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

struct CollectionView: View {
    @Query(sort: \CollectedFish.recordedAt, order: .reverse) private var collected: [CollectedFish]

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
        case .locked:   result = result.filter { records(for: $0).isEmpty }
        }

        switch difficultyFilter {
        case .all: break
        case .easy:   result = result.filter { $0.difficultyLabel == "やさしい" }
        case .normal: result = result.filter { $0.difficultyLabel == "ふつう" }
        case .hard:   result = result.filter { $0.difficultyLabel == "むずかしい" }
        }

        switch sortOrder {
        case .default: break
        case .name:
            result = result.sorted { $0.displayName < $1.displayName }
        case .difficulty:
            result = result.sorted { $0.requiredWaterRatio < $1.requiredWaterRatio }
        case .achievement:
            result = result.sorted {
                let a = records(for: $0).map(\.waterRatio).max() ?? -1
                let b = records(for: $1).map(\.waterRatio).max() ?? -1
                return a > b
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
        let records = records(for: species)
        let best = records.map(\.waterRatio).max() ?? 0
        let unlocked = !records.isEmpty

        return Button {
            selectedSpecies = species
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ZStack {
                        Circle()
                            .fill((unlocked ? WaterLevelTheme(waterRatio: best).tintColor : Color.gray).opacity(0.14))
                        Text(species.emoji)
                            .font(.system(size: 32))
                            .grayscale(unlocked ? 0 : 1)
                            .opacity(unlocked ? 1 : 0.45)
                    }
                    .frame(width: 58, height: 58)

                    Spacer()

                    if unlocked {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.subheadline)
                            .foregroundStyle(.teal)
                    } else {
                        Text(species.difficultyLabel)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(.gray.opacity(0.18), in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(species.displayName)
                        .font(.headline)
                        .foregroundStyle(unlocked ? .primary : Color.gray.opacity(0.55))
                    if unlocked {
                        Text("\(records.count)回 / 最高 \(Int(best * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    } else {
                        Text("水量 \(species.requiredWaterPercentText) 以上で解放")
                            .font(.caption)
                            .foregroundStyle(.secondary.opacity(0.8))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 148, alignment: .leading)
            .background(
                unlocked
                    ? AnyShapeStyle(.white.opacity(0.72))
                    : AnyShapeStyle(.ultraThinMaterial.opacity(0.6)),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        unlocked
                            ? WaterLevelTheme(waterRatio: best).tintColor.opacity(0.24)
                            : Color.gray.opacity(0.18),
                        lineWidth: 1
                    )
            }
            .opacity(unlocked ? 1.0 : 0.82)
        }
        .buttonStyle(.plain)
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

    private func emoji(for fish: CollectedFish) -> String {
        FishSpecies(rawValue: fish.speciesId)?.emoji ?? "🐟"
    }
}

private struct SpeciesDetailSheet: View {
    let species: FishSpecies
    let fishes: [CollectedFish]
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
        let best = fishes.map(\.waterRatio).max() ?? 0
        let unlocked = !fishes.isEmpty

        return VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill((unlocked ? WaterLevelTheme(waterRatio: best).tintColor : Color.gray).opacity(0.14))
                Text(species.emoji)
                    .font(.system(size: 58))
                    .grayscale(unlocked ? 0 : 1)
                    .opacity(unlocked ? 1 : 0.4)
            }
            .frame(width: 112, height: 112)

            Text(species.displayName)
                .font(.title2.weight(.bold))
                .foregroundStyle(unlocked ? .primary : Color.gray.opacity(0.55))
            Text(unlocked ? "\(fishes.count)回育てました / 最高 \(Int(best * 100))%" : "未発見")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
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
}

#Preview {
    CollectionView()
        .modelContainer(for: [UserSchedule.self, RoutineItem.self, CollectedFish.self, ActiveFish.self, FishCareRecord.self, Aquarium.self], inMemory: true)
}
