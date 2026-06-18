import SwiftUI

/// 餌（エサ）を表すアイコン。葉っぱではなくペレット形で統一する。
enum FeedIcon {
    static let systemName = "circle.fill"
    static let compactSymbol = "●"
}

struct FeedPelletGlyph: View {
    var size: CGFloat = 10

    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.95, green: 0.7, blue: 0.35),
                        Color(red: 0.82, green: 0.48, blue: 0.22)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.18), radius: 1, y: 0.5)
    }
}
