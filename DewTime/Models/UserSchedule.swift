import Foundation
import SwiftData

@Model
final class UserSchedule {
    @Attribute(.unique) var id: UUID
    var name: String
    var targetDepartureTime: Date
    var isActive: Bool

    @Relationship(deleteRule: .cascade, inverse: \RoutineItem.schedule)
    var items: [RoutineItem] = []

    init(
        id: UUID = UUID(),
        name: String,
        targetDepartureTime: Date,
        isActive: Bool = false
    ) {
        self.id = id
        self.name = name
        self.targetDepartureTime = targetDepartureTime
        self.isActive = isActive
    }

    var orderedItems: [RoutineItem] {
        items.sorted { $0.orderIndex < $1.orderIndex }
    }

    var totalSeconds: Int {
        items.reduce(0) { $0 + $1.durationSeconds }
    }
}

extension UserSchedule {
    /// isActive なスケジュールを返す。なければ先頭を返す。
    static func active(in schedules: [UserSchedule]) -> UserSchedule? {
        schedules.first(where: { $0.isActive }) ?? schedules.first
    }
}
