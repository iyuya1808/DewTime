import Foundation

@MainActor
final class ReviewRequestManager {
    static let shared = ReviewRequestManager()
    private(set) var hasRequestedThisSession = false

    private init() {}

    func tryRequest(for trigger: Trigger, action: () -> Void) {
        guard !hasRequestedThisSession else { return }
        hasRequestedThisSession = true
        action()
    }

    enum Trigger {
        case departureResult
        case collectionTab
    }
}
