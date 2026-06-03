import Foundation
import Observation

@Observable
@MainActor
final class TimerViewModel {
    private(set) var schedule: UserSchedule
    private(set) var startedAt: Date?
    private(set) var now: Date = .now
    private(set) var departed: Bool = false
    private(set) var finalWaterLevel: Double = 1.0
    private(set) var finalDelaySeconds: Int = 0
    private(set) var saveError: String?
    private(set) var selectedSpecies: FishSpecies
    private(set) var activeFish: ActiveFish?
    private(set) var finalWaterAmount: Double = 0
    private(set) var finalTotalWaterAfter: Double = 0
    private(set) var finalRequiredTotalWater: Double = 1
    private(set) var finalGrowthStage: GrowthStage = .egg
    private(set) var finalCompletedGrowth: Bool = false

    private var timer: Timer?
    private var lastRoutineItemID: UUID?
    private var lastLiveActivityUpdate: Date?
    private var didPlayOverdueWarning = false

    init(schedule: UserSchedule) {
        self.schedule = schedule
        self.selectedSpecies = Self.restoreSelectedSpecies()
        restoreState()
        lastRoutineItemID = currentRoutineItem?.id
        didPlayOverdueWarning = isOverdue
    }

    // MARK: - Derived state

    var remainingSeconds: Int {
        let target = schedule.targetDepartureTime
        let base: Date = startedAt != nil ? now : .now
        return max(0, Int(target.timeIntervalSince(base)))
    }

    var overdueSeconds: Int {
        guard startedAt != nil else { return 0 }
        return max(0, Int(now.timeIntervalSince(schedule.targetDepartureTime)))
    }

    var isOverdue: Bool { overdueSeconds > 0 }

    var waterLevel: Double {
        if departed { return finalWaterLevel }
        guard let startedAt else { return 1.0 }
        let total = schedule.targetDepartureTime.timeIntervalSince(startedAt)
        guard total > 0 else { return 0.0 }
        let remaining = schedule.targetDepartureTime.timeIntervalSince(now)
        return min(1.0, max(0.0, remaining / total))
    }

    var isRunning: Bool { startedAt != nil && !departed }

    var elapsedSeconds: Int {
        guard let startedAt else { return 0 }
        return max(0, Int(now.timeIntervalSince(startedAt)))
    }

    var currentRoutineItem: RoutineItem? {
        guard startedAt != nil, !departed, !schedule.orderedItems.isEmpty else { return nil }

        var accumulated = 0
        for item in schedule.orderedItems {
            accumulated += item.durationSeconds
            if elapsedSeconds < accumulated {
                return item
            }
        }
        return schedule.orderedItems.last
    }

    var nextRoutineItem: RoutineItem? {
        guard let currentRoutineItem else { return nil }
        let items = schedule.orderedItems
        guard let index = items.firstIndex(where: { $0.id == currentRoutineItem.id }),
              items.indices.contains(index + 1) else { return nil }
        return items[index + 1]
    }

    var currentRoutineProgress: Double {
        guard let currentRoutineItem else { return 0 }
        var elapsedBeforeCurrent = 0
        for item in schedule.orderedItems {
            if item.id == currentRoutineItem.id { break }
            elapsedBeforeCurrent += item.durationSeconds
        }
        let elapsedInCurrent = elapsedSeconds - elapsedBeforeCurrent
        return min(1.0, max(0.0, Double(elapsedInCurrent) / Double(currentRoutineItem.durationSeconds)))
    }

    var meetsSelectedRequirement: Bool {
        projectedTotalWater >= currentRequiredTotalWater
    }

    var growthProgress: Double {
        currentGrowthProgress
    }

    var currentWaterAmount: Double {
        waterLevel * 100
    }

    var projectedTotalWater: Double {
        min(currentRequiredTotalWater, currentReceivedWater + currentWaterAmount)
    }

    var currentReceivedWater: Double {
        activeFish?.receivedWater ?? 0
    }

