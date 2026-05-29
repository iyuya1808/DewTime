import SwiftUI

extension Color {
    // MARK: - Brand
    static let dewBlue = Color(hex: "#0EC5FF")
    static let dewNavy = Color(hex: "#3A7BD5")

    // MARK: - Water level gradient endpoints
    static let dewWaterHigh1 = Color(hex: "#43C6AC")
    static let dewWaterHigh2 = Color(hex: "#0EC5FF")
    static let dewWaterMid1  = Color(hex: "#f7971e")
    static let dewWaterMid2  = Color(hex: "#ffd200")
    static let dewWaterLow1  = Color(hex: "#f953c6")
    static let dewWaterLow2  = Color(hex: "#b91d73")

    // MARK: - Water tank animation
    static let dewTankWaterTop      = Color(red: 0.25, green: 0.75, blue: 0.98)
    static let dewTankWaterBottom   = Color(red: 0.05, green: 0.40, blue: 0.85)
    static let dewTankOverdueTop    = Color(red: 0.95, green: 0.35, blue: 0.25)
    static let dewTankOverdueBottom = Color(red: 0.70, green: 0.15, blue: 0.10)

    // MARK: - Garden
    static let gardenTop    = Color(red: 0.92, green: 0.97, blue: 0.92)
    static let gardenBottom = Color(red: 0.78, green: 0.90, blue: 0.82)

    // MARK: - Routine task color palette
    static let routinePalette: [Color] = [
        Color(hex: "#4FC3F7"), Color(hex: "#81D4FA"), Color(hex: "#FFB74D"),
        Color(hex: "#FFCC80"), Color(hex: "#A5D6A7"), Color(hex: "#CE93D8"),
        Color(hex: "#F48FB1"), Color(hex: "#9FA8DA")
    ]
}
