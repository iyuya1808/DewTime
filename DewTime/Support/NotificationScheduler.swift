import UserNotifications
import CoreHaptics
import UIKit

enum NotificationScheduler {
    private static let center = UNUserNotificationCenter.current()

    static func requestPermission() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// スタート時に出発通知と5分前リマインダーをスケジュール
    static func schedule(departureAt date: Date, scheduleName: String) {
        cancelAll()
        guard AppPreferences.notificationsEnabled else { return }

        scheduleNotification(
            id: "dew.departure",
            title: "出発時刻です！",
            body: "「\(scheduleName)」の出発時刻になりました",
            at: date
        )

        guard AppPreferences.departureReminderEnabled else { return }
        let reminderMinutes = AppPreferences.departureReminderMinutes
        scheduleNotification(
            id: "dew.reminder5",
            title: "あと\(reminderMinutes)分！",
            body: "「\(scheduleName)」の出発まであと\(reminderMinutes)分です",
            at: date.addingTimeInterval(TimeInterval(-reminderMinutes * 60))
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

@MainActor
enum ScheduleHaptics {
    private static var engine: CHHapticEngine?

    static func prepare() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let newEngine = try CHHapticEngine()
            newEngine.stoppedHandler = { _ in
                Task { @MainActor in engine = nil }
            }
            newEngine.resetHandler = {
                Task { @MainActor in try? engine?.start() }
            }
            try newEngine.start()
            engine = newEngine
        } catch {
            engine = nil
        }
    }

    static func playPhaseKnock() {
        play(events: [
            transient(intensity: 0.38, sharpness: 0.18, at: 0),
            transient(intensity: 0.50, sharpness: 0.26, at: 0.13),
            transient(intensity: 0.34, sharpness: 0.16, at: 0.31)
        ], fallback: .medium)
    }

    static func playOverdueWarning() {
        var events: [CHHapticEvent] = []
        for index in 0..<8 {
            events.append(transient(intensity: 0.58, sharpness: 0.88, at: Double(index) * 0.045))
        }
        play(events: events, fallback: .heavy)
    }

    private static func play(events: [CHHapticEvent], fallback: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            UIImpactFeedbackGenerator(style: fallback).impactOccurred()
            return
        }

        if engine == nil { prepare() }
        do {
            guard let engine else { return }
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            UIImpactFeedbackGenerator(style: fallback).impactOccurred()
        }
    }

    private static func transient(intensity: Float, sharpness: Float, at time: TimeInterval) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ],
            relativeTime: time
        )
    }
}
