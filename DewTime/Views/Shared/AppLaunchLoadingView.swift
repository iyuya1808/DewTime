import SwiftUI

/// 起動ローディング。タイマータブと同じ水槽で、水位の上昇が進捗を表す。
struct AppLaunchLoadingView: View {
    let bootstrapComplete: Bool
    let onDismissed: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fillStart: Date?
    @State private var fillAnimationDone = false
    @State private var overlayOpacity: Double = 1
    @State private var hasDismissed = false

    private var fillDuration: TimeInterval {
        reduceMotion ? 0.35 : 2.2
    }

    /// ブートストラップ異常時でもオーバーレイを閉じる上限。
    private var maxOverlayDuration: TimeInterval {
        reduceMotion ? 1.2 : 6.0
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
            .accessibilityLabel("起動準備中。水がたまっています")
            .accessibilityValue("\(Int((level * 100).rounded()))パーセント")
            .accessibilityAddTraits(fillAnimationDone ? [] : .updatesFrequently)
        }
        .opacity(overlayOpacity)
        .onAppear(perform: startFill)
        .onChange(of: bootstrapComplete) { _, _ in
            tryDismiss()
        }
    }

    private func startFill() {
        fillStart = .now
        fillAnimationDone = false

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(fillDuration))
            fillAnimationDone = true
            tryDismiss()
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(maxOverlayDuration))
            fillAnimationDone = true
            tryDismiss(force: true)
        }
    }

    private func tryDismiss(force: Bool = false) {
        guard (bootstrapComplete || force), fillAnimationDone, !hasDismissed else { return }
        hasDismissed = true

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(280))
            let duration = reduceMotion ? 0.22 : 0.38
            withAnimation(.easeOut(duration: duration)) {
                overlayOpacity = 0
            } completion: {
                onDismissed()
            }
        }
    }

    private func waterLevel(at date: Date) -> Double {
        guard let fillStart else { return 0 }
        let raw = min(1, max(0, date.timeIntervalSince(fillStart) / fillDuration))
        return easeInOut(raw)
    }

    private func easeInOut(_ t: Double) -> Double {
        t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }
}

#Preview {
    AppLaunchLoadingView(bootstrapComplete: false, onDismissed: {})
}
