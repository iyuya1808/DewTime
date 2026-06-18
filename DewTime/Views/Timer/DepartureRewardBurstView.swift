import SwiftUI

/// 出発完了後にしずく・餌獲得を伝える軽いオーバーレイ演出。
struct DepartureRewardBurstView: View {
    let bonusFeedAwarded: Bool
    let onFinished: () -> Void

    @State private var scale: CGFloat = 0.72
    @State private var opacity: Double = 0
    @State private var yOffset: CGFloat = 16

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 38))
                .foregroundStyle(Color(red: 0.35, green: 0.95, blue: 0.82))
                .shadow(color: Color.teal.opacity(0.55), radius: 12, y: 4)

            HStack(spacing: 10) {
                rewardChip(icon: "drop.fill", label: L10n.Timer.dewDropPlus, tint: Color(red: 0.2, green: 0.72, blue: 0.95))
                if bonusFeedAwarded {
                    rewardChip(icon: FeedIcon.systemName, label: L10n.Timer.feedPlus, tint: Color(red: 0.98, green: 0.78, blue: 0.15))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(Self.panelFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.28), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.45), radius: 24, y: 10)
        .scaleEffect(scale)
        .opacity(opacity)
        .offset(y: yOffset)
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(bonusFeedAwarded ? L10n.Timer.rewardDewFeedA11y : L10n.Timer.rewardDewA11y)
        .onAppear(perform: playSequence)
    }

    private static let panelFill = Color(red: 0.04, green: 0.06, blue: 0.18).opacity(0.96)

    private func rewardChip(icon: String, label: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.body.weight(.bold))
            Text(label)
                .font(.subheadline.weight(.heavy))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(tint.opacity(0.92), in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(.white.opacity(0.35), lineWidth: 1)
        }
        .shadow(color: tint.opacity(0.45), radius: 8, y: 3)
        .accessibilityLabel(label)
    }

    private func playSequence() {
        if AppPreferences.hapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
            scale = 1
            opacity = 1
            yOffset = 0
        }

        withAnimation(.easeOut(duration: 0.4).delay(2.2)) {
            opacity = 0
            yOffset = -10
            scale = 0.96
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.65) {
            onFinished()
        }
    }
}

#Preview {
    ZStack {
        LinearGradient.dewTimeDark.ignoresSafeArea()
        DepartureRewardBurstView(bonusFeedAwarded: true, onFinished: {})
    }
}
