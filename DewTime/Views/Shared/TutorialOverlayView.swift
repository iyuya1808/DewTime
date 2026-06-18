import SwiftUI

struct TutorialOverlayView: View {
    @Binding var selectedTab: AppTab
    let onFinish: () -> Void

    @State private var currentIndex = 0

    private let steps = TutorialStep.allCases

    private var currentStep: TutorialStep {
        steps[currentIndex]
    }

    private var isFirstStep: Bool {
        currentIndex == steps.startIndex
    }

    private var isLastStep: Bool {
        currentIndex == steps.index(before: steps.endIndex)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.56)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(L10n.Tutorial.skip) {
                        completeTutorial()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.14), in: Capsule())
                    .accessibilityHint(L10n.Tutorial.skipHint)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)

                Spacer()

                tutorialCard
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
            }
        }
        .onAppear {
            selectedTab = currentStep.tab
        }
        .onChange(of: currentIndex) { _, _ in
            withAnimation(.easeInOut(duration: 0.24)) {
                selectedTab = currentStep.tab
            }
        }
        .accessibilityAddTraits(.isModal)
    }

    private var tutorialCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(currentStep.tint.opacity(0.16))
                    Image(systemName: currentStep.icon)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(currentStep.tint)
                }
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(currentStep.tab.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(currentStep.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text(currentStep.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                ForEach(steps.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == currentIndex ? currentStep.tint : Color.secondary.opacity(0.24))
                        .frame(width: index == currentIndex ? 22 : 7, height: 7)
                        .animation(.spring(response: 0.26, dampingFraction: 0.78), value: currentIndex)
                        .accessibilityHidden(true)
                }

                Spacer()

                Text("\(currentIndex + 1)/\(steps.count)")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(L10n.Tutorial.pageOf(current: currentIndex + 1, total: steps.count))
            }

            HStack(spacing: 10) {
                Button {
                    moveBackward()
                } label: {
                    Label(L10n.Common.back, systemImage: "chevron.left")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(TutorialSecondaryButtonStyle())
                .disabled(isFirstStep)
                .opacity(isFirstStep ? 0.45 : 1)

                Button {
                    moveForward()
                } label: {
                    Label(isLastStep ? L10n.Tutorial.start : L10n.Tutorial.next, systemImage: isLastStep ? "checkmark" : "chevron.right")
                        .labelStyle(.titleAndIcon)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(TutorialPrimaryButtonStyle(tint: currentStep.tint))
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.24), radius: 24, y: 14)
        .accessibilityElement(children: .contain)
    }

    private func moveForward() {
        guard !isLastStep else {
            completeTutorial()
            return
        }

        currentIndex += 1
    }

    private func moveBackward() {
        guard !isFirstStep else { return }
        currentIndex -= 1
    }

    private func completeTutorial() {
        onFinish()
    }
}

private enum TutorialStep: CaseIterable {
    case timerWater
    case timerDepart
    case rewards
    case aquariumGacha
    case collection
    case profileRecords

    var kind: TutorialStepKind {
        switch self {
        case .timerWater: return .timerWater
        case .timerDepart: return .timerDepart
        case .rewards: return .rewards
        case .aquariumGacha: return .aquariumGacha
        case .collection: return .collection
        case .profileRecords: return .profileRecords
        }
    }

    var tab: AppTab {
        switch self {
        case .timerWater, .timerDepart, .rewards:
            return .timer
        case .aquariumGacha:
            return .aquarium
        case .collection:
            return .collection
        case .profileRecords:
            return .profile
        }
    }

    var icon: String {
        switch self {
        case .timerWater:
            return "drop.fill"
        case .timerDepart:
            return "figure.walk.departure"
        case .rewards:
            return "gift.fill"
        case .aquariumGacha:
            return FeedIcon.systemName
        case .collection:
            return "book.closed.fill"
        case .profileRecords:
            return "calendar"
        }
    }

    var title: String { L10n.Tutorial.stepTitle(kind) }

    var message: String { L10n.Tutorial.stepMessage(kind) }

    var tint: Color {
        switch self {
        case .timerWater:
            return Color.dewBlue
        case .timerDepart:
            return .cyan
        case .rewards:
            return .teal
        case .aquariumGacha:
            return .yellow
        case .collection:
            return .purple
        case .profileRecords:
            return .orange
        }
    }
}

private struct TutorialPrimaryButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .padding(.vertical, 13)
            .background(tint.opacity(configuration.isPressed ? 0.78 : 1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.78), value: configuration.isPressed)
    }
}

private struct TutorialSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.primary)
            .padding(.vertical, 13)
            .background(Color.secondary.opacity(configuration.isPressed ? 0.18 : 0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.78), value: configuration.isPressed)
    }
}

#Preview {
    TutorialOverlayView(selectedTab: .constant(.timer), onFinish: {})
        .environment(AppDataStore())
}
