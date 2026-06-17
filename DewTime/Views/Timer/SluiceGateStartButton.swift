import SwiftUI

/// シンプルな円形スタートボタン。
struct SluiceGateStartButton: View {
    let onStart: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button { handleTap() } label: {
            Image(systemName: "drop.fill")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 88, height: 88)
                .background(Color.dewBlue, in: Circle())
                .scaleEffect(isPressed ? 0.92 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("起きる")
        .accessibilityHint("タップして起きる")
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
