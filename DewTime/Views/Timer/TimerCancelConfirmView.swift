import SwiftUI

/// タイマーキャンセルの確認シート。テキストなし・アイコンとビジュアルのみ。
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

                Image(systemName: "xmark.circle")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))

                HStack(alignment: .center, spacing: 20) {
                    WaterTankView(waterLevel: waterLevel, cornerRadius: 22)
                        .frame(width: 88, height: 118)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.35))

                    WaterTankView(waterLevel: 0.05, cornerRadius: 22)
                        .frame(width: 88, height: 118)
                        .overlay {
                            Image(systemName: "xmark")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                }
                .padding(.top, 16)

                Spacer(minLength: 0)
            }
        }
        .foregroundStyle(.white)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 48) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onContinue()
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(Color.dewBlue)
                        .shadow(color: Color.dewBlue.opacity(0.45), radius: 10, y: 4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("続ける")

                Button {
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    onReset()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.orange)
                        .shadow(color: Color.orange.opacity(0.35), radius: 10, y: 4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("タイマーをキャンセル")
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .background(
                LinearGradient.dewTimeSheet
                    .opacity(0.98)
                    .ignoresSafeArea(edges: .bottom)
            )
        }
    }
}

#Preview {
    Color.black.ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            TimerCancelConfirmView(waterLevel: 0.62, onReset: {}, onContinue: {})
                .presentationDetents([.height(340)])
        }
}
