import UserNotifications

enum NotificationScheduler {
    private static let center = UNUserNotificationCenter.current()

    static func requestPermission() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// スタート時に出発通知と5分前リマインダーをスケジュール
    static func schedule(departureAt date: Date, scheduleName: String) {
        cancelAll()
        scheduleNotification(
            id: "dew.departure",
            title: "出発時刻です！",
            body: "「\(scheduleName)」の出発時刻になりました",
            at: date
        )
        scheduleNotification(
            id: "dew.reminder5",
            title: "あと5分！",
            body: "「\(scheduleName)」の出発まであと5分です",
            at: date.addingTimeInterval(-5 * 60)
        )
    }

    static func cancelAll() {
        center.removePendingNotificationRequests(withIdentifiers: ["dew.departure", "dew.reminder5"])
    }

    private static func scheduleNotification(id: String, title: String, body: String, at date: Date) {
        guard date > .now else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = .default
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
