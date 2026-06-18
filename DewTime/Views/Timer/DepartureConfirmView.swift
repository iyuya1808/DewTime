import SwiftUI

/// 出発前の確認シート。報酬はオンタイムかどうかのみで決まり、残水量は関係しない。
struct DepartureConfirmView: View {
    let isOnTime: Bool
    let tierWillGrow: Bool
    let bonusFeedWillAward: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    static func preferredDetentHeight(tierWillGrow: Bool) -> CGFloat {
        tierWillGrow ? 370 : 350
    }

    var body: some View {
        ZStack {
            LinearGradient.dewTimeSheet
                .ignoresSafeArea()

            VStack(spacing: 0) {
                DragHandle()
                    .padding(.bottom, 12)

                Text(L10n.Timer.departureConfirmTitle)
                    .font(.title3.weight(.bold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Text(confirmationSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.top, 8)

                rewardPreview
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                if tierWillGrow {
                    Label(L10n.Timer.aquariumGrows, systemImage: "arrow.up.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.teal)
                        .padding(.top, 14)
                }

                Spacer(minLength: 0)

                actionButtons
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }
        }
        .foregroundStyle(.white)
    }

    // MARK: - Sections

    private var rewardPreview: some View {
        HStack(spacing: 10) {
            rewardChip(
                icon: isOnTime ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                title: isOnTime ? L10n.Timer.onTime : L10n.Timer.late,
                tint: isOnTime ? .teal : .orange
            )
            rewardChip(
                icon: isOnTime ? "drop.fill" : "drop",
                title: isOnTime ? L10n.Timer.dewDropPlus : L10n.Timer.noDewDrop,
                tint: isOnTime ? .cyan : .orange.opacity(0.8)
            )
            if bonusFeedWillAward {
                rewardChip(
                    icon: FeedIcon.systemName,
                    title: L10n.Timer.feedPlus,
                    tint: .yellow
                )
            }
        }
    }

    private func rewardChip(icon: String, title: String, tint: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2.weight(.semibold))
                .foregroundStyle(tint)
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityLabel(title)
    }

    private var actionButtons: some View {
        HStack(spacing: 48) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onCancel()
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.white.opacity(0.55))
                        .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
                    Text(L10n.Common.back)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.Common.back)

            Button {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onConfirm()
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: "figure.walk.departure")
                        .font(.system(size: 56))
                        .foregroundStyle(Color.dewBlue)
                        .shadow(color: Color.dewBlue.opacity(0.45), radius: 10, y: 4)
                    Text(L10n.Timer.depart)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.Timer.confirmDepartureA11y)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private var confirmationSubtitle: String {
        if isOnTime {
            return L10n.Timer.onTimeRewardHint(includesFeed: bonusFeedWillAward)
        }
        return L10n.Timer.lateNoReward
    }
}

#Preview("オンタイム") {
    Color.black.ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            DepartureConfirmView(
                isOnTime: true,
                tierWillGrow: true,
                bonusFeedWillAward: true,
                onConfirm: {},
                onCancel: {}
            )
            .presentationDetents([.height(DepartureConfirmView.preferredDetentHeight(tierWillGrow: true))])
        }
}

#Preview("遅刻") {
    Color.black.ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            DepartureConfirmView(
                isOnTime: false,
                tierWillGrow: false,
                bonusFeedWillAward: false,
                onConfirm: {},
                onCancel: {}
            )
            .presentationDetents([.height(DepartureConfirmView.preferredDetentHeight(tierWillGrow: false))])
        }
}
