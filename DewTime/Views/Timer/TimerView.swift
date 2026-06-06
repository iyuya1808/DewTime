import SwiftUI
import StoreKit

struct TimerView: View {
    @Environment(AppDataStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview

    @State private var viewModel: TimerViewModel?
    @State private var showConfirm = false
    @State private var showResult = false
    @State private var showCancelConfirm = false
    @State private var showStartSheet = false
    @State private var showFishPicker = false

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            if let vm = viewModel {
                mainContent(vm: vm)
            } else {
                emptyState
            }
        }
        .onAppear {
            ensureViewModel()
            viewModel?.syncActiveFish(store.activeFishes)
        }
        .onChange(of: activeSchedule?.id) { _, _ in
            viewModel = nil
            ensureViewModel()
            viewModel?.syncActiveFish(store.activeFishes)
        }
        .onChange(of: store.activeFishes.map(\.id)) { _, _ in
            viewModel?.syncActiveFish(store.activeFishes)
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
                    selectedSpecies: vm.selectedSpecies,
                    waterAmount: vm.currentWaterAmount,
                    totalWaterBefore: vm.currentReceivedWater,
                    totalWaterAfter: vm.projectedTotalWater,
                    requiredTotalWater: vm.currentRequiredTotalWater,
                    growthStage: vm.projectedGrowthStage,
                    completesGrowth: vm.meetsSelectedRequirement,
                    onConfirm: {
                        Task {
                            await vm.depart(store: store)
                            showConfirm = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showResult = true
                            }
                        }
                    },
                    onCancel: { showConfirm = false }
                )
                .presentationDetents([.fraction(0.75), .large])
                .presentationBackground(.clear)
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showStartSheet) {
            if let vm = viewModel {
                StartSheet(
                    scheduleName: vm.schedule.name,
                    currentTime: DepartureTimeDefaults.fifteenMinutesFromNow(),
                    selectedSpecies: vm.selectedSpecies,
                    aquariumTier: currentAquariumTier,
                    onSelectSpecies: { species in
                        Task { await vm.selectSpecies(species, store: store) }
                    },
                    onStart: { newTime in
                        vm.updateDepartureTime(newTime)
                        Task {
                            await store.saveAll()
                            vm.start()
                            showStartSheet = false
                        }
                    },
                    onCancel: { showStartSheet = false }
                )
                .presentationDetents([.fraction(0.88), .large])
                .presentationBackground(.clear)
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(32)
            }
        }
        .sheet(isPresented: $showResult, onDismiss: {
            ReviewRequestManager.shared.tryRequest(for: .departureResult) { requestReview() }
        }) {
            if let vm = viewModel {
                DepartureResultView(
                    waterLevel: vm.finalWaterLevel,
                    elapsedFormatted: vm.elapsedFormatted,
                    totalSeconds: max(1, Int(vm.schedule.targetDepartureTime.timeIntervalSince(vm.startedAt ?? .now))),
                    delaySeconds: vm.finalDelaySeconds,
                    scheduleName: vm.schedule.name,
                    selectedSpecies: vm.selectedSpecies,
                    waterAmount: vm.finalWaterAmount,
                    totalWaterAfter: vm.finalTotalWaterAfter,
                    requiredTotalWater: vm.finalRequiredTotalWater,
                    growthStage: vm.finalGrowthStage,
                    completedGrowth: vm.finalCompletedGrowth,
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
        .sheet(isPresented: $showFishPicker) {
            if let vm = viewModel {
                FishPickerSheet(
                    selectedSpecies: vm.selectedSpecies,
                    aquariumTier: currentAquariumTier,
                    onSelect: { species in
                        Task {
                            await vm.selectSpecies(species, store: store)
                            showFishPicker = false
                        }
                    }
                )
                .presentationDetents([.fraction(0.72), .large])
                .presentationBackground(.clear)
                .presentationDragIndicator(.hidden)
            }
        }
    }

    // MARK: - Main layout

    @ViewBuilder
    private func mainContent(vm: TimerViewModel) -> some View {
        ZStack {
            WaterTankView(
                waterLevel: vm.waterLevel,
                isOverdue: vm.isOverdue,
                cornerRadius: 0,
                showBorder: false,
                showLevelText: false,
                startDate: vm.isRunning ? vm.startedAt : nil,
                targetDate: vm.isRunning ? vm.schedule.targetDepartureTime : nil
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 72)

                centerInfoDisplay(vm: vm)

                Spacer()

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

    private func fishSelectionCard(vm: TimerViewModel, isEditable: Bool) -> some View {
        Button {
            if isEditable { showFishPicker = true }
        } label: {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(fishStatusColor(vm: vm).opacity(0.18))
                        Text(vm.selectedSpecies.emoji)
                            .font(.system(size: isEditable ? 30 : 22))
                    }
                    .frame(width: isEditable ? 54 : 42, height: isEditable ? 54 : 42)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("今日育てる魚")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.68))
                        Text(vm.selectedSpecies.displayName)
                            .font(isEditable ? .headline : .subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(vm.hasActiveFish ? vm.currentGrowthStage.message : "魚を選んで育てましょう")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.54))
                            .lineLimit(1)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text("育成水量")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.52))
                        Text("\(Int(vm.currentReceivedWater.rounded()))/\(Int(vm.currentRequiredTotalWater.rounded()))pt")
                            .font(.subheadline.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    }

                    if isEditable {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }

                progressBar(value: vm.growthProgress, color: fishStatusColor(vm: vm), trackOpacity: 0.14)

                HStack {
                    Label(vm.currentGrowthStage.displayName, systemImage: vm.currentGrowthStage.icon)
                    Spacer()
                    Text(vm.meetsSelectedRequirement ? "今回で成魚に" : "今回 +\(Int(vm.currentWaterAmount.rounded()))pt")
                        .monospacedDigit()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(fishStatusColor(vm: vm).opacity(0.92))
            }
            .padding(.horizontal, isEditable ? 18 : 14)
            .padding(.vertical, isEditable ? 16 : 12)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: isEditable ? 20 : 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: isEditable ? 20 : 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(DepartureCardButtonStyle())
        .disabled(!isEditable)
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

                progressBar(value: vm.currentRoutineProgress, color: Color(hex: currentItem.colorHex), trackOpacity: 0.16)
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

    private func progressBar(value: Double, color: Color, trackOpacity: Double) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(trackOpacity))
                Capsule()
                    .fill(color)
                    .frame(width: proxy.size.width * max(0, min(1, value)))
                    .animation(.linear(duration: 1.0), value: value)
            }
        }
        .frame(height: 4)
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

    private func fishStatusColor(vm: TimerViewModel) -> Color {
        vm.projectedGrowthStage == .adult ? WaterLevelTheme(waterRatio: vm.waterLevel).tintColor : .orange
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
        store.activeSchedule
    }

    private var currentAquariumTier: Int {
        store.aquariums.first?.sizeTier ?? 0
    }

    private func ensureViewModel() {
        guard viewModel == nil, let schedule = activeSchedule else { return }
        viewModel = TimerViewModel(schedule: schedule)
    }
}

