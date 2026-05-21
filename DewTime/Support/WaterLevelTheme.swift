import SwiftUI

/// 水量（0.0〜1.0）に応じた色・グラデーションを一元管理する
struct WaterLevelTheme {
    let waterRatio: Double

    var tintColor: Color {
        if waterRatio > 0.6 { return .cyan }
        if waterRatio > 0.3 { return .yellow }
        return .orange
    }

    var gradientColors: [Color] {
        if waterRatio > 0.6 { return [.dewWaterHigh1, .dewWaterHigh2] }
        if waterRatio > 0.3 { return [.dewWaterMid1,  .dewWaterMid2] }
        return [.dewWaterLow1, .dewWaterLow2]
    }

    var gradient: LinearGradient {
        LinearGradient(colors: gradientColors, startPoint: .leading, endPoint: .trailing)
    }
}

extension LinearGradient {
    /// タイマー画面などのメイン背景
    static let dewTimeDark = LinearGradient(
        colors: [Color(red: 0.05, green: 0.08, blue: 0.20),
                 Color(red: 0.08, green: 0.14, blue: 0.28)],
        startPoint: .top,
        endPoint: .bottom
    )

    /// シート（確認・結果）画面の背景
    static let dewTimeSheet = LinearGradient(
        colors: [Color(red: 0.06, green: 0.10, blue: 0.22),
                 Color(red: 0.04, green: 0.06, blue: 0.16)],
        startPoint: .top,
        endPoint: .bottom
    )
}
