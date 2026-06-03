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
                    Button("スキップ") {
                        completeTutorial()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.14), in: Capsule())
                    .accessibilityHint("チュートリアルを閉じます")
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
                    .accessibilityLabel("\(steps.count)ページ中\(currentIndex + 1)ページ")
            }

            HStack(spacing: 10) {
                Button {
                    moveBackward()
                } label: {
                    Label("戻る", systemImage: "chevron.left")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(TutorialSecondaryButtonStyle())
                .disabled(isFirstStep)
                .opacity(isFirstStep ? 0.45 : 1)

                Button {
                    moveForward()
                } label: {
                    Label(isLastStep ? "はじめる" : "次へ", systemImage: isLastStep ? "checkmark" : "chevron.right")
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
    case timerOverview
    case timerFlow
    case collection
    case aquarium
    case profile

    var tab: AppTab {
        switch self {
        case .timerOverview, .timerFlow:
            return .timer
        case .collection:
            return .collection
        case .aquarium:
            return .aquarium
        case .profile:
            return .profile
        }
    }

    var icon: String {
        switch self {
        case .timerOverview:
            return "drop.fill"
        case .timerFlow:
            return "figure.walk.departure"
        case .collection:
            return "book.closed.fill"
        case .aquarium:
            return "fish.fill"
        case .profile:
            return "person.crop.circle.fill"
        }
    }

    var title: String {
        switch self {
        case .timerOverview:
            return "水を残す朝タイマー"
        case .timerFlow:
            return "出発すると魚が育ちます"
        case .collection:
            return "育った魚は図鑑へ"
        case .aquarium:
            return "水槽で魚を眺める"
        case .profile:
            return "記録と設定をあとから確認"
        }
    }

    var message: String {
        switch self {
        case .timerOverview:
            return "出発時刻までの余裕が水量として表示されます。準備が順調なほど水が残り、魚にあげられる水も増えます。"
        case .timerFlow:
            return "「スタート」で朝の準備を始めます。出発できたら「いってきます！」を押して、残った水を今日の魚に届けましょう。"
        case .collection:
            return "魚が成魚まで育つと図鑑に登録されます。育成中の進み具合や、まだ出会っていない魚の目安もここで確認できます。"
        case .aquarium:
            return "成魚になった魚は水槽で泳ぎます。水槽は毎日の水やりで少しずつ育ち、より大きな魚にも出会えるようになります。"
        case .profile:
            return "プロフィールでは水やりの記録や達成状況を確認できます。スケジュール変更やチュートリアルの再表示は設定から行えます。"
        }
    }

    var tint: Color {
        switch self {
        case .timerOverview:
            return Color.dewBlue
        case .timerFlow:
            return .cyan
        case .collection:
            return .purple
        case .aquarium:
            return .teal
        case .profile:
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