    var currentRequiredTotalWater: Double {
        activeFish?.requiredTotalWater ?? Double(selectedSpecies.requiredTotalWaterRange.upperBound)
    }

    var currentGrowthProgress: Double {
        guard currentRequiredTotalWater > 0 else { return 0 }
        return min(1.0, max(0.0, currentReceivedWater / currentRequiredTotalWater))
    }

    var projectedGrowthProgress: Double {
        guard currentRequiredTotalWater > 0 else { return 0 }
        return min(1.0, max(0.0, projectedTotalWater / currentRequiredTotalWater))
    }

    var currentGrowthStage: GrowthStage {
        GrowthStage.stage(for: currentGrowthProgress)
    }

    var projectedGrowthStage: GrowthStage {
        GrowthStage.stage(for: projectedGrowthProgress)
    }

    var hasActiveFish: Bool {
        activeFish != nil
    }

    // MARK: - Formatted strings

    var countdownText: String {
        if isOverdue { return "+" + formatSeconds(overdueSeconds) }
        return formatSeconds(remainingSeconds)
    }

    var elapsedFormatted: String {
        formatSeconds(elapsedSeconds)
    }

    var currentRoutineRemainingText: String {
        guard let currentRoutineItem else { return "00:00" }
        let remaining = Int(Double(currentRoutineItem.durationSeconds) * (1 - currentRoutineProgress))
        return formatSeconds(max(0, remaining))
    }

