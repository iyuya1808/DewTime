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

    /// 出発時の演出用。まず `.departed` 状態へ更新して注水アニメを見せ、`lingerSeconds` 後に自動で消す。
    static func finishWithPour(state: DewTimerActivityAttributes.ContentState, lingerSeconds: TimeInterval = 4) async {
        guard let currentActivity else { return }
        await currentActivity.update(ActivityContent(state: state, staleDate: nil))
        await currentActivity.end(
            ActivityContent(state: state, staleDate: nil),
            dismissalPolicy: .after(Date.now.addingTimeInterval(lingerSeconds))
        )
    }
}
