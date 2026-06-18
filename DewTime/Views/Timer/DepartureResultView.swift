import SwiftUI

struct DepartureResultView: View {
    let earnedDrop: Bool
    let bonusFeedAwarded: Bool
    let delaySeconds: Int
    let onDismiss: () -> Void

    /// sheet の高さ目安（報酬行数に応じて調整）
    static func preferredDetentHeight(bonusFeedAwarded: Bool, hasDelay: Bool) -> CGFloat {
        var height: CGFloat = 318
        if bonusFeedAwarded { height += 58 }
        if hasDelay { height += 22 }
        return height
    }

    var body: some View {
        ZStack {
            LinearGradient.dewTimeSheet
                .ignoresSafeArea()

            VStack(spacing: 0) {
                DragHandle()

                VStack(spacing: 20) {
                    statusSection
                    rewardsSection
                    doneButton
                }
                .padding(.horizontal, 24)
                .padding(.top, 4)
                .padding(.bottom, 16)
            }
            .foregroundStyle(.white)
        }
        .safeAreaPadding(.bottom, 8)
        .onAppear(perform: playFeedback)
    }

    // MARK: - Sections

    private var statusSection: some View {
        VStack(spacing: 10) {
            Image(systemName: earnedDrop ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundStyle(earnedDrop ? Color.teal : Color.orange)
                .shadow(color: (earnedDrop ? Color.teal : Color.orange).opacity(0.4), radius: 12, y: 4)

            Text(earnedDrop ? "いってきます！" : "遅刻してしまいました")
                .font(.title3.weight(.bold))

            if delaySeconds > 0 {
                Text("\(delayMinutesText)遅れ")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
            }
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }

    private var rewardsSection: some View {
        VStack(spacing: 10) {
            rewardRow(
                icon: earnedDrop ? "drop.fill" : "drop",
                title: earnedDrop ? "しずく +1" : "しずくなし",
                subtitle: earnedDrop ? "オンタイム出発" : "次回は時間内に出発しましょう",
                tint: earnedDrop ? .cyan : .orange
            )

            if bonusFeedAwarded {
                rewardRow(
                    icon: FeedIcon.systemName,
                    title: "餌 +1",
                    subtitle: "水槽タブで使えます",
                    tint: .yellow
                )
            }
        }
        .padding(16)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func rewardRow(icon: String, title: String, subtitle: String, tint: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer()
        }
    }

    private var doneButton: some View {
        Button(action: onDismiss) {
            Text("完了")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: earnedDrop ? [.teal, .cyan] : [.orange, .yellow.opacity(0.85)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .accessibilityLabel("完了")
    }

    // MARK: - Helpers

    private var delayMinutesText: String {
        let minutes = max(1, Int(ceil(Double(delaySeconds) / 60.0)))
        return "\(minutes)分"
    }

    private func playFeedback() {
        guard AppPreferences.hapticsEnabled else { return }
        if earnedDrop {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }
}

#Preview("オンタイム") {
    Color.black.ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            DepartureResultView(
                earnedDrop: true,
                bonusFeedAwarded: true,
                delaySeconds: 0,
                onDismiss: {}
            )
            .presentationDetents([
                .height(DepartureResultView.preferredDetentHeight(bonusFeedAwarded: true, hasDelay: false))
            ])
        }
}

#Preview("遅刻") {
    Color.black.ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            DepartureResultView(
                earnedDrop: false,
                bonusFeedAwarded: false,
                delaySeconds: 185,
                onDismiss: {}
            )
            .presentationDetents([
                .height(DepartureResultView.preferredDetentHeight(bonusFeedAwarded: false, hasDelay: true))
            ])
        }
}