    private func formatSeconds(_ s: Int) -> String {
        if s >= 3600 {
            return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
        }
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    // MARK: - Actions

    func start() {
        guard startedAt == nil else { return }
        startedAt = .now
        now = .now
        lastRoutineItemID = currentRoutineItem?.id
        didPlayOverdueWarning = isOverdue
        ScheduleHaptics.prepare()
        startTicker()
        saveState()
        NotificationScheduler.schedule(departureAt: schedule.targetDepartureTime, scheduleName: schedule.name)
        syncLiveActivity(force: true)
    }

    func depart(store: AppDataStore) async {
        guard !departed else { return }
        finalWaterLevel = waterLevel
        finalDelaySeconds = overdueSeconds
        finalWaterAmount = currentWaterAmount
        let fish = activeFish ?? createActiveFish(for: selectedSpecies, in: store)
        let species = fish.species
        let totalAfter = min(fish.requiredTotalWater, fish.receivedWater + finalWaterAmount)
        let growthStage = GrowthStage.stage(for: totalAfter / fish.requiredTotalWater)
        let completedGrowth = totalAfter >= fish.requiredTotalWater
        finalTotalWaterAfter = totalAfter
        finalRequiredTotalWater = fish.requiredTotalWater
        finalGrowthStage = growthStage
        finalCompletedGrowth = completedGrowth

        departed = true
        timer?.invalidate()
        timer = nil
        NotificationScheduler.cancelAll()
        saveState()
        endLiveActivity(status: .departed)

        await store.recordDeparture(
            species: species,
            fish: fish,
            waterAmount: finalWaterAmount,
            totalWaterAfter: totalAfter,
            growthStage: growthStage,
            completedGrowth: completedGrowth
        )

        if let error = store.errorMessage {
            saveError = "記録の保存に失敗しました"
            print("[DewTime] 水やり記録の保存に失敗しました: \(error)")
        } else {
            activeFish = completedGrowth ? nil : fish
        }
    }

    func reset() {
        if isRunning || departed {
            endLiveActivity(status: .cancelled)
        }
        timer?.invalidate()
        timer = nil
        startedAt = nil
        departed = false
        finalWaterLevel = 1.0
        finalDelaySeconds = 0
        finalWaterAmount = 0
        finalTotalWaterAfter = activeFish?.receivedWater ?? 0
        finalRequiredTotalWater = activeFish?.requiredTotalWater ?? 1
        finalGrowthStage = activeFish?.growthStage ?? .egg
        finalCompletedGrowth = false
        now = .now
        lastRoutineItemID = nil
        didPlayOverdueWarning = false
        clearState()
        NotificationScheduler.cancelAll()
    }

    func clearError() { saveError = nil }

    func selectSpecies(_ species: FishSpecies, store: AppDataStore) async {
        guard !isRunning, !departed else { return }
        selectedSpecies = species
        UserDefaults.standard.set(species.rawValue, forKey: PKey.selectedSpecies.rawValue)
        activeFish = createActiveFish(for: species, in: store)
        await store.saveAll()
        if let error = store.errorMessage {
            saveError = "魚の準備に失敗しました"
            print("[DewTime] ActiveFish の保存に失敗しました: \(error)")
        }
    }

    func syncActiveFish(_ fishes: [ActiveFish]) {
        if let fish = fishes
            .filter({ !$0.isCompleted })
            .sorted(by: { $0.startedAt > $1.startedAt })
            .first {
            activeFish = fish
            selectedSpecies = fish.species
            return
        }
        activeFish = nil
    }

    func updateDepartureTime(_ newTime: Date) {
        schedule.targetDepartureTime = newTime
    }

    // MARK: - Background / Foreground

    /// フォアグラウンド復帰時に呼ぶ。now を即時更新してティッカーを再開する。
    func resume() {
        guard startedAt != nil, !departed else { return }
        now = .now
        handleScheduleKnocks()
        if timer == nil { startTicker() }
        syncLiveActivity(force: true)
    }

    /// バックグラウンド移行時に呼ぶ。ティッカーを止めてバッテリーを節約する。
    func pause() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - State persistence

    private enum PKey: String {
        case scheduleId       = "dew.timer.scheduleId"
        case startedAt        = "dew.timer.startedAt"
        case departed         = "dew.timer.departed"
        case finalWaterLevel  = "dew.timer.finalWaterLevel"
        case finalDelaySeconds = "dew.timer.finalDelaySeconds"
        case selectedSpecies  = "dew.timer.selectedSpecies"
    }

    private func saveState() {
        let ud = UserDefaults.standard
        ud.set(schedule.id.uuidString,  forKey: PKey.scheduleId.rawValue)
        ud.set(startedAt,               forKey: PKey.startedAt.rawValue)
        ud.set(departed,                forKey: PKey.departed.rawValue)
        ud.set(finalWaterLevel,         forKey: PKey.finalWaterLevel.rawValue)
        ud.set(finalDelaySeconds,       forKey: PKey.finalDelaySeconds.rawValue)
    }

    private func restoreState() {
        let ud = UserDefaults.standard
        guard let savedId = ud.string(forKey: PKey.scheduleId.rawValue),
              savedId == schedule.id.uuidString else { return }

        departed   = ud.bool(forKey: PKey.departed.rawValue)
        startedAt  = ud.object(forKey: PKey.startedAt.rawValue) as? Date

        if departed {
            finalWaterLevel   = ud.double(forKey: PKey.finalWaterLevel.rawValue)
            finalDelaySeconds = ud.integer(forKey: PKey.finalDelaySeconds.rawValue)
        } else if startedAt != nil {
            now = .now
            startTicker()
        }
    }

    private func clearState() {
        [PKey.scheduleId, .startedAt, .departed, .finalWaterLevel, .finalDelaySeconds]
            .forEach { UserDefaults.standard.removeObject(forKey: $0.rawValue) }
    }

    // MARK: - Private helpers

    private static func restoreSelectedSpecies() -> FishSpecies {
        guard let rawValue = UserDefaults.standard.string(forKey: PKey.selectedSpecies.rawValue),
              let species = FishSpecies(rawValue: rawValue) else {
            return .medaka
        }
        return species
    }

    private func createActiveFish(for species: FishSpecies, in store: AppDataStore) -> ActiveFish {
        if let activeFish, !activeFish.isCompleted, activeFish.species == species {
            return activeFish
        }

        let fish = store.createActiveFish(for: species)
        activeFish = fish
        return fish
    }

    private func startTicker() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.now = .now
                self.handleScheduleKnocks()
                self.syncLiveActivity(force: false)
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func handleScheduleKnocks() {
        guard isRunning else { return }

        let currentID = currentRoutineItem?.id
        if let currentID, let lastRoutineItemID, currentID != lastRoutineItemID {
            if AppPreferences.hapticsEnabled {
                ScheduleHaptics.playPhaseKnock()
            }
            syncLiveActivity(force: true)
        }
        lastRoutineItemID = currentID

        if isOverdue, !didPlayOverdueWarning {
            didPlayOverdueWarning = true
            if AppPreferences.hapticsEnabled {
                ScheduleHaptics.playOverdueWarning()
            }
            syncLiveActivity(force: true)
        }
    }
}

extension TimerViewModel {
    func liveActivityAttributes() -> DewTimerActivityAttributes? {
        guard let startedAt else { return nil }

        var elapsed: TimeInterval = 0
        let segments = schedule.orderedItems.map { item in
            let start = elapsed
            elapsed += TimeInterval(item.durationSeconds)
            return DewTimerActivityAttributes.RoutineSegment(
                id: item.id.uuidString,
                name: item.name,
                colorHex: item.colorHex,
                startOffset: start,
                endOffset: elapsed
            )
        }

        return DewTimerActivityAttributes(
            scheduleName: schedule.name,
            startedAt: startedAt,
            targetDepartureTime: schedule.targetDepartureTime,
            segments: segments
        )
    }