struct FishPickerSheet: View {
    let selectedSpecies: FishSpecies
    let aquariumTier: Int
    let onSelect: (FishSpecies) -> Void

    var body: some View {
        ZStack {
            LinearGradient.dewTimeSheet
                .ignoresSafeArea()

            // オーロラグロー
            ZStack {
                Circle()
                    .fill(Color(hex: "#52D9A4").opacity(0.10))
                    .frame(width: 280, height: 280)
                    .blur(radius: 65)
                    .offset(x: 80, y: -120)
                Circle()
                    .fill(Color(red: 0.48, green: 0.40, blue: 1.0).opacity(0.08))
                    .frame(width: 240, height: 240)
                    .blur(radius: 55)
                    .offset(x: -90, y: 50)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                DragHandle()
                    .padding(.top, 14)
                    .padding(.bottom, 16)

                // ヘッダー
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#52D9A4").opacity(0.28), Color(hex: "#34D399").opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36, height: 36)
                        Circle()
                            .strokeBorder(Color(hex: "#52D9A4").opacity(0.30), lineWidth: 1)
                            .frame(width: 36, height: 36)
                        Image(systemName: "fish.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color(hex: "#52D9A4"))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("今日育てる魚")
                            .font(AppFont.sheetTitle)
                        Text("難易度が高いほど多くの水が必要です")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.40))
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)

                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(FishSpecies.allCases.sorted { $0.requiredTotalWaterRange.lowerBound < $1.requiredTotalWaterRange.lowerBound }) { species in
                            let isUnlocked = species.isUnlocked(aquariumTier: aquariumTier)
                            Button {
                                if isUnlocked { onSelect(species) }
                            } label: {
                                fishRow(species, isUnlocked: isUnlocked)
                            }
                            .buttonStyle(.plain)
                            .disabled(!isUnlocked)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
        }
        .foregroundStyle(.white)
    }

    private func speciesAccentColor(_ species: FishSpecies) -> Color {
        switch species.difficultyLabel {
        case "かんたん":   return Color(hex: "#4ADE80")
        case "やさしい":   return Color(hex: "#34D399")
        case "ふつう":     return Color(hex: "#60A5FA")
        case "むずかしい": return Color(hex: "#A78BFA")
        default:           return Color(hex: "#F472B6")
        }
    }

    private func fishRow(_ species: FishSpecies, isUnlocked: Bool) -> some View {
        let isSelected = selectedSpecies == species
        let accent = isSelected ? Color.dewBlue : speciesAccentColor(species)

        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(accent.opacity(isUnlocked ? 0.18 : 0.08))
                    .frame(width: 52, height: 52)
                if isSelected {
                    Circle()
                        .strokeBorder(accent.opacity(0.45), lineWidth: 1.5)
                        .frame(width: 52, height: 52)
                }
                Text(species.emoji)
                    .font(.system(size: 26))
                    .opacity(isUnlocked ? 1 : 0.35)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(species.displayName)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(isUnlocked ? .white : .white.opacity(0.45))
                HStack(spacing: 6) {
                    Text(species.difficultyLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isUnlocked ? accent : .white.opacity(0.38))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background((isUnlocked ? accent.opacity(0.15) : .white.opacity(0.07)), in: Capsule())
                    Text(isUnlocked ? species.requiredTotalWaterRangeText : "\(species.requiredAquariumName)で解放")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.42))
                }
            }

            Spacer()

            Image(systemName: isUnlocked ? (isSelected ? "checkmark.circle.fill" : "circle") : "lock.fill")
                .font(.title3)
                .foregroundStyle(isSelected ? accent : .white.opacity(isUnlocked ? 0.22 : 0.34))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(isSelected ? accent.opacity(0.12) : Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    isSelected ? accent.opacity(0.50) : Color.white.opacity(0.08),
                    lineWidth: 1
                )
        )
        .shadow(color: isSelected ? accent.opacity(0.18) : .clear, radius: 10, y: 4)
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
        .environment(AppDataStore())
}
