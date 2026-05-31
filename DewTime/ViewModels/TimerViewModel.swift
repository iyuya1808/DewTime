import Foundation
import SwiftData
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
    }

    func depart(context: ModelContext) {
        guard !departed else { return }
        finalWaterLevel = waterLevel
        finalDelaySeconds = overdueSeconds
        finalWaterAmount = currentWaterAmount
        let fish = activeFish ?? createActiveFish(for: selectedSpecies, in: context)
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

        fish.receivedWater = totalAfter
        fish.lastWateredAt = .now
        fish.isCompleted = completedGrowth

        let record = FishCareRecord(
            speciesId: species.rawValue,
            recordedAt: .now,
            waterAmount: finalWaterAmount,
            totalWaterAfter: totalAfter,
            requiredTotalWater: fish.requiredTotalWater,
            growthStage: growthStage,
            completedGrowth: completedGrowth
        )
        context.insert(record)

        // 出発時に水槽へ注いだ水を累積し、水槽を成長させる（ゲーム要素の土台）。
        let aquarium = fetchOrCreateAquarium(in: context)
        aquarium.totalWaterCollected += finalWaterAmount
        aquarium.updatedAt = .now

        if completedGrowth {
            let collected = CollectedFish(
                name: species.displayName,
                speciesId: species.rawValue,
                recordedAt: .now,
                succeeded: true,
                waterRatio: 1.0
            )
            context.insert(collected)
        }

        do {
            try context.save()
            activeFish = completedGrowth ? nil : fish
        } catch {
            saveError = "記録の保存に失敗しました"
            print("[DewTime] 水やり記録の保存に失敗しました: \(error)")
        }
    }

    func reset() {
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

    func selectSpecies(_ species: FishSpecies, context: ModelContext) {
        guard !isRunning, !departed else { return }
        selectedSpecies = species
        UserDefaults.standard.set(species.rawValue, forKey: PKey.selectedSpecies.rawValue)
        activeFish = createActiveFish(for: species, in: context)
        do {
            try context.save()
        } catch {
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

    private func createActiveFish(for species: FishSpecies, in context: ModelContext) -> ActiveFish {
        if let activeFish, !activeFish.isCompleted, activeFish.species == species {
            return activeFish
        }

        activeFish?.isCompleted = true
        let fish = ActiveFish(
            speciesId: species.rawValue,
            name: species.displayName,
            requiredTotalWater: species.makeRequiredTotalWater()
        )
        context.insert(fish)
        activeFish = fish
        return fish
    }

    private func fetchOrCreateAquarium(in context: ModelContext) -> Aquarium {
        if let existing = try? context.fetch(FetchDescriptor<Aquarium>()).first {
            return existing
        }
        let aquarium = Aquarium()
        context.insert(aquarium)
        return aquarium
    }

    private func startTicker() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.now = .now
                self.handleScheduleKnocks()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func handleScheduleKnocks() {
        guard isRunning else { return }

        let currentID = currentRoutineItem?.id
        if let currentID, let lastRoutineItemID, currentID != lastRoutineItemID {
            ScheduleHaptics.playPhaseKnock()
        }
        lastRoutineItemID = currentID

        if isOverdue, !didPlayOverdueWarning {
            didPlayOverdueWarning = true
            ScheduleHaptics.playOverdueWarning()
        }
    }
}