    func liveActivityContentState(
        status explicitStatus: DewTimerActivityAttributes.TimerStatus? = nil
    ) -> DewTimerActivityAttributes.ContentState {
        let status = explicitStatus ?? defaultLiveActivityStatus
        return DewTimerActivityAttributes.ContentState(
            currentTaskName: liveActivityCurrentTaskName(status: status),
            nextTaskName: status.isFinished ? nil : nextRoutineItem?.name,
            selectedSpeciesName: selectedSpecies.displayName,
            fishEmoji: selectedSpecies.emoji,
            growthStageName: projectedGrowthStage.displayName,
            growthStageIconName: projectedGrowthStage.icon,
            receivedWater: currentReceivedWater,
            requiredWater: currentRequiredTotalWater,
            projectedWater: projectedTotalWater,
            waterLevel: waterLevel,
            status: status,
            lastUpdatedAt: now
        )
    }

    private var defaultLiveActivityStatus: DewTimerActivityAttributes.TimerStatus {
        if departed { return .departed }
        if isOverdue { return .overdue }
        return .running
    }

    private func liveActivityCurrentTaskName(status: DewTimerActivityAttributes.TimerStatus) -> String {
        switch status {
        case .departed:
            return "出発完了"
        case .cancelled:
            return "キャンセル"
        case .running, .overdue:
            return currentRoutineItem?.name ?? "準備中"
        }
    }

    private func syncLiveActivity(force: Bool) {
        guard isRunning else { return }

        let shouldUpdate: Bool
        if force {
            shouldUpdate = true
        } else if let lastLiveActivityUpdate {
            shouldUpdate = now.timeIntervalSince(lastLiveActivityUpdate) >= 15
        } else {
            shouldUpdate = true
        }

        guard shouldUpdate else { return }
        lastLiveActivityUpdate = now

        guard let attributes = liveActivityAttributes() else { return }
        let state = liveActivityContentState()
        Task {
            await DewTimerLiveActivityController.start(attributes: attributes, state: state)
        }
    }

    private func endLiveActivity(status: DewTimerActivityAttributes.TimerStatus) {
        let state = liveActivityContentState(status: status)
        lastLiveActivityUpdate = nil
        Task {
            await DewTimerLiveActivityController.end(state: state)
        }
    }
}
