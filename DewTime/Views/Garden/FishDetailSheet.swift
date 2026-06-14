import SwiftUI

struct FishDetailSheet: View {
    let fish: CollectedFish

    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var showNameEditor = false
    @State private var nameDraft = ""

    var body: some View {
        VStack(spacing: 16) {
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

            ZStack {
                Circle()
                    .fill(fishColor.opacity(0.16))
                    .frame(width: 112, height: 112)
                FishArtworkView(
                    species: fishSpecies,
                    tint: fish.succeeded ? nil : .secondary,
                    isLocked: !fish.succeeded
                )
                .frame(width: 82, height: 78)
            }

            VStack(spacing: 4) {
                ZStack(alignment: .trailing) {
                    Text(fish.name)
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.trailing, 36)
                    Button {
                        nameDraft = fish.name
                        showNameEditor = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.teal)
                            .frame(width: 28, height: 28)
                            .background(Color.dewSurface, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("魚の名前を編集")
                }
                Text(speciesName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(fish.recordedAt, format: .dateTime.year().month().day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 10) {
                waterMetricCard
                departureMetricCard
            }

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 24)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    colorScheme == .dark
                        ? AnyShapeStyle(Color(red: 0.02, green: 0.06, blue: 0.10))
                        : AnyShapeStyle(LinearGradient(colors: [.aquariumTop, .aquariumBottom], startPoint: .top, endPoint: .bottom))
                )
                .ignoresSafeArea()
        )
        .alert("魚の名前", isPresented: $showNameEditor) {
            TextField("名前", text: $nameDraft)
            Button("保存") {
                Task { await store.renameCollectedFish(fish, name: nameDraft) }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("空欄で保存すると種類名に戻ります。")
        }
    }

    private var waterMetricCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 3) {
                ForEach(0..<5) { i in
                    Image(systemName: i < waterDropCount ? "drop.fill" : "drop")
                        .font(.system(size: 14))
                        .foregroundStyle(i < waterDropCount ? fishColor : Color(.tertiaryLabel))
                }
            }
            Text(waterEvaluation)
                .font(.headline)
                .foregroundStyle(fishColor)
            Text("朝のゆとり")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.dewSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var departureMetricCard: some View {
        VStack(spacing: 8) {
            Image(systemName: fish.succeeded ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.title3)
                .foregroundStyle(fish.succeeded ? Color.teal : Color.orange)
            Text(fish.succeeded ? "時間内" : "時間超過")
                .font(.headline)
                .foregroundStyle(fish.succeeded ? Color.teal : Color.orange)
            Text("出発タイミング")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.dewSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var waterDropCount: Int {
        switch fish.waterRatio {
        case 0.8...: return 5
        case 0.6...: return 4
        case 0.4...: return 3
        case 0.2...: return 2
        default: return 1
        }
    }

    private var waterEvaluation: String {
        switch fish.waterRatio {
        case 0.8...: return "余裕たっぷり"
        case 0.6...: return "いいペース"
        case 0.4...: return "まずまず"
        case 0.2...: return "ギリギリ"
        default: return "タイムオーバー"
        }
    }

    private var fishSpecies: FishSpecies {
        FishSpecies(rawValue: fish.speciesId) ?? .medaka
    }

    private var fishColor: Color {
        if !fish.succeeded { return .gray }
        return WaterLevelTheme(waterRatio: fish.waterRatio).tintColor
    }

    private var speciesName: String {
        fishSpecies.displayName
    }

    private var message: String {
        if fish.waterRatio >= 0.8 { return "たっぷり水が残りました。元気いっぱいの魚に育ちました。" }
        if fish.waterRatio >= 0.5 { return "いいペースで出発できました。水槽にもちゃんと潤いが残っています。" }
        if fish.waterRatio >= 0.2 { return "少し慌ただしかったですが、魚はきちんと育っています。" }
        return "ぎりぎりの出発でした。次はもう少し水を残して育てましょう。"
    }
}
