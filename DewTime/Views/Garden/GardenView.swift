import SwiftUI
import SwiftData

struct GardenView: View {
    @Query(sort: \PlantFlower.recordedAt, order: .reverse) private var flowers: [PlantFlower]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        NavigationStack {
            ScrollView {
                if flowers.isEmpty {
                    emptyState
                        .padding(.top, 80)
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(flowers) { flower in
                            cell(for: flower)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("お庭")
            .background(
                LinearGradient(
                    colors: [.gardenTop, .gardenBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
        }
    }

    private func cell(for flower: PlantFlower) -> some View {
        VStack(spacing: 6) {
            Image(systemName: flower.succeeded ? (FlowerSpecies(rawValue: flower.speciesId)?.icon ?? "sparkles") : "leaf.fill")
                .font(.system(size: 32))
                .foregroundStyle(flower.succeeded ? .pink : .gray)
                .frame(maxWidth: .infinity, minHeight: 56)
            Text(flower.recordedAt, format: .dateTime.month(.abbreviated).day())
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(Int(flower.waterRatio * 100))%")
                .font(.caption.bold())
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "leaf")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("まだ花が咲いていません")
                .font(.headline)
            Text("タイマー画面で「いってきます！」を押すと、ここに花が増えていきます")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
}

#Preview {
    GardenView()
        .modelContainer(for: [UserSchedule.self, RoutineItem.self, PlantFlower.self], inMemory: true)
}
