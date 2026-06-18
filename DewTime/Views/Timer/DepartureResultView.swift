import SwiftUI

struct DepartureResultView: View {
    let earnedDrop: Bool
    let bonusFeedAwarded: Bool
    let delaySeconds: Int
    let onDismiss: () -> Void
    let onResume: () -> Void

    /// sheet の高さ目安（報酬行数に応じて調整）
    static func preferredDetentHeight(bonusFeedAwarded: Bool, hasDelay: Bool) -> CGFloat {
        var height: CGFloat = 330
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
                    actionButtons
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

            Text(earnedDrop ? L10n.Timer.resultOnTime : L10n.Timer.resultLate)
                .font(.title3.weight(.bold))

            if delaySeconds > 0 {
                Text(L10n.Timer.minutesLate(delayMinutesText))
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
                title: earnedDrop ? L10n.Timer.dewDropPlus : L10n.Timer.noDewDrop,
                subtitle: earnedDrop ? L10n.Timer.onTimeDeparture : L10n.Timer.tryOnTimeNext,
                tint: earnedDrop ? .cyan : .orange
            )

            if bonusFeedAwarded {
                rewardRow(
                    icon: FeedIcon.systemName,
                    title: L10n.Timer.feedPlus,
                    subtitle: L10n.Timer.feedForAquarium,
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

    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button(action: onResume) {
                Label(L10n.Timer.resume, systemImage: "arrow.uturn.backward.circle")
                    .font(.subheadline.weight(.semibold))
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(width: 100, height: 52)
                    .background(.white.opacity(0.10), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.Timer.resumeA11y)

            Button(action: onDismiss) {
                Text(L10n.Common.done)
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.dewBlue, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.Common.done)
        }
    }

    // MARK: - Helpers

    private var delayMinutesText: String {
        let minutes = max(1, Int(ceil(Double(delaySeconds) / 60.0)))
        return L10n.Timer.minutes(minutes)
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
                onDismiss: {},
                onResume: {}
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
                onDismiss: {},
                onResume: {}
            )
            .presentationDetents([
                .height(DepartureResultView.preferredDetentHeight(bonusFeedAwarded: false, hasDelay: true))
            ])
        }
}
