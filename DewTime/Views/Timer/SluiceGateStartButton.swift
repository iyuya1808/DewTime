import SwiftUI

/// シンプルな円形スタートボタン。
struct SluiceGateStartButton: View {
    let onStart: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button { handleTap() } label: {
            VStack(spacing: 8) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 88, height: 88)
                    .background(Color.dewBlue, in: Circle())
                Text(L10n.Timer.start)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .scaleEffect(isPressed ? 0.92 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.Timer.start)
        .accessibilityHint(L10n.Timer.startA11yHint)
        .accessibilityAddTraits(.isButton)
    }

    private func handleTap() {
        withAnimation(.spring(response: 0.14, dampingFraction: 0.5)) { isPressed = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            withAnimation(.spring(response: 0.30, dampingFraction: 0.46)) { isPressed = false }
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onStart()
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        LinearGradient.dewTimeDark.ignoresSafeArea()
        VStack {
            Spacer()
            SluiceGateStartButton { }
            Spacer()
        }
    }
}
