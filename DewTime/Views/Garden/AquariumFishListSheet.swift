import SwiftUI

struct AquariumFishListSheet: View {
    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var editingFish: CollectedFish?
    @State private var nameDraft = ""

    private var fishes: [CollectedFish] {
        store.aquariumFish()
    }

    var body: some View {
        NavigationStack {
            Group {
                if fishes.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(fishes) { fish in
                                fishRow(fish)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                }
            }
            .navigationTitle(L10n.Aquarium.FishList.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
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
            }
        }
        .dewAppBackground()
        .alert(L10n.Aquarium.FishList.nameAlertTitle, isPresented: Binding(
            get: { editingFish != nil },
            set: { if !$0 { editingFish = nil } }
        )) {
            TextField(L10n.Common.name, text: $nameDraft)
            Button(L10n.Common.save) {
                guard let fish = editingFish else { return }
                Task { await store.renameCollectedFish(fish, name: nameDraft) }
                editingFish = nil
            }
            Button(L10n.Common.cancel, role: .cancel) {
                editingFish = nil
            }
        } message: {
            Text(L10n.Aquarium.FishList.nameAlertMessage)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "fish")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(L10n.Aquarium.FishList.emptyTitle)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(L10n.Aquarium.FishList.emptyDetail)
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }

    private func fishRow(_ fish: CollectedFish) -> some View {
        let species = FishSpecies(rawValue: fish.speciesId) ?? .medaka
        let theme = WaterLevelTheme(waterRatio: fish.waterRatio)

        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(theme.tintColor.opacity(0.14))
                    .frame(width: 52, height: 52)
                FishArtworkView(
                    species: species,
                    tint: fish.succeeded ? nil : .secondary,
                    isLocked: !fish.succeeded
                )
                .frame(width: 40, height: 36)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(fish.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(species.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(fish.recordedAt, format: .dateTime.month().day().hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }

            Spacer(minLength: 0)

            Button {
                nameDraft = fish.name
                editingFish = fish
            } label: {
                Image(systemName: "pencil")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.teal)
                    .frame(width: 32, height: 32)
                    .background(Color.dewSurface, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.Aquarium.FishList.renameA11y(fish.name))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.dewSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(fish.name)、\(species.displayName)")
    }
}

#Preview {
    AquariumFishListSheet()
        .environment(AppDataStore())
}
