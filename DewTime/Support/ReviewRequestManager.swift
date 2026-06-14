import Foundation

@MainActor
final class ReviewRequestManager {
    static let shared = ReviewRequestManager()
    private(set) var hasRequestedThisSession = false

    private let lastRequestDateKey = "lastReviewRequestDate"
    private let cooldownInterval: TimeInterval = 30 * 24 * 60 * 60 // 30日間（秒）

    private init() {}

    func tryRequest(for trigger: Trigger, action: () -> Void) {
        #if DEBUG
        // デバッグビルド時は開発・テストの邪魔になるため、レビュー要求をスキップします
        return
        #endif

        // 同一セッション内での重複表示を防止
        guard !hasRequestedThisSession else { return }

        // 最後にレビュー要求した日時から30日経過しているか確認
        if let lastDate = UserDefaults.standard.object(forKey: lastRequestDateKey) as? Date {
            let elapsed = Date().timeIntervalSince(lastDate)
            guard elapsed >= cooldownInterval else { return }
        }

        // 状態を更新して実行
        hasRequestedThisSession = true
        UserDefaults.standard.set(Date(), forKey: lastRequestDateKey)
        action()
    }

    enum Trigger {
        case departureResult
        case collectionTab
    }
}
