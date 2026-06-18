import SwiftUI

/// 起動ローディング。タイマータブと同じ水槽で、水位の上昇が進捗を表す。
/// 100% はデータ読み込みとシェル初期化が終わるまで到達しない。
struct AppLaunchLoadingView: View {
    let bootstrapComplete: Bool
    let onDismissed: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fillStart: Date?
    /// `bootstrapComplete` は View の `let` のため Task から読むと古い値が残る。@State で同期する。
    @State private var isBootstrapReady = false
    @State private var bootstrapReadyAt: Date?
    @State private var overlayOpacity: Double = 1
    @State private var hasDismissed = false

    /// 準備完了前に水位が止まる上限（100% は準備完了後だけ）。
    private var stallCap: Double { 0.88 }

    private var minDisplayDuration: TimeInterval {
        reduceMotion ? 0.25 : 0.4
    }

    /// 準備完了前に stallCap へ達するまでの目安時間。
    private var rampDuration: TimeInterval {
        reduceMotion ? 0.45 : 1.2
    }

    /// 準備完了後に 100% まで満たす時間。
    private var completionFillDuration: TimeInterval {
        reduceMotion ? 0.15 : 0.25
    }

    /// ブートストラップ異常時でもオーバーレイを閉じる上限。
    private var maxOverlayDuration: TimeInterval {
        reduceMotion ? 2.0 : 5.0
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let level = waterLevel(at: timeline.date)

            ZStack {
                LinearGradient.dewTimeDark
                    .ignoresSafeArea()

                WaterTankView(
                    waterLevel: level,
                    cornerRadius: 0,
                    showBorder: false
                )
                .ignoresSafeArea()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L10n.Launch.loadingAccessibility)
            .accessibilityValue(L10n.Launch.loadingValue(Int((level * 100).rounded())))
            .accessibilityAddTraits(level >= 0.99 ? [] : .updatesFrequently)
        }
        .opacity(overlayOpacity)
        .onAppear(perform: startFill)
        .onChange(of: bootstrapComplete) { _, complete in
            markBootstrapReady(complete)
        }
    }

    private func startFill() {
        fillStart = .now
        markBootstrapReady(bootstrapComplete)

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(maxOverlayDuration))
            tryDismiss(force: true)
        }
    }

    private func markBootstrapReady(_ complete: Bool) {
        guard complete, !isBootstrapReady else { return }
        isBootstrapReady = true
        if bootstrapReadyAt == nil {
            bootstrapReadyAt = .now
        }
        runDismissLoop()
    }

    private func runDismissLoop() {
        Task { @MainActor in
            while !hasDismissed {
                tryDismiss()
                if hasDismissed { break }
                try? await Task.sleep(for: .milliseconds(32))
            }
        }
    }

    private func tryDismiss(force: Bool = false) {
        guard !hasDismissed else { return }
        guard isBootstrapReady || force else { return }
        guard let fillStart else { return }

        let elapsed = Date.now.timeIntervalSince(fillStart)
        guard force || elapsed >= minDisplayDuration else { return }

        let level = waterLevel(at: .now)
        guard force || level >= 0.99 else { return }

        hasDismissed = true

        Task { @MainActor in
            let duration = reduceMotion ? 0.18 : 0.28
            withAnimation(.easeOut(duration: duration)) {
                overlayOpacity = 0
            } completion: {
                onDismissed()
            }
        }
    }

    private func waterLevel(at date: Date) -> Double {
        guard let fillStart else { return 0 }
        let elapsed = date.timeIntervalSince(fillStart)

        if isBootstrapReady, let bootstrapReadyAt {
            let rampLevel = rampLevel(at: bootstrapReadyAt.timeIntervalSince(fillStart))
            let sinceReady = date.timeIntervalSince(bootstrapReadyAt)
            let t = min(1, max(0, sinceReady / completionFillDuration))
            return rampLevel + (1 - rampLevel) * easeInOut(t)
        }

        let t = min(1, max(0, elapsed / rampDuration))
        return easeInOut(t) * stallCap
    }

    private func rampLevel(at elapsed: TimeInterval) -> Double {
        let t = min(1, max(0, elapsed / rampDuration))
        return easeInOut(t) * stallCap
    }

    private func easeInOut(_ t: Double) -> Double {
        t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }
}

#Preview {
    AppLaunchLoadingView(bootstrapComplete: false, onDismissed: {})
}
