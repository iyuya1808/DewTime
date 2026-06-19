import Foundation
import Observation
import WidgetKit

@Observable
@MainActor
final class TimerViewModel {
    private(set) var targetDepartureTime: Date
    private(set) var startedAt: Date?
    private(set) var now: Date = .now
    private(set) var departed: Bool = false
    private(set) var initialWaterLevel: Double = 1.0
    private(set) var finalWaterLevel: Double = 1.0
    private(set) var finalDelaySeconds: Int = 0
    private(set) var saveError: String?
    private(set) var finalEarnedDrop: Bool = false
    private(set) var finalBonusFeedAwarded: Bool = false
    private(set) var finalAquariumTier: Int = 0
    private(set) var finalAquariumDepartures: Int = 0
    private(set) var departurePersisted: Bool = false

    private var timer: Timer?
    private var lastLiveActivityUpdate: Date?
    private var didPlayOverdueWarning = false
    private var departureSessionID = UUID()
    private weak var activityStore: AppDataStore?

    init(targetDepartureTime: Date = .now.addingTimeInterval(15 * 60)) {
        self.targetDepartureTime = targetDepartureTime
        restoreState()
        didPlayOverdueWarning = isOverdue
    }

    func handleLanguageChange() {
        syncLiveActivity(store: activityStore, force: true)
        saveWidgetStateIfNeeded()
    }

    func bindStore(_ store: AppDataStore) {
        activityStore = store
    }

    // MARK: - Derived state

    var remainingSeconds: Int {
        let base: Date = startedAt != nil ? now : .now
        return max(0, Int(targetDepartureTime.timeIntervalSince(base)))
    }

    var overdueSeconds: Int {
        guard startedAt != nil else { return 0 }
        return max(0, Int(now.timeIntervalSince(targetDepartureTime)))
    }

    var isOverdue: Bool { overdueSeconds > 0 }

    var waterLevel: Double {
        if departed { return finalWaterLevel }
        guard let startedAt else { return 1.0 }
        let total = targetDepartureTime.timeIntervalSince(startedAt)
        guard total > 0 else { return 0.0 }
        let remaining = targetDepartureTime.timeIntervalSince(now)
        return min(initialWaterLevel, max(0.0, remaining / total * initialWaterLevel))
    }

    var isRunning: Bool { startedAt != nil && !departed }

    var elapsedSeconds: Int {
        guard let startedAt else { return 0 }
        return max(0, Int(now.timeIntervalSince(startedAt)))
    }

    func aquariumSnapshot(from store: AppDataStore) -> Aquarium {
        store.aquarium()
    }

    func projectedAquariumDepartures(from store: AppDataStore) -> Int {
        let aquarium = store.aquarium()
        return aquarium.totalDepartures + (isOverdue ? 0 : 1)
    }

    // MARK: - Formatted strings

    var countdownText: String {
        if isOverdue { return "+" + formatSeconds(overdueSeconds) }
        return formatSeconds(remainingSeconds)
    }

    var elapsedFormatted: String {
        formatSeconds(elapsedSeconds)
    }

