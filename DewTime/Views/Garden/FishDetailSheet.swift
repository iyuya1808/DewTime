import SwiftUI

struct FishDetailSheet: View {
    let fish: CollectedFish

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 20) {
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
                Text(fishEmoji)
                    .font(.system(size: 58))
                    .grayscale(fish.succeeded ? 0 : 1)
            }

            VStack(spacing: 6) {
                Text(speciesName)
                    .font(.title2.weight(.bold))
                Text(fish.recordedAt, format: .dateTime.year().month().day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                detailMetric(icon: "drop.fill", value: "\(Int(fish.waterRatio * 100))%", label: "残水量", tint: fishColor)
                detailMetric(
                    icon: fish.succeeded ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
                    value: fish.succeeded ? "成功" : "未達",
                    label: "出発",
                    tint: fish.succeeded ? .teal : .orange
                )
            }

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

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
    }

    private func detailMetric(icon: String, value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
            Text(value)
                .font(.headline)
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.dewSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var fishEmoji: String {
        FishSpecies(rawValue: fish.speciesId)?.emoji ?? "🐟"
    }

    private var fishColor: Color {
        if !fish.succeeded { return .gray }
        return WaterLevelTheme(waterRatio: fish.waterRatio).tintColor
    }

    private var speciesName: String {
        FishSpecies(rawValue: fish.speciesId)?.displayName ?? fish.name
    }

    private var message: String {
        if fish.waterRatio >= 0.8 { return "たっぷり水が残った朝。元気いっぱいの魚に育ちました。" }
        if fish.waterRatio >= 0.5 { return "いいペースで出発できました。水槽にもちゃんと潤いが残っています。" }
        if fish.waterRatio >= 0.2 { return "少し慌ただしい朝でしたが、魚はきちんと育っています。" }
        return "ぎりぎりの朝でした。次はもう少し水を残して育てましょう。"
    }
}
