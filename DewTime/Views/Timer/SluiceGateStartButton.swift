import SwiftUI

/// シンプルな円形スタートボタン。
/// play.circle.fill アイコンを使った分かりやすいボタン。
struct SluiceGateStartButton: View {
    let onStart: () -> Void

    @State private var isPressed = false
    @State private var glowPulse = false

    var body: some View {
        Button { handleTap() } label: {
            ZStack {
                // 背景円（濃い青）
                Circle()
                    .fill(Color.dewBlue.opacity(0.3))
                    .frame(width: 120, height: 120)

                // 白いアイコン
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.white)
            }
            .scaleEffect(isPressed ? 0.88 : 1.0)
            .shadow(color: Color.black.opacity(glowPulse ? 0.4 : 0.2), radius: glowPulse ? 24 : 12, y: 6)
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
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
