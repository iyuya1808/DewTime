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
    case timerWater
    case timerDepart
    case rewards
    case aquariumGacha
    case collection
    case profileRecords

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

    var title: String {
        switch self {
        case .timerWater:
            return "水で時間がわかる"
        case .timerDepart:
            return "出発で水槽へ届ける"
        case .rewards:
            return "しずくと餌"
        case .aquariumGacha:
            return "餌で仲間を増やす"
        case .collection:
            return "図鑑を埋めよう"
        case .profileRecords:
            return "記録と実績"
        }
    }

    var message: String {
        switch self {
        case .timerWater:
            return "タンクをスワイプして出発までの時間を設定します。水が多いほど余裕があり、準備が順調なほど水が残ります。"
        case .timerDepart:
            return "「スタート」で準備を始めます。時間内に「いってきます」を押すと、残った水を水槽へ届けられます。"
        case .rewards:
            return "オンタイム出発で「しずく +1」と「餌 +1」を獲得できます。しずくは水槽の成長に、餌は水槽タブで魚を呼び寄せるのに使います。遅刻すると報酬はありません。"
        case .aquariumGacha:
            return "水槽をタップして餌を落としましょう。魚が食べたタイミングで新しい仲間が誕生し、図鑑に登録されます。"
        case .collection:
            return "獲得した魚種は図鑑に記録されます。まだ出会っていない魚はシルエットで表示されます。水槽レベルが上がると、より珍しい魚が出現します。"
        case .profileRecords:
            return "出発記録をカレンダーで確認できます。実績を達成すると餌がもらえます。通知の変更は右上の歯車から行えます。"
        }
    }

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
