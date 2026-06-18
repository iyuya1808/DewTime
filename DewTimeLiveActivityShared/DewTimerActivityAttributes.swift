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

    var timerInterval: ClosedRange<Date> {
        startedAt...targetDepartureTime
    }
}
