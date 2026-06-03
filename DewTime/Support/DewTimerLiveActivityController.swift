import ActivityKit
import Foundation

@MainActor
enum DewTimerLiveActivityController {
    private static var currentActivity: Activity<DewTimerActivityAttributes>? {
        Activity<DewTimerActivityAttributes>.activities.first
    }

    static var activitiesAreEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    static func start(
        attributes: DewTimerActivityAttributes,
        state: DewTimerActivityAttributes.ContentState
    ) async {
        guard activitiesAreEnabled else { return }

        if let currentActivity {
            await currentActivity.update(ActivityContent(state: state, staleDate: nil))
            return
        }

        do {
            _ = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            print("[DewTime] Live Activity の開始に失敗しました: \(error)")
        }
    }

    static func update(state: DewTimerActivityAttributes.ContentState) async {
        guard activitiesAreEnabled, let currentActivity else { return }
        await currentActivity.update(ActivityContent(state: state, staleDate: nil))
    }

    static func end(state: DewTimerActivityAttributes.ContentState, immediately: Bool = true) async {
        guard let currentActivity else { return }
        await currentActivity.end(
            ActivityContent(state: state, staleDate: nil),
            dismissalPolicy: immediately ? .immediate : .default
        )
    }
}
