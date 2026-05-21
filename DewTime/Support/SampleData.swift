import Foundation
import SwiftData

enum SampleData {
    static func seedIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<UserSchedule>()
        let existing = (try? context.fetch(descriptor)) ?? []
        guard existing.isEmpty else { return }

        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: .now)
        components.hour = 8
        components.minute = 0
        let departureTime = calendar.date(from: components) ?? .now

        let schedule = UserSchedule(
            name: "平日通常モード",
            targetDepartureTime: departureTime,
            isActive: true
        )
        context.insert(schedule)

        let definitions: [(String, Int, String)] = [
            ("ハミガキ", 180, "#4FC3F7"),
            ("洗顔", 120, "#81D4FA"),
            ("着替え", 300, "#FFB74D"),
            ("朝食", 600, "#FFCC80"),
            ("持ち物確認", 120, "#A5D6A7")
        ]

        for (index, def) in definitions.enumerated() {
            let item = RoutineItem(
                name: def.0,
                durationSeconds: def.1,
                colorHex: def.2,
                orderIndex: index,
                schedule: schedule
            )
            context.insert(item)
        }

        do {
            try context.save()
        } catch {
            print("[DewTime] SampleData の保存に失敗しました: \(error)")
        }
    }
}
