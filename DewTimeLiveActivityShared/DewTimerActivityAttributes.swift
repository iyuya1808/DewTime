import ActivityKit
import Foundation

struct DewTimerActivityAttributes: ActivityAttributes {
    struct RoutineSegment: Codable, Hashable, Identifiable {
        var id: String
        var name: String
        var colorHex: String
        var startOffset: TimeInterval
        var endOffset: TimeInterval
    }

    struct ContentState: Codable, Hashable {
        var currentTaskName: String
        var nextTaskName: String?
        var aquariumTier: Int
        var aquariumTierName: String
        var aquariumDepartures: Int
        var bonusFeedStock: Int
        var waterLevel: Double
        var status: TimerStatus
        var phaseIndex: Int
        var lastUpdatedAt: Date

        var waterPercent: Int {
            Int((max(0, min(1, waterLevel)) * 100).rounded())
        }

        var tierDisplayNumber: Int {
            aquariumTier + 1
        }
    }

    enum TimerStatus: String, Codable, Hashable {
        case running
        case overdue
        case departed
        case cancelled

        var isFinished: Bool {
            self == .departed || self == .cancelled
        }
    }

    var scheduleName: String
    var startedAt: Date
    var targetDepartureTime: Date
    var segments: [RoutineSegment]
    var initialWaterLevel: Double = 1.0

    var timerInterval: ClosedRange<Date> {
        startedAt...targetDepartureTime
    }

    var totalDuration: TimeInterval {
        max(1, targetDepartureTime.timeIntervalSince(startedAt))
    }

    func waterLevel(at date: Date) -> Double {
        let remaining = targetDepartureTime.timeIntervalSince(date)
        return min(initialWaterLevel, max(0, remaining / totalDuration * initialWaterLevel))
    }

    func isOverdue(at date: Date) -> Bool {
        date > targetDepartureTime
    }

    func resolvedStatus(state: ContentState, at date: Date) -> TimerStatus {
        switch state.status {
        case .departed, .cancelled:
            return state.status
        case .running, .overdue:
            return isOverdue(at: date) ? .overdue : .running
        }
    }

    var showsHourTimer: Bool {
        totalDuration >= 3600
    }

    func timerSeconds(at date: Date) -> Int {
        if isOverdue(at: date) {
            return max(0, Int(date.timeIntervalSince(targetDepartureTime)))
        }
        return max(0, Int(targetDepartureTime.timeIntervalSince(date)))
    }

    func formattedTimer(at date: Date) -> String {
        let overdue = isOverdue(at: date)
        let seconds = timerSeconds(at: date)
        let prefix = overdue ? "+" : ""
        if seconds >= 3600 || (showsHourTimer && !overdue) {
            return prefix + String(format: "%d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
        }
        return prefix + String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    func timerPlaceholder(isOverdue: Bool) -> String {
        if isOverdue {
            return showsHourTimer ? "+0:00:00" : "+00:00"
        }
        return showsHourTimer ? "0:00:00" : "00:00"
    }

    /// 超過後も表示を維持するため、出発予定の2時間後までを有効期限とする。
    var activityStaleDate: Date {
        targetDepartureTime.addingTimeInterval(2 * 3600)
    }
}
