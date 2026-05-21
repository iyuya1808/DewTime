import SwiftUI
import SwiftData

struct TimerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var schedules: [UserSchedule]

    @State private var viewModel: TimerViewModel?
    @State private var showConfirm = false
    @State private var showResult = false

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            if let vm = viewModel {
                mainContent(vm: vm)
            } else {
                emptyState
            }
        }
        .onAppear { ensureViewModel() }
        .onChange(of: activeSchedule?.id) { _, _ in
            viewModel = nil
            ensureViewModel()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel?.resume()
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
        .sheet(isPresented: $showConfirm) {
            if let vm = viewModel {
                DepartureConfirmView(
                    waterLevel: vm.waterLevel,
                    isOnTime: !vm.isOverdue,
                    onConfirm: {
                        vm.depart(context: modelContext)
                        showConfirm = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showResult = true
                        }
                    },
                    onCancel: { showConfirm = false }
                )
                .presentationDetents([.medium])
                .presentationBackground(.clear)
                .presentationDragIndicator(.hidden)
            }
        }
        .sheet(isPresented: $showResult) {
            if let vm = viewModel {
                DepartureResultView(
                    waterLevel: vm.finalWaterLevel,
                    elapsedFormatted: vm.elapsedFormatted,
                    totalSeconds: max(1, Int(vm.schedule.targetDepartureTime.timeIntervalSince(vm.startedAt ?? .now))),
                    delaySeconds: vm.finalDelaySeconds,
                    scheduleName: vm.schedule.name,
                    onDismiss: {
                        showResult = false
                        vm.reset()
                    }
                )
                .presentationDetents([.large])
                .presentationBackground(.clear)
                .presentationDragIndicator(.hidden)
                .interactiveDismissDisabled()
            }
        }
    }

    // MARK: - Main layout

    @ViewBuilder
    private func mainContent(vm: TimerViewModel) -> some View {
        VStack(spacing: 0) {
            // 出発時刻ヘッダー
            departureHeader(vm: vm)
                .padding(.top, 12)

            // カウントダウン
            countdownSection(vm: vm)
                .padding(.top, 8)

            // 水タンク
            WaterTankView(waterLevel: vm.waterLevel, isOverdue: vm.isOverdue)
                .frame(maxWidth: 180)
                .aspectRatio(0.5, contentMode: .fit)
                .shadow(color: .black.opacity(0.3), radius: 16, y: 8)
                .padding(.top, 20)

            // ステータスラベル
            statusLabel(vm: vm)
                .padding(.top, 16)

            Spacer()

            // ボタン
            actionButton(vm: vm)
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
        }
        .foregroundStyle(.white)
    }

    // MARK: - Sub views

    private func departureHeader(vm: TimerViewModel) -> some View {
        VStack(spacing: 3) {
            Text(vm.schedule.name)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.45))
                .textCase(.uppercase)
                .tracking(1.2)
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Image(systemName: "figure.walk.departure")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.55))
                Text(vm.schedule.targetDepartureTime, format: .dateTime.hour().minute())
                    .font(AppFont.departureTime)
                    .monospacedDigit()
            }
        }
    }

    @ViewBuilder
    private func countdownSection(vm: TimerViewModel) -> some View {
        VStack(spacing: 4) {
            if !vm.isRunning && !vm.departed {
                Text("準備ができたらスタート")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
                Text(vm.countdownText)
                    .font(AppFont.countdownSmall)
                    .foregroundStyle(.white.opacity(0.55))
                    .monospacedDigit()
            } else if vm.departed {
                Text("出発完了 🎉")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.7))
            } else if vm.isOverdue {
                Text("出発時刻を過ぎています")
                    .font(.caption)
                    .foregroundStyle(.orange.opacity(0.85))
                Text(vm.countdownText)
                    .font(AppFont.countdown)
                    .foregroundStyle(.orange)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.linear(duration: 1.0), value: vm.countdownText)
            } else {
                Text("出発まで")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
                Text(vm.countdownText)
                    .font(AppFont.countdown)
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.linear(duration: 1.0), value: vm.countdownText)
            }
        }
    }

    @ViewBuilder
    private func statusLabel(vm: TimerViewModel) -> some View {
        if vm.isRunning {
            let level = vm.waterLevel
            let (text, color) = statusInfo(level: level, overdue: vm.isOverdue)
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)
                Text(text)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(color)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(color.opacity(0.12), in: Capsule())
        }
    }

    private func statusInfo(level: Double, overdue: Bool) -> (String, Color) {
        if overdue { return ("遅刻中… 早く出発して！", .orange) }
        let color = WaterLevelTheme(waterRatio: level).tintColor
        if level > 0.6 { return ("余裕あり ✨", color) }
        if level > 0.3 { return ("そろそろ準備を 🏃", color) }
        return ("急いで！ もうすぐ出発時刻", color)
    }

    @ViewBuilder
    private func actionButton(vm: TimerViewModel) -> some View {
        if vm.departed {
            EmptyView()
        } else if vm.startedAt == nil {
            Button { vm.start() } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                    Text("スタート")
                        .font(AppFont.actionButton)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    LinearGradient(
                        colors: [.dewBlue, .dewNavy],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: Color.dewBlue.opacity(0.4), radius: 12, y: 5)
            }
        } else {
            Button { showConfirm = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "figure.walk.departure")
                    Text("いってきます！")
                        .font(AppFont.actionButton)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    LinearGradient(
                        colors: departureBtnColors(vm.waterLevel),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: departureBtnColors(vm.waterLevel).first!.opacity(0.4), radius: 12, y: 5)
            }
        }
    }

    private func departureBtnColors(_ level: Double) -> [Color] {
        WaterLevelTheme(waterRatio: level).gradientColors
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(AppFont.countdown)
                .foregroundStyle(Color.dewBlue.opacity(0.7))
            Text("出発時刻が設定されていません")
                .font(.headline)
            Text("「設定」タブから出発時刻を設定してください")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .foregroundStyle(.white)
    }

    // MARK: - Background

    private var background: some View {
        LinearGradient.dewTimeDark
    }

    // MARK: - Helpers

    private var activeSchedule: UserSchedule? {
        UserSchedule.active(in: schedules)
    }

    private func ensureViewModel() {
        guard viewModel == nil, let schedule = activeSchedule else { return }
        viewModel = TimerViewModel(schedule: schedule)
    }
}

#Preview {
    TimerView()
        .modelContainer(for: [UserSchedule.self, RoutineItem.self, PlantFlower.self], inMemory: true)
}
