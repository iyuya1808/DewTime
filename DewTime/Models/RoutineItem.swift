import Foundation
import SwiftData

@Model
final class RoutineItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var durationSeconds: Int
    var colorHex: String
    var orderIndex: Int
    var schedule: UserSchedule?

    init(
        id: UUID = UUID(),
        name: String,
        durationSeconds: Int,
        colorHex: String,
        orderIndex: Int,
        schedule: UserSchedule? = nil
    ) {
        self.id = id
        self.name = name
        self.durationSeconds = durationSeconds
        self.colorHex = colorHex
        self.orderIndex = orderIndex
        self.schedule = schedule
    }
}
