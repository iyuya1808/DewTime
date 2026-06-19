import Foundation

struct SharedTimerWidgetState: Codable, Equatable {
    static let appGroupIdentifier = "group.com.technophere.DewTime"
    static let defaultsKey = "dew.widget.timerState"
    static let widgetKind = "DewTimeQuickStartWidget"

    struct RoutineSegment: Codable, Equatable, Identifiable {
        var id: String
        var name: String
        var startOffset: TimeInterval
        var endOffset: TimeInterval
    }

    var scheduleName: String
    var startedAt: Date
    var targetDepartureTime: Date
    var fishEmoji: String
    /// 実写魚画像のアセット名を決めるための `FishSpecies.rawValue`（例: "medaka"）。
    /// 旧バージョンの保存データには存在しないため optional。
    var speciesRawValue: String?
    var selectedSpeciesName: String
    var segments: [RoutineSegment]

    var totalDuration: TimeInterval {
        max(1, targetDepartureTime.timeIntervalSince(startedAt))
    }

    func waterLevel(at date: Date) -> Double {
        let remaining = targetDepartureTime.timeIntervalSince(date)
        return min(1, max(0, remaining / totalDuration))
    }

    func isOverdue(at date: Date) -> Bool {
        date > targetDepartureTime
    }

    func currentTaskName(at date: Date) -> String {
        guard !segments.isEmpty else { return selectedSpeciesName }
        let elapsed = max(0, date.timeIntervalSince(startedAt))
        return segments.first(where: { elapsed < $0.endOffset })?.name
            ?? segments.last?.name
            ?? L10n.Common.preparing
    }

    static func load() -> SharedTimerWidgetState? {
        guard let data = sharedDefaults?.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(SharedTimerWidgetState.self, from: data)
    }

    static func save(_ state: SharedTimerWidgetState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        sharedDefaults?.set(data, forKey: defaultsKey)
    }

    static func clear() {
        sharedDefaults?.removeObject(forKey: defaultsKey)
    }

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }
}
