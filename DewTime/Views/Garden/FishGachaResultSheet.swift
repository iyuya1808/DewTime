import SwiftUI

/// 餌やりガチャで魚が誕生したときの結果表示。
struct FishGachaReveal: Identifiable {
    let id: UUID
    let fish: CollectedFish
    let isNewSpecies: Bool

    var species: FishSpecies? {
        FishSpecies(rawValue: fish.speciesId)
    }
}

struct FishGachaResultSheet: View {
    let reveal: FishGachaReveal
    let onDismiss: () -> Void

    private var species: FishSpecies {
        reveal.species ?? .medaka
    }

    var body: some View {
        VStack(spacing: 0) {
            DragHandle()

            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.yellow)
                        .symbolEffect(.pulse, options: .repeating)

                    Text("新しい仲間が誕生！")
                        .font(.title3.weight(.bold))

                    if reveal.isNewSpecies {
                        Label("図鑑に初登場", systemImage: "book.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.purple)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.purple.opacity(0.12), in: Capsule())
                    }
                }
                .padding(.top, 8)

                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.cyan.opacity(0.2), .teal.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 148, height: 148)
                    FishArtworkView(species: species)
                        .frame(width: 118, height: 108)
                }

                VStack(spacing: 4) {
                    Text(species.displayName)
                        .font(.title2.weight(.bold))
                    Text(reveal.fish.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Button {
                    onDismiss()
                } label: {
                    Text("水槽で見る")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.teal, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity)
        .dewAppBackground()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        var parts = ["新しい\(species.displayName)が誕生しました"]
        if reveal.isNewSpecies { parts.append("図鑑に初登場") }
        return parts.joined(separator: "、")
    }
}

#Preview {
    FishGachaResultSheet(
        reveal: FishGachaReveal(
            id: UUID(),
            fish: CollectedFish(
                name: "メダカ",
                speciesId: FishSpecies.medaka.rawValue,
                succeeded: true,
                waterRatio: 1
            ),
            isNewSpecies: true
        ),
        onDismiss: {}
    )
}
