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
        var selectedSpeciesName: String
        var fishEmoji: String
        var growthStageName: String
        var growthStageIconName: String
        var receivedWater: Double
        var requiredWater: Double
        var projectedWater: Double
        var waterLevel: Double
        var status: TimerStatus
        var lastUpdatedAt: Date

        var waterPercent: Int {
            Int((max(0, min(1, waterLevel)) * 100).rounded())
        }

        var growthProgress: Double {
            guard requiredWater > 0 else { return 0 }
            return max(0, min(1, projectedWater / requiredWater))
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

    var timerInterval: ClosedRange<Date> {
        startedAt...targetDepartureTime
    }
}
