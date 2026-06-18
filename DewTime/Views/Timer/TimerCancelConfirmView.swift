import SwiftUI

/// タイマーキャンセルの確認シート。
struct TimerCancelConfirmView: View {
    let waterLevel: Double
    let onReset: () -> Void
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            LinearGradient.dewTimeSheet
                .ignoresSafeArea()

            VStack(spacing: 0) {
                DragHandle()
                    .padding(.bottom, 12)

                Text(L10n.Timer.cancelConfirmTitle)
                    .font(.title3.weight(.bold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                HStack(alignment: .center, spacing: 20) {
                    WaterTankView(waterLevel: waterLevel, cornerRadius: 22)
                        .frame(width: 88, height: 118)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.35))

                    WaterTankView(waterLevel: 1.0, cornerRadius: 22)
                        .frame(width: 88, height: 118)
                }
                .padding(.top, 16)

                Text(L10n.Timer.cancelConfirmSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.65))
                    .padding(.top, 12)
                    .padding(.horizontal, 24)
                    .multilineTextAlignment(.center)

                Spacer(minLength: 0)

                HStack(spacing: 48) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onContinue()
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "arrow.uturn.backward.circle.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(Color.dewBlue)
                                .shadow(color: Color.dewBlue.opacity(0.45), radius: 10, y: 4)
                            Text(L10n.Timer.cancelGoBack)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.Timer.cancelA11yBack)

                    Button {
                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
                        onReset()
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "stop.circle.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(.orange)
                                .shadow(color: Color.orange.opacity(0.35), radius: 10, y: 4)
                            Text(L10n.Timer.cancelStop)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.75))
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.Timer.cancelA11yStop)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
        }
        .foregroundStyle(.white)
    }
}

#Preview {
    Color.black.ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            TimerCancelConfirmView(waterLevel: 0.62, onReset: {}, onContinue: {})
                .presentationDetents([.height(340)])
        }
}
