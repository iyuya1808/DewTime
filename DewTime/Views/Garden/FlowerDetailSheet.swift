import SwiftUI

struct FlowerDetailSheet: View {
    let flower: PlantFlower

    @Environment(\.dismiss) private var dismiss

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
                    .fill(flowerColor.opacity(0.16))
                    .frame(width: 112, height: 112)
                Image(systemName: flowerIcon)
                    .font(.system(size: 58, weight: .semibold))
                    .foregroundStyle(flowerColor)
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(spacing: 6) {
                Text(speciesName)
                    .font(.title2.weight(.bold))
                Text(flower.recordedAt, format: .dateTime.year().month().day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                detailMetric(icon: "drop.fill", value: "\(Int(flower.waterRatio * 100))%", label: "残水量", tint: flowerColor)
                detailMetric(
                    icon: flower.succeeded ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
                    value: flower.succeeded ? "成功" : "未達",
                    label: "出発",
                    tint: flower.succeeded ? .green : .orange
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
                .fill(LinearGradient(colors: [.gardenTop, .gardenBottom], startPoint: .top, endPoint: .bottom))
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
        .background(.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var flowerIcon: String {
        if !flower.succeeded { return "leaf.fill" }
        return FlowerSpecies(rawValue: flower.speciesId)?.icon ?? "sparkles"
    }

    private var flowerColor: Color {
        if !flower.succeeded { return .gray }
        return WaterLevelTheme(waterRatio: flower.waterRatio).tintColor
    }

    private var speciesName: String {
        FlowerSpecies(rawValue: flower.speciesId)?.displayName ?? flower.name
    }

    private var message: String {
        if flower.waterRatio >= 0.8 { return "たっぷり水が残った朝。大きく明るい花が咲きました。" }
        if flower.waterRatio >= 0.5 { return "いいペースで出発できました。庭にもちゃんと潤いが残っています。" }
        if flower.waterRatio >= 0.2 { return "少し慌ただしい朝でしたが、芽はきちんと残っています。" }
        return "ぎりぎりの朝でした。次はもう少し水を残して咲かせましょう。"
    }
}
