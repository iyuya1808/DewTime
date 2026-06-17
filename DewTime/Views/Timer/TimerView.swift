import SwiftUI
import StoreKit

struct TimerView: View {
    @Environment(AppDataStore.self) private var store
    @Environment(QuickTimerDeepLinkRouter.self) private var deepLinkRouter
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview

    @State private var viewModel: TimerViewModel?
    @State private var showConfirm = false
    @State private var showResult = false
    @State private var showCancelConfirm = false
    @State private var showFishPicker = false
    @State private var showFishNameEditor = false
    @State private var fishNameDraft = ""
    @State private var draftLevel: Double = 1.0

    private var draftMinutes: Int { max(5, Int((draftLevel * 30).rounded())) }

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
            handlePendingQuickTimerRequest()
        }
        .onChange(of: activeSchedule?.id) { _, _ in
            viewModel = nil
            ensureViewModel()
            viewModel?.syncActiveFish(store.activeFishes)
            handlePendingQuickTimerRequest()
        }
        .onChange(of: store.isLoading) { _, isLoading in
            if !isLoading {
                ensureViewModel()
                viewModel?.syncActiveFish(store.activeFishes)
            }
        }
        .onChange(of: store.activeFishes.map(\.id)) { _, _ in
            viewModel?.syncActiveFish(store.activeFishes)
        }
        .onChange(of: deepLinkRouter.pendingRequest) { _, _ in
            handlePendingQuickTimerRequest()
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
        .alert("魚の名前", isPresented: $showFishNameEditor) {
            TextField("名前", text: $fishNameDraft)
            Button("保存") {
                Task { await viewModel?.renameActiveFish(fishNameDraft, store: store) }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("空欄で保存すると種類名に戻ります。")
        }
        .sheet(isPresented: $showConfirm) {
            if let vm = viewModel {
                DepartureConfirmView(
                    waterLevel: vm.waterLevel,
                    isOnTime: !vm.isOverdue,
                    selectedSpecies: vm.selectedSpecies,
                    departuresBefore: vm.currentDepartures,
                    departuresAfter: vm.projectedDepartures,
                    requiredDepartures: vm.currentRequiredDepartures,
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
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
            }
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
                    waterLevel: vm.finalWaterLevel,
                    elapsedFormatted: vm.elapsedFormatted,
                    totalSeconds: max(1, Int(vm.schedule.targetDepartureTime.timeIntervalSince(vm.startedAt ?? .now))),
                    delaySeconds: vm.finalDelaySeconds,
                    scheduleName: vm.schedule.name,
                    selectedSpecies: vm.selectedSpecies,
                    earnedDrop: vm.finalEarnedDrop,
                    departuresAfter: vm.finalDeparturesAfter,
                    requiredDepartures: vm.currentRequiredDepartures,
                    growthStage: vm.finalGrowthStage,
                    completedGrowth: vm.finalCompletedGrowth,
                    onDismiss: {
                        showResult = false
                        vm.reset()
                    }
                )
                .presentationDetents([.large])
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
        let isIdle = vm.startedAt == nil && !vm.departed
        let displayLevel = isIdle ? draftLevel : vm.waterLevel
        ZStack {
            WaterTankView(
                waterLevel: displayLevel,
                isOverdue: vm.isOverdue,
                cornerRadius: 0,
                showBorder: false,
                startDate: vm.isRunning ? vm.startedAt : nil,
                targetDate: vm.isRunning ? vm.schedule.targetDepartureTime : nil,
                initialWaterLevel: vm.isRunning ? vm.initialWaterLevel : 1.0,
                isDraggable: isIdle,
                onLevelChanged: isIdle ? { newLevel in draftLevel = newLevel } : nil
            )
            .ignoresSafeArea()

            if !vm.departed {
                TimerFishOverlay(
                    species: vm.selectedSpecies,
                    waterLevel: displayLevel
                )
                .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                Spacer(minLength: 72)

                centerInfoDisplay(vm: vm, isIdle: isIdle)

                Spacer()

                // スタート済みなら出発ボタン、アイドルなら水滴ボタン
                if isIdle {
                    HStack(spacing: 16) {
                        // 前の魚
                        Button {
                            let allSpecies = FishSpecies.allCases
                            if let currentIndex = allSpecies.firstIndex(of: vm.selectedSpecies) {
                                let previousIndex = currentIndex == 0 ? allSpecies.count - 1 : currentIndex - 1
                                Task { await vm.selectSpecies(allSpecies[previousIndex], store: store) }
                            }
                        } label: {
                            fishSpeciesNavButtonIcon("chevron.left")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("前の魚")

                        Spacer()

                        // スタートボタン
                        SluiceGateStartButton {
                            let departureDate = Date.now.addingTimeInterval(TimeInterval(draftMinutes * 60))
                            vm.updateDepartureTime(departureDate)
                            vm.start(initialLevel: draftLevel)
                            Task { await store.saveAll() }
                        }

                        Spacer()

                        // 次の魚
                        Button {
                            let allSpecies = FishSpecies.allCases
                            if let currentIndex = allSpecies.firstIndex(of: vm.selectedSpecies) {
                                let nextIndex = (currentIndex + 1) % allSpecies.count
                                Task { await vm.selectSpecies(allSpecies[nextIndex], store: store) }
                            }
                        } label: {
                            fishSpeciesNavButtonIcon("chevron.right")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("次の魚")
                    }
                    .padding(.horizontal, 16)
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

    // MARK: - Sub views

    /// 未スタート時: 出発時刻を編集できる目立つカード（未使用）
    private func departureCard(vm: TimerViewModel) -> some View {
        Button {
            // no-op: StartSheet廃止のため
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
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(fishStatusColor(vm: vm).opacity(0.18))
                    FishArtworkView(species: vm.selectedSpecies)
                        .frame(width: isEditable ? 42 : 32, height: isEditable ? 38 : 30)
                }
                .frame(width: isEditable ? 54 : 42, height: isEditable ? 54 : 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text("今日育てる魚")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.68))
                    Text(vm.currentFishName)
                        .font(isEditable ? .headline : .subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(vm.hasActiveFish ? "\(vm.selectedSpecies.displayName)・\(vm.currentGrowthStage.message)" : "魚を選んで育てましょう")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.54))
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text("しずく")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.52))
                    Text("\(vm.currentDepartures)/\(vm.currentRequiredDepartures)")
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }

                if isEditable {
                    HStack(spacing: 8) {
                        Button {
                            fishNameDraft = vm.currentFishName
                            showFishNameEditor = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.82))
                                .frame(width: 32, height: 32)
                                .background(.white.opacity(0.14), in: Circle())
                                .overlay(Circle().strokeBorder(.white.opacity(0.22), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("魚の名前を編集")

                        Button {
                            showFishPicker = true
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.72))
                                .frame(width: 32, height: 32)
                                .background(.white.opacity(0.10), in: Circle())
                                .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("育てる魚を変更")
                    }
                }
            }

            progressBar(value: vm.growthProgress, color: fishStatusColor(vm: vm), trackOpacity: 0.14)

            HStack {
                Label(vm.currentGrowthStage.displayName, systemImage: vm.currentGrowthStage.icon)
                Spacer()
                Text(vm.meetsSelectedRequirement ? "今回で成魚に" : (vm.isOverdue ? "しずく +0" : "しずく +1"))
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

    private func departureBottomButton(vm: TimerViewModel) -> some View {
        HStack(spacing: 20) {
            Button { showCancelConfirm = true } label: {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(width: 52, height: 52)
                    .background(.white.opacity(0.10), in: Circle())
            }
            .accessibilityLabel("キャンセル")

            Button { showConfirm = true } label: {
                Image(systemName: "figure.walk.departure")
                    .font(.system(size: 28, weight: .semibold))
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
            .accessibilityLabel("いってきます")
        }
        .padding(.horizontal, 28)
    }

    @ViewBuilder
    private func actionButton(vm: TimerViewModel) -> some View {
        if vm.departed {
            EmptyView()
        } else {
            VStack(spacing: 16) {
                Button { showConfirm = true } label: {
                    Image(systemName: "figure.walk.departure")
                        .font(.system(size: 40, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 22)
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
                .accessibilityLabel("いってきます")

                Button { showCancelConfirm = true } label: {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .accessibilityLabel("キャンセル")
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
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 52))
                .foregroundStyle(Color.dewBlue.opacity(0.7))
            Image(systemName: "arrow.down")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.35))
        }
        .foregroundStyle(.white)
        .accessibilityLabel("「設定」タブから出発時刻を設定してください")
    }

    // MARK: - Background

    private var background: some View {
        LinearGradient.dewTimeDark
    }

    // MARK: - Helpers

    private func fishSpeciesNavButtonIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 56, height: 56)
            .background(Color.black.opacity(0.22), in: Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.55), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
    }

    private var activeSchedule: UserSchedule? {
        store.activeSchedule
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
        Task {
            await store.saveAll()
            vm.start(initialLevel: quickLevel)
            deepLinkRouter.consume(request)
        }
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
                    Text("今日育てる魚")
                        .font(AppFont.sheetTitle)
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)

                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(FishSpecies.allCases.sorted { $0.requiredDepartures < $1.requiredDepartures }) { species in
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

    private func difficultyIconName(for label: String) -> String {
        switch label {
        case "かんたん":   return "1.circle.fill"
        case "やさしい":   return "2.circle.fill"
        case "ふつう":     return "3.circle.fill"
        default:           return "4.circle.fill"
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
                FishArtworkView(
                    species: species,
                    tint: isUnlocked ? nil : .secondary,
                    isLocked: !isUnlocked
                )
                .frame(width: 38, height: 34)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(species.displayName)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(isUnlocked ? .white : .white.opacity(0.45))
                HStack(spacing: 6) {
                    Image(systemName: difficultyIconName(for: species.difficultyLabel))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isUnlocked ? accent : .white.opacity(0.38))
                    if isUnlocked {
                        Text(species.requiredDeparturesText)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.42))
                    }
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