    private func formatSeconds(_ s: Int) -> String {
        if s >= 3600 {
            return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
        }
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    // MARK: - Actions

    func start(initialLevel: Double = 1.0) {
        guard startedAt == nil else { return }
        initialWaterLevel = max(0.01, min(1.0, initialLevel))
        startedAt = .now
        now = .now
        didPlayOverdueWarning = isOverdue
        ScheduleHaptics.prepare()
        startTicker()
        saveState()
        NotificationScheduler.schedule(departureAt: targetDepartureTime)
        syncLiveActivity(store: activityStore, force: true)
    }

    func finalizeDeparture(store: AppDataStore) {
        guard !departed else { return }
        finalWaterLevel = waterLevel
        finalDelaySeconds = overdueSeconds
        finalEarnedDrop = !isOverdue
        finalBonusFeedAwarded = finalEarnedDrop

        let aquariumBefore = store.aquarium()
        finalAquariumDepartures = aquariumBefore.totalDepartures + (finalEarnedDrop ? 1 : 0)
        finalAquariumTier = Aquarium(totalDepartures: finalAquariumDepartures).sizeTier

        departureSessionID = UUID()
        departed = true
        departurePersisted = false
        timer?.invalidate()
        timer = nil
        NotificationScheduler.cancelAll()
        saveState()
        endLiveActivity(store: activityStore, status: .departed)
    }

    func persistDeparture(store: AppDataStore) async {
        guard departed, !departurePersisted else { return }

        let sessionID = departureSessionID
        let earnedDrop = finalEarnedDrop

        await store.recordDeparture(earnedDrop: earnedDrop)

        if sessionID != departureSessionID {
            if store.errorMessage == nil {
                await store.undoLastDeparture(earnedDrop: earnedDrop)
            }
            return
        }

        guard departed else { return }

        departurePersisted = store.errorMessage == nil
        saveState()

        if let error = store.errorMessage {
            saveError = L10n.Timer.saveFailed
            print("[DewTime] 出発記録の保存に失敗しました: \(error)")
        }
    }

    func depart(store: AppDataStore) async {
        finalizeDeparture(store: store)
        await persistDeparture(store: store)
    }

    /// 誤タップで出発した場合、タイマーを再開する。
    func resumeDeparture(store: AppDataStore) async {
        guard departed, startedAt != nil else { return }

        let earnedDrop = finalEarnedDrop
        let wasPersisted = departurePersisted
        departureSessionID = UUID()

        departed = false
        departurePersisted = false
        finalWaterLevel = 1.0
        finalDelaySeconds = 0
        finalEarnedDrop = false
        finalBonusFeedAwarded = false
        finalAquariumTier = 0
        finalAquariumDepartures = 0

        now = .now
        didPlayOverdueWarning = isOverdue
        startTicker()
        saveState()
        NotificationScheduler.schedule(departureAt: targetDepartureTime)
        syncLiveActivity(store: store, force: true)

        if wasPersisted {
            await store.undoLastDeparture(earnedDrop: earnedDrop)
        }
    }

    /// 前回セッションで出発済みのまま結果画面を閉じられなかった場合の復旧。
    func recoverDepartedSession(store: AppDataStore) async {
        guard departed else { return }

        finalEarnedDrop = finalDelaySeconds == 0
        finalBonusFeedAwarded = finalEarnedDrop

        if !isDepartureRecorded(in: store) {
            await store.recordDeparture(earnedDrop: finalEarnedDrop)
            departurePersisted = store.errorMessage == nil
            saveState()

            if let error = store.errorMessage {
                saveError = L10n.Timer.saveFailed
                print("[DewTime] 出発記録の再保存に失敗しました: \(error)")
            }
        } else {
            departurePersisted = true
            saveState()
        }

        let aquarium = store.aquarium()
        finalAquariumDepartures = aquarium.totalDepartures
        finalAquariumTier = aquarium.sizeTier
    }

    func reset() {
        if isRunning || departed {
            endLiveActivity(store: activityStore, status: .cancelled)
        }
        timer?.invalidate()
        timer = nil
        startedAt = nil
        departed = false
        initialWaterLevel = 1.0
        finalWaterLevel = 1.0
        finalDelaySeconds = 0
        finalEarnedDrop = false
        finalBonusFeedAwarded = false
        finalAquariumTier = 0
        finalAquariumDepartures = 0
        departurePersisted = false
        now = .now
        didPlayOverdueWarning = false
        clearState()
        NotificationScheduler.cancelAll()
    }

    func clearError() { saveError = nil }

    func reportSaveError(_ message: String) { saveError = message }

    func updateDepartureTime(_ newTime: Date) {
        targetDepartureTime = newTime
    }

    // MARK: - Background / Foreground

    func resume(store: AppDataStore) {
        guard startedAt != nil, !departed else { return }
        now = .now
        handleTimerKnocks()
        if timer == nil { startTicker() }
        syncLiveActivity(store: store, force: true)
    }

    func pause() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - State persistence

    private enum PKey: String {
        case legacyScheduleId     = "dew.timer.scheduleId"
        case targetDepartureTime  = "dew.timer.targetDepartureTime"
        case startedAt            = "dew.timer.startedAt"
        case departed             = "dew.timer.departed"
        case finalWaterLevel      = "dew.timer.finalWaterLevel"
        case finalDelaySeconds    = "dew.timer.finalDelaySeconds"
        case initialWaterLevel    = "dew.timer.initialWaterLevel"
        case departurePersisted   = "dew.timer.departurePersisted"
    }

    private func saveState() {
        let ud = UserDefaults.standard
        ud.set(targetDepartureTime, forKey: PKey.targetDepartureTime.rawValue)
        ud.set(startedAt,          forKey: PKey.startedAt.rawValue)
        ud.set(departed,           forKey: PKey.departed.rawValue)
        ud.set(initialWaterLevel,  forKey: PKey.initialWaterLevel.rawValue)
        ud.set(finalWaterLevel,    forKey: PKey.finalWaterLevel.rawValue)
        ud.set(finalDelaySeconds,  forKey: PKey.finalDelaySeconds.rawValue)
        ud.set(departurePersisted, forKey: PKey.departurePersisted.rawValue)
        saveWidgetStateIfNeeded()
    }

    private func restoreState() {
        let ud = UserDefaults.standard
        ud.removeObject(forKey: PKey.legacyScheduleId.rawValue)

        if let savedTarget = ud.object(forKey: PKey.targetDepartureTime.rawValue) as? Date {
            targetDepartureTime = savedTarget
        }

        departed          = ud.bool(forKey: PKey.departed.rawValue)
        startedAt         = ud.object(forKey: PKey.startedAt.rawValue) as? Date
        let savedInitial  = ud.double(forKey: PKey.initialWaterLevel.rawValue)
        initialWaterLevel = savedInitial > 0 ? savedInitial : 1.0

        if departed {
            finalWaterLevel   = ud.double(forKey: PKey.finalWaterLevel.rawValue)
            finalDelaySeconds = ud.integer(forKey: PKey.finalDelaySeconds.rawValue)
            departurePersisted = ud.bool(forKey: PKey.departurePersisted.rawValue)
            finalEarnedDrop = finalDelaySeconds == 0
            finalBonusFeedAwarded = finalEarnedDrop
        } else if startedAt != nil {
            now = .now
            startTicker()
        }
    }

    private func clearState() {
        [
            PKey.legacyScheduleId,
            .targetDepartureTime,
            .startedAt,
            .departed,
            .initialWaterLevel,
            .finalWaterLevel,
            .finalDelaySeconds,
            .departurePersisted
        ].forEach { UserDefaults.standard.removeObject(forKey: $0.rawValue) }
        SharedTimerWidgetState.clear()
        WidgetCenter.shared.reloadTimelines(ofKind: SharedTimerWidgetState.widgetKind)
    }

    private func startTicker() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.now = .now
                self.handleTimerKnocks()
                self.syncLiveActivity(store: self.activityStore, force: false)
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func isDepartureRecorded(in store: AppDataStore) -> Bool {
        if UserDefaults.standard.object(forKey: PKey.departurePersisted.rawValue) != nil {
            return departurePersisted
        }
        guard let startedAt else { return false }
        return store.careRecords.contains { record in
            record.isDepartureLog && record.recordedAt >= startedAt.addingTimeInterval(-60)
        }
    }

    private func handleTimerKnocks() {
        guard isRunning else { return }

        if isOverdue, !didPlayOverdueWarning {
            didPlayOverdueWarning = true
            if AppPreferences.hapticsEnabled {
                ScheduleHaptics.playOverdueWarning()
            }
            syncLiveActivity(store: activityStore, force: true)
        }
    }
}

extension TimerViewModel {
    func liveActivityAttributes() -> DewTimerActivityAttributes? {
        guard let startedAt else { return nil }

        return DewTimerActivityAttributes(
            scheduleName: "DewTime",
            startedAt: startedAt,
            targetDepartureTime: targetDepartureTime,
            segments: [],
            initialWaterLevel: initialWaterLevel
        )
    }

