import SwiftUI
import StoreKit

struct TimerView: View {
    @Environment(AppDataStore.self) private var store
    @Environment(QuickTimerDeepLinkRouter.self) private var deepLinkRouter
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview

    @State private var viewModel: TimerViewModel?
    @State private var showCancelConfirm = false
    @State private var showResult = false
    @State private var draftLevel: Double = 1.0
    @State private var didAttemptDepartureRecovery = false

    private var draftMinutes: Int { max(5, Int((draftLevel * 30).rounded())) }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            if let vm = viewModel {
                mainContent(vm: vm)
            }
        }
        .onAppear {
            ensureViewModel()
            handlePendingQuickTimerRequest()
            recoverDepartedSessionIfNeeded()
        }
        .onChange(of: deepLinkRouter.pendingRequest) { _, _ in
            handlePendingQuickTimerRequest()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel?.resume(store: store)
            } else {
                viewModel?.pause()
            }
        }
        .alert(
            "保存エラー",
            isPresented: Binding(get: { viewModel?.saveError != nil }, set: { _ in viewModel?.clearError() })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel?.saveError ?? "")
        }
        .sheet(isPresented: $showCancelConfirm) {
            if let vm = viewModel {
                TimerCancelConfirmView(
                    waterLevel: vm.waterLevel,
                    onReset: {
                        vm.reset()
                        showCancelConfirm = false
                    },
                    onContinue: { showCancelConfirm = false }
                )
                .presentationDetents([.height(340)])
                .presentationDragIndicator(.hidden)
            }
        }
        .sheet(isPresented: $showResult, onDismiss: {
            ReviewRequestManager.shared.tryRequest(for: .departureResult) { requestReview() }
        }) {
            if let vm = viewModel {
                DepartureResultView(
                    earnedDrop: vm.finalEarnedDrop,
                    bonusFeedAwarded: vm.finalBonusFeedAwarded,
                    delaySeconds: vm.finalDelaySeconds,
                    onDismiss: {
                        showResult = false
                        vm.reset()
                    }
                )
                .presentationDetents([
                    .height(DepartureResultView.preferredDetentHeight(
                        bonusFeedAwarded: vm.finalBonusFeedAwarded,
                        hasDelay: vm.finalDelaySeconds > 0
                    ))
                ])
                .presentationDragIndicator(.hidden)
                .interactiveDismissDisabled()
            }
        }
    }

    // MARK: - Main layout

    @ViewBuilder
    private func mainContent(vm: TimerViewModel) -> some View {
        let isIdle = vm.startedAt == nil && !vm.departed
        let displayLevel = isIdle ? draftLevel : vm.waterLevel
        ZStack {
            WaterTankView(
                waterLevel: displayLevel,
                isOverdue: false,
                cornerRadius: 0,
                showBorder: false,
                startDate: vm.isRunning ? vm.startedAt : nil,
                targetDate: vm.isRunning ? vm.targetDepartureTime : nil,
                initialWaterLevel: vm.isRunning ? vm.initialWaterLevel : 1.0,
                isDraggable: isIdle,
                onLevelChanged: isIdle ? { newLevel in draftLevel = newLevel } : nil
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 72)

                centerInfoDisplay(vm: vm, isIdle: isIdle)

                Spacer()

                if isIdle {
                    SluiceGateStartButton {
                        let departureDate = Date.now.addingTimeInterval(TimeInterval(draftMinutes * 60))
                        vm.updateDepartureTime(departureDate)
                        vm.start(initialLevel: draftLevel)
                    }
                    .padding(.bottom, 24)
                    .transition(.opacity)
                } else if !vm.departed {
                    departureBottomButton(vm: vm)
                        .padding(.bottom, 24)
                        .transition(.opacity)
                }
            }
            .foregroundStyle(.white)
            .animation(.easeInOut(duration: 0.3), value: isIdle)
        }
    }

    @ViewBuilder
    private func centerInfoDisplay(vm: TimerViewModel, isIdle: Bool = false) -> some View {
        ZStack {
            if vm.departed {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.white.opacity(0.85))
                    .transition(.opacity)
            } else if isIdle {
                VStack(spacing: 0) {
                    Image(systemName: "hand.draw.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.white.opacity(0.45))
                    Text("スワイプで時間を設定")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.45))
                        .padding(.top, 4)

                    HStack(alignment: .bottom, spacing: 4) {
                        Text("\(draftMinutes)")
                            .font(.system(size: 88, weight: .ultraLight, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.85))
                            .contentTransition(.numericText())
                            .animation(.interactiveSpring(), value: draftMinutes)
                        Text("分")
                            .font(.system(size: 28, weight: .light, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                            .padding(.bottom, 24)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 18)
                    .accessibilityLabel("\(draftMinutes)分")
                }
                .transition(.opacity)
            } else {
                VStack(spacing: 0) {
                    Image(systemName: vm.isOverdue ? "exclamationmark.triangle.fill" : "figure.walk")
                        .font(.system(size: 22))
                        .foregroundStyle(vm.isOverdue ? Color.orange.opacity(0.9) : Color.white.opacity(0.55))

                    Text(vm.countdownText)
                        .font(.system(size: 88, weight: .ultraLight, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(vm.isOverdue ? Color.orange : Color.white.opacity(1.0))
                        .contentTransition(vm.isOverdue ? .numericText() : .numericText(countsDown: true))
                        .animation(.linear(duration: 1.0), value: vm.countdownText)
                        .padding(.top, 8)
                        .padding(.bottom, 18)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: isIdle)
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    }

    private func departureBottomButton(vm: TimerViewModel) -> some View {
        HStack(spacing: 20) {
            Button { showCancelConfirm = true } label: {
                Label("キャンセル", systemImage: "xmark.circle")
                    .font(.subheadline.weight(.semibold))
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(width: 110, height: 52)
                    .background(.white.opacity(0.10), in: Capsule())
            }
            .disabled(vm.departed)
            .accessibilityLabel("キャンセル")

            Button { depart(vm: vm) } label: {
                Label("いってきます", systemImage: "figure.walk.departure")
                    .font(.headline.weight(.semibold))
                    .labelStyle(.titleAndIcon)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: departureBtnColors(vm.waterLevel),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .disabled(vm.departed)
            .accessibilityLabel("いってきます")
        }
        .padding(.horizontal, 28)
    }

    private func departureBtnColors(_ level: Double) -> [Color] {
        WaterLevelTheme(waterRatio: level).gradientColors
    }

    private func depart(vm: TimerViewModel) {
        guard !vm.departed else { return }
        Task {
            await vm.depart(store: store)
            showResult = true
        }
    }

    private var background: some View {
        LinearGradient.dewTimeDark
    }

    private func handlePendingQuickTimerRequest() {
        guard let request = deepLinkRouter.pendingRequest,
              let vm = viewModel,
              !vm.isRunning,
              !vm.departed else {
            return
        }

        let targetDate = Calendar.current.date(
            byAdding: .minute,
            value: request.minutes,
            to: .now
        ) ?? Date.now.addingTimeInterval(TimeInterval(request.minutes * 60))

        let quickLevel = min(1.0, Double(request.minutes) / 30.0)
        vm.updateDepartureTime(targetDate)
        vm.start(initialLevel: quickLevel)
        deepLinkRouter.consume(request)
    }

    private func ensureViewModel() {
        guard viewModel == nil else { return }
        let vm = TimerViewModel()
        vm.bindStore(store)
        viewModel = vm
        recoverDepartedSessionIfNeeded()
    }

    private func recoverDepartedSessionIfNeeded() {
        guard let vm = viewModel,
              vm.departed,
              !showResult,
              !didAttemptDepartureRecovery else { return }
        didAttemptDepartureRecovery = true
        Task {
            await vm.recoverDepartedSession(store: store)
            if vm.departed {
                showResult = true
            }
        }
    }
}

#Preview {
    TimerView()
        .environment(AppDataStore())
        .environment(QuickTimerDeepLinkRouter())
}
