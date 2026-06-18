import SwiftUI

struct FishDetailSheet: View {
    let fish: CollectedFish

    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var showNameEditor = false
    @State private var nameDraft = ""

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(fishColor.opacity(0.16))
                    .frame(width: 140, height: 140)
                FishArtworkView(
                    species: fishSpecies,
                    tint: fish.succeeded ? nil : .secondary,
                    isLocked: !fish.succeeded
                )
                .frame(width: 110, height: 105)
            }

            VStack(spacing: 8) {
                ZStack(alignment: .trailing) {
                    Text(fish.name)
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 36)
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
                    .accessibilityLabel(L10n.FishDetail.editNameA11y)
                }
                
                Text(fish.recordedAt, format: .dateTime.year().month().day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 16) {
                // 朝のゆとり（残った水量）のビジュアル化（表情マークと水滴）
                VStack(spacing: 12) {
                    Image(systemName: waterDropFaceIcon)
                        .font(.system(size: 28))
                        .foregroundStyle(fishColor)
                    
                    HStack(spacing: 2) {
                        ForEach(0..<5) { i in
                            Image(systemName: i < waterDropCount ? "drop.fill" : "drop")
                                .font(.system(size: 10))
                                .foregroundStyle(i < waterDropCount ? fishColor : Color(.tertiaryLabel))
                        }
                    }
                    
                    Text(L10n.FishDetail.morningMargin)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color.dewSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                // 出発タイミングのビジュアル化（時計とチェックマーク/警告）
                VStack(spacing: 12) {
                    Image(systemName: fish.succeeded ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(fish.succeeded ? Color.teal : Color.orange)
                    
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Text(L10n.FishDetail.departure)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color.dewSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 38)
        .padding(.bottom, 24)
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(.secondaryLabel))
                    .frame(width: 30, height: 30)
                    .background(Color(.systemGray5), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.Common.close)
            .padding(24)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.FishDetail.recordA11y(
            name: fish.name,
            water: waterEvaluation,
            departure: fish.succeeded ? L10n.FishDetail.onTime : L10n.FishDetail.overTime
        ))
        .alert(L10n.FishDetail.nameAlertTitle, isPresented: $showNameEditor) {
            TextField(L10n.Common.name, text: $nameDraft)
            Button(L10n.Common.save) {
                Task { await store.renameCollectedFish(fish, name: nameDraft) }
            }
            Button(L10n.Common.cancel, role: .cancel) {}
        } message: {
            Text(L10n.FishDetail.nameAlertMessage)
        }
    }

    private var waterDropFaceIcon: String {
        switch fish.waterRatio {
        case 0.8...: return "face.smiling.fill"
        case 0.6...: return "face.smiling"
        case 0.4...: return "face.dashed"
        case 0.2...: return "face.neutral"
        default: return "face.frowning"
        }
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
        L10n.FishDetail.waterEvaluation(for: fish.waterRatio)
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
}