    func liveActivityContentState(
        store: AppDataStore?,
        status explicitStatus: DewTimerActivityAttributes.TimerStatus? = nil
    ) -> DewTimerActivityAttributes.ContentState {
        let status = explicitStatus ?? defaultLiveActivityStatus
        let aquarium = store?.aquarium() ?? Aquarium()
        let projectedDepartures = store.map { projectedAquariumDepartures(from: $0) } ?? aquarium.totalDepartures
        let projectedTier = Aquarium(totalDepartures: projectedDepartures).sizeTier

        return DewTimerActivityAttributes.ContentState(
            currentTaskName: liveActivityCurrentTaskName(status: status),
            nextTaskName: nil,
            aquariumTier: projectedTier,
            aquariumTierName: Aquarium.sizeName(for: projectedTier),
            aquariumDepartures: projectedDepartures,
            bonusFeedStock: aquarium.bonusFeedStock,
            waterLevel: waterLevel,
            status: status,
            phaseIndex: -1,
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
            return L10n.Timer.statusDeparted
        case .cancelled:
            return L10n.Timer.statusCancelled
        case .running:
            return L10n.Timer.statusRemaining(countdownText)
        case .overdue:
            return L10n.Timer.statusOverdue(countdownText)
        }
    }

    private func syncLiveActivity(store: AppDataStore?, force: Bool) {
        guard isRunning else { return }

        let shouldUpdate: Bool
        if force {
            shouldUpdate = true
        } else if let lastLiveActivityUpdate {
            // タイマーは Text(timerInterval:) に任せる。水位だけ15秒ごとに更新。
            shouldUpdate = now.timeIntervalSince(lastLiveActivityUpdate) >= 15
        } else {
            shouldUpdate = true
        }

        guard shouldUpdate else { return }
        lastLiveActivityUpdate = now

        guard let attributes = liveActivityAttributes() else { return }
        let state = liveActivityContentState(store: store)
        Task {
            await DewTimerLiveActivityController.start(attributes: attributes, state: state)
        }
    }

