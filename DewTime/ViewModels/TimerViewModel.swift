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
    private(set) var selectedSpecies: FlowerSpecies
    private(set) var activePlant: ActivePlant?
    private(set) var finalWaterAmount: Double = 0
    private(set) var finalTotalWaterAfter: Double = 0
    private(set) var finalRequiredTotalWater: Double = 1
    private(set) var finalGrowthStage: GrowthStage = .seed
    private(set) var finalCompletedGrowth: Bool = false

    private var timer: Timer?

    init(schedule: UserSchedule) {
        self.schedule = schedule
        self.selectedSpecies = Self.restoreSelectedSpecies()
        restoreState()
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
        activePlant?.receivedWater ?? 0
    }

    var currentRequiredTotalWater: Double {
        activePlant?.requiredTotalWater ?? Double(selectedSpecies.requiredTotalWaterRange.upperBound)
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

    var hasActivePlant: Bool {
        activePlant != nil
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
        startTicker()
        saveState()
        NotificationScheduler.schedule(departureAt: schedule.targetDepartureTime, scheduleName: schedule.name)
    }

    func depart(context: ModelContext) {
        guard !departed else { return }
        finalWaterLevel = waterLevel
        finalDelaySeconds = overdueSeconds
        finalWaterAmount = currentWaterAmount
        let plant = activePlant ?? createActivePlant(for: selectedSpecies, in: context)
        let species = plant.species
        let totalAfter = min(plant.requiredTotalWater, plant.receivedWater + finalWaterAmount)
        let growthStage = GrowthStage.stage(for: totalAfter / plant.requiredTotalWater)
        let completedGrowth = totalAfter >= plant.requiredTotalWater
        finalTotalWaterAfter = totalAfter
        finalRequiredTotalWater = plant.requiredTotalWater
        finalGrowthStage = growthStage
        finalCompletedGrowth = completedGrowth

        departed = true
        timer?.invalidate()
        timer = nil
        NotificationScheduler.cancelAll()
        saveState()

        plant.receivedWater = totalAfter
        plant.lastWateredAt = .now
        plant.isCompleted = completedGrowth

        let record = PlantWateringRecord(
            speciesId: species.rawValue,
            recordedAt: .now,
            waterAmount: finalWaterAmount,
            totalWaterAfter: totalAfter,
            requiredTotalWater: plant.requiredTotalWater,
            growthStage: growthStage,
            completedGrowth: completedGrowth
        )
        context.insert(record)

        if completedGrowth {
            let flower = PlantFlower(
                name: species.displayName,
                speciesId: species.rawValue,
                recordedAt: .now,
                succeeded: true,
                waterRatio: 1.0
            )
            context.insert(flower)
        }

        do {
            try context.save()
            activePlant = completedGrowth ? nil : plant
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
        finalTotalWaterAfter = activePlant?.receivedWater ?? 0
        finalRequiredTotalWater = activePlant?.requiredTotalWater ?? 1
        finalGrowthStage = activePlant?.growthStage ?? .seed
        finalCompletedGrowth = false
        now = .now
        clearState()
        NotificationScheduler.cancelAll()
    }

    func clearError() { saveError = nil }

    func selectSpecies(_ species: FlowerSpecies, context: ModelContext) {
        guard !isRunning, !departed else { return }
        selectedSpecies = species
        UserDefaults.standard.set(species.rawValue, forKey: PKey.selectedSpecies.rawValue)
        activePlant = createActivePlant(for: species, in: context)
        do {
            try context.save()
        } catch {
            saveError = "植物の準備に失敗しました"
            print("[DewTime] ActivePlant の保存に失敗しました: \(error)")
        }
    }

    func syncActivePlant(_ plants: [ActivePlant]) {
        if let plant = plants
            .filter({ !$0.isCompleted })
            .sorted(by: { $0.startedAt > $1.startedAt })
            .first {
            activePlant = plant
            selectedSpecies = plant.species
            return
        }
        activePlant = nil
    }

    func updateDepartureTime(_ newTime: Date) {
        schedule.targetDepartureTime = newTime
    }

    // MARK: - Background / Foreground

    /// フォアグラウンド復帰時に呼ぶ。now を即時更新してティッカーを再開する。
    func resume() {
        guard startedAt != nil, !departed else { return }
        now = .now
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

    private static func restoreSelectedSpecies() -> FlowerSpecies {
        guard let rawValue = UserDefaults.standard.string(forKey: PKey.selectedSpecies.rawValue),
              let species = FlowerSpecies(rawValue: rawValue) else {
            return .cactus
        }
        return species
    }

    private func createActivePlant(for species: FlowerSpecies, in context: ModelContext) -> ActivePlant {
        if let activePlant, !activePlant.isCompleted, activePlant.species == species {
            return activePlant
        }

        activePlant?.isCompleted = true
        let plant = ActivePlant(
            speciesId: species.rawValue,
            name: species.displayName,
            requiredTotalWater: species.makeRequiredTotalWater()
        )
        context.insert(plant)
        activePlant = plant
        return plant
    }

    private func startTicker() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.now = .now }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
}
