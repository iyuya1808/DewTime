import Foundation
import Observation

struct QuickTimerRequest: Equatable, Identifiable {
    let id = UUID()
    let minutes: Int
}

@Observable
@MainActor
final class QuickTimerDeepLinkRouter {
    private(set) var pendingRequest: QuickTimerRequest?

    func handle(_ url: URL) {
        guard url.scheme?.lowercased() == "dewtime",
              url.host?.lowercased() == "start-timer" else {
            return
        }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let minutesValue = components?
            .queryItems?
            .first(where: { $0.name == "minutes" })?
            .value

        guard let minutesValue,
              let minutes = Int(minutesValue),
              [15, 30, 45, 60].contains(minutes) else {
            return
        }

        pendingRequest = QuickTimerRequest(minutes: minutes)
    }

    func consume(_ request: QuickTimerRequest) {
        guard pendingRequest == request else { return }
        pendingRequest = nil
    }
}