    private func saveWidgetStateIfNeeded() {
        guard let startedAt, !departed else {
            SharedTimerWidgetState.clear()
            WidgetCenter.shared.reloadTimelines(ofKind: SharedTimerWidgetState.widgetKind)
            return
        }

        let fish = activityStore?.latestActiveFish()
        let species = fish.flatMap { FishSpecies(rawValue: $0.speciesId) }
        let fishEmoji = species?.emoji ?? "🐟"
        let speciesName = species.map { L10n.Fish.name($0) } ?? L10n.Fish.generic

        SharedTimerWidgetState.save(
            SharedTimerWidgetState(
                scheduleName: "DewTime",
                startedAt: startedAt,
                targetDepartureTime: targetDepartureTime,
                fishEmoji: fishEmoji,
                speciesRawValue: species?.rawValue,
                selectedSpeciesName: speciesName,
                segments: []
            )
        )
        WidgetCenter.shared.reloadTimelines(ofKind: SharedTimerWidgetState.widgetKind)
    }

    private func endLiveActivity(store: AppDataStore?, status: DewTimerActivityAttributes.TimerStatus) {
        let state = liveActivityContentState(store: store, status: status)
        lastLiveActivityUpdate = nil
        Task {
            if status == .departed {
                await DewTimerLiveActivityController.finishWithPour(state: state)
            } else {
                await DewTimerLiveActivityController.end(state: state)
            }
        }
    }
}
