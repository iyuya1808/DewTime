import SwiftUI
import SwiftData

struct TimerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var schedules: [UserSchedule]

    @State private var viewModel: TimerViewModel?
    @State private var showConfirm = false
    @State private var showResult = false
    @State private var showCancelConfirm = false
    @State private var showStartSheet = false

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
        .alert("タイマーをキャンセルしますか？", isPresented: $showCancelConfirm) {
            Button("キャンセルする", role: .destructive) { viewModel?.reset() }
            Button("続ける", role: .cancel) {}
        } message: {
            Text("タイマーをリセットして最初の状態に戻ります。")
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
        .sheet(isPresented: $showStartSheet) {
            if let vm = viewModel {
                StartSheet(
                    scheduleName: vm.schedule.name,
                    currentTime: vm.schedule.targetDepartureTime,
                    onStart: { newTime in
                        vm.updateDepartureTime(newTime)
                        try? modelContext.save()
                        vm.start()
                        showStartSheet = false
                    },
                    onCancel: { showStartSheet = false }
                )
                .presentationDetents([.fraction(0.88)])
                .presentationBackground(.clear)
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(32)
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
        ZStack {
            WaterTankView(
                waterLevel: vm.waterLevel,
                routineItems: vm.schedule.orderedItems,
                activeRoutineItemID: vm.currentRoutineItem?.id,
                isOverdue: vm.isOverdue,
                cornerRadius: 0,
                showBorder: false,
                showLevelText: false
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // トップ: 出発時刻カード or コンパクトヘッダー
                Group {
                    if !vm.isRunning && !vm.departed {
                        departureCard(vm: vm)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                    } else {
                        compactDepartureHeader(vm: vm)
                            .padding(.top, 16)
                    }
                }

                Spacer()

                // センター: カウントダウン + %
                centerInfoDisplay(vm: vm)

                Spacer()

                // ボトム: ステータス + ボタン
                currentTaskPanel(vm: vm)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)

                statusLabel(vm: vm)
                    .padding(.bottom, 12)

                actionButton(vm: vm)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 28)
            }
            .foregroundStyle(.white)
        }
    }

    // MARK: - Sub views

    /// 未スタート時: 出発時刻を編集できる目立つカード
    private func departureCard(vm: TimerViewModel) -> some View {
        Button {
            showStartSheet = true
        } label: {
            VStack(spacing: 12) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("出発時刻")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .textCase(.uppercase)
                            .tracking(1.0)
                        Text(vm.schedule.name)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    Spacer()
                    HStack(spacing: 5) {
                        Image(systemName: "pencil")
                            .font(.caption.weight(.bold))
                        Text("変更")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.15), in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1))
                }

                HStack(alignment: .lastTextBaseline, spacing: 10) {
                    Image(systemName: "figure.walk.departure")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.85))
                    Text(vm.schedule.targetDepartureTime, format: .dateTime.hour().minute())
                        .font(AppFont.departureTime)
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Spacer()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(DepartureCardButtonStyle())
    }

    /// 実行中 / 完了時: コンパクトな中央揃えヘッダー
    private func compactDepartureHeader(vm: TimerViewModel) -> some View {
        VStack(spacing: 3) {
            Text(vm.schedule.name)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
                .textCase(.uppercase)
                .tracking(1.2)
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Image(systemName: "figure.walk.departure")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.8))
                Text(vm.schedule.targetDepartureTime, format: .dateTime.hour().minute())
                    .font(AppFont.departureTime)
                    .monospacedDigit()
            }
        }
    }

    @ViewBuilder
    private func centerInfoDisplay(vm: TimerViewModel) -> some View {
        VStack(spacing: 0) {
            if vm.departed {
                // 出発完了
                Text("出発完了 🎉")
                    .font(.system(.title3, design: .rounded).weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.bottom, 20)
            } else {
                // ラベル
                Text(vm.isOverdue ? "遅刻中" : "出発まで")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .tracking(3)
                    .textCase(.uppercase)
                    .foregroundStyle(vm.isOverdue ? Color.orange.opacity(0.9) : Color.white.opacity(0.55))

                // カウントダウン（ヒーロー数字）
                Text(vm.countdownText)
                    .font(.system(size: 88, weight: .ultraLight, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(vm.isOverdue ? Color.orange : Color.white.opacity(vm.isRunning ? 1.0 : 0.7))
                    .contentTransition(vm.isOverdue ? .numericText() : .numericText(countsDown: true))
                    .animation(.linear(duration: 1.0), value: vm.countdownText)
                    .padding(.top, 8)

                // ドット区切り
                HStack(spacing: 5) {
                    ForEach(0..<5, id: \.self) { _ in
                        Circle()
                            .fill(.white.opacity(0.25))
                            .frame(width: 3.5, height: 3.5)
                    }
                }
                .padding(.vertical, 18)
            }

            // % サブ表示
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text("\(Int(vm.waterLevel * 100))")
                    .font(.system(size: 44, weight: .thin, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.linear(duration: 1.0), value: vm.waterLevel)
                Text("%")
                    .font(.system(size: 22, weight: .thin, design: .rounded))
                    .padding(.bottom, 4)
            }
            .foregroundStyle(vm.isOverdue ? Color.orange.opacity(0.7) : Color.white.opacity(0.6))
        }
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    }

    @ViewBuilder
    private func currentTaskPanel(vm: TimerViewModel) -> some View {
        if vm.isRunning, let currentItem = vm.currentRoutineItem {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color(hex: currentItem.colorHex))
                        .frame(width: 10, height: 10)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(currentItem.name)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        if let next = vm.nextRoutineItem {
                            Text("次: \(next.name)")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.55))
                                .lineLimit(1)
                        } else {
                            Text("最後の準備")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.55))
                        }
                    }

                    Spacer()

                    Text(vm.currentRoutineRemainingText)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.8))
                }

                ProgressView(value: vm.currentRoutineProgress)
                    .tint(Color(hex: currentItem.colorHex))
                    .background(.white.opacity(0.16), in: Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.14), lineWidth: 1)
            )
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
            Button { showStartSheet = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                    Text("スタート")
                        .font(AppFont.actionButton)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color.dewBlue)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: Color.dewBlue.opacity(0.4), radius: 12, y: 5)
            }
        } else {
            VStack(spacing: 12) {
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

                Button { showCancelConfirm = true } label: {
                    Text("キャンセル")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.65))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
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

// MARK: - ButtonStyle

private struct DepartureCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview {
    TimerView()
        .modelContainer(for: [UserSchedule.self, RoutineItem.self, PlantFlower.self], inMemory: true)
}
