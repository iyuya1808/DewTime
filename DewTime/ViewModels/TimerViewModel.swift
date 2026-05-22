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

    private var timer: Timer?

    init(schedule: UserSchedule) {
        self.schedule = schedule
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

    // MARK: - Formatted strings

    var countdownText: String {
        if isOverdue { return "+" + formatSeconds(overdueSeconds) }
        return formatSeconds(remainingSeconds)
    }

    var elapsedFormatted: String {
        guard let startedAt else { return "00:00" }
        let s = Int(now.timeIntervalSince(startedAt))
        return formatSeconds(max(0, s))
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
        departed = true
        timer?.invalidate()
        timer = nil
        NotificationScheduler.cancelAll()
        saveState()

        let species = FlowerSpecies.pick(for: finalWaterLevel)
        let flower = PlantFlower(
            name: "今日の花",
            speciesId: species.rawValue,
            recordedAt: .now,
            succeeded: finalWaterLevel > 0.1,
            waterRatio: finalWaterLevel
        )
        context.insert(flower)
        do {
            try context.save()
        } catch {
            saveError = "記録の保存に失敗しました"
            print("[DewTime] PlantFlower の保存に失敗しました: \(error)")
        }
    }

    func reset() {
        timer?.invalidate()
        timer = nil
        startedAt = nil
        departed = false
        finalWaterLevel = 1.0
        finalDelaySeconds = 0
        now = .now
        clearState()
        NotificationScheduler.cancelAll()
    }

    func clearError() { saveError = nil }

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

    private func startTicker() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.now = .now }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
}
