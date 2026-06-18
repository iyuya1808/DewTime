import SwiftUI
import StoreKit

struct TimerView: View {
    @Environment(AppDataStore.self) private var store
    @Environment(QuickTimerDeepLinkRouter.self) private var deepLinkRouter
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview

    @State private var viewModel: TimerViewModel?
    @State private var showCancelConfirm = false
    @State private var showDepartureConfirm = false
    @State private var rewardBurst: DepartureRewardBurst?
    @State private var draftLevel: Double = 1.0
    @State private var didAttemptDepartureRecovery = false

    private struct DepartureRewardBurst: Identifiable {
        let id = UUID()
        let bonusFeedAwarded: Bool
    }

    private var draftMinutes: Int { max(5, Int((draftLevel * 30).rounded())) }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            if let vm = viewModel {
                mainContent(vm: vm)
            }

            if let burst = rewardBurst {
                DepartureRewardBurstView(bonusFeedAwarded: burst.bonusFeedAwarded) {
                    rewardBurst = nil
                    ReviewRequestManager.shared.tryRequest(for: .departureResult) { requestReview() }
                }
                .transition(.opacity)
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
        .onReceive(NotificationCenter.default.publisher(for: LocalizationManager.languageDidChangeNotification)) { _ in
            viewModel?.handleLanguageChange()
        }
        .alert(
            L10n.Common.saveError,
            isPresented: Binding(get: { viewModel?.saveError != nil }, set: { _ in viewModel?.clearError() })
        ) {
            Button(L10n.Common.ok, role: .cancel) {}
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
        .sheet(isPresented: $showDepartureConfirm) {
            if let vm = viewModel {
                let aquarium = vm.aquariumSnapshot(from: store)
                let departuresAfter = vm.projectedAquariumDepartures(from: store)
                let tierAfter = Aquarium(totalDepartures: departuresAfter).sizeTier
                DepartureConfirmView(
                    isOnTime: !vm.isOverdue,
                    tierWillGrow: tierAfter > aquarium.sizeTier,
                    bonusFeedWillAward: !vm.isOverdue,
                    onConfirm: {
                        showDepartureConfirm = false
                        depart(vm: vm)
                    },
                    onCancel: { showDepartureConfirm = false }
                )
                .presentationDetents([
                    .height(DepartureConfirmView.preferredDetentHeight(tierWillGrow: tierAfter > aquarium.sizeTier))
                ])
                .presentationDragIndicator(.hidden)
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
            if isIdle {
                VStack(spacing: 0) {
                    Image(systemName: "hand.draw.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.white.opacity(0.45))
                    Text(L10n.Timer.swipeToSet)
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
                        Text(L10n.Timer.minutesUnit)
                            .font(.system(size: 28, weight: .light, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                            .padding(.bottom, 24)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 18)
                    .accessibilityLabel(L10n.Timer.minutes(draftMinutes))
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
                Label(L10n.Timer.cancel, systemImage: "xmark.circle")
                    .font(.subheadline.weight(.semibold))
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(width: 110, height: 52)
                    .background(.white.opacity(0.10), in: Capsule())
            }
            .disabled(vm.departed)
            .accessibilityLabel(L10n.Timer.cancel)

            Button { showDepartureConfirm = true } label: {
                Label(L10n.Timer.depart, systemImage: "figure.walk.departure")
                    .font(.headline.weight(.semibold))
                    .labelStyle(.titleAndIcon)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.dewBlue, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .disabled(vm.departed)
            .accessibilityLabel(L10n.Timer.depart)
        }
        .padding(.horizontal, 28)
    }

    private func depart(vm: TimerViewModel) {
        guard !vm.departed else { return }
        vm.finalizeDeparture(store: store)
        let earnedDrop = vm.finalEarnedDrop
        let bonusFeed = vm.finalBonusFeedAwarded

        vm.reset()
        if earnedDrop {
            rewardBurst = DepartureRewardBurst(bonusFeedAwarded: bonusFeed)
        }

        Task {
            await store.recordDeparture(earnedDrop: earnedDrop)
            await MainActor.run {
                if store.errorMessage != nil {
                    viewModel?.reportSaveError(L10n.Timer.saveFailed)
                }
            }
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
              !didAttemptDepartureRecovery else { return }
        didAttemptDepartureRecovery = true
        Task {
            await vm.recoverDepartedSession(store: store)
            await MainActor.run {
                vm.reset()
            }
        }
    }
}

#Preview {
    TimerView()
        .environment(AppDataStore())
        .environment(QuickTimerDeepLinkRouter())
}
