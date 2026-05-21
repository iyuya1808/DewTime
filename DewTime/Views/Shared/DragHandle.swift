import SwiftUI

/// シートの上部に表示するドラッグハンドル
struct DragHandle: View {
    var body: some View {
        Capsule()
            .fill(Color.white.opacity(0.18))
            .frame(width: 40, height: 4)
            .padding(.top, 14)
    }
}
