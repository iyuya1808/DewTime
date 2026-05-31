import Foundation

enum DepartureTimeDefaults {
    static func fifteenMinutesFromNow(
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Date {
        let roundedNow = calendar.nextDate(
            after: now,
            matching: DateComponents(second: 0),
            matchingPolicy: .nextTimePreservingSmallerComponents
        ) ?? now

        return calendar.date(byAdding: .minute, value: 15, to: roundedNow)
            ?? roundedNow.addingTimeInterval(15 * 60)
    }
}
