import SwiftUI

enum AppFont {
    // MARK: - Timer display
    static let countdown      = Font.system(size: 52, weight: .bold,     design: .rounded)
    static let countdownSmall = Font.system(size: 28, weight: .medium,   design: .rounded)
    static let departureTime  = Font.system(size: 42, weight: .bold,     design: .rounded)

    // MARK: - Water tank
    static let waterDisplay = Font.system(size: 44, weight: .bold,     design: .rounded)
    static let waterUnit    = Font.system(size: 16, weight: .semibold, design: .rounded)

    // MARK: - Sheet titles
    static let sheetTitle   = Font.system(size: 26, weight: .bold, design: .rounded)
    static let confirmTitle = Font.system(size: 22, weight: .bold, design: .rounded)

    // MARK: - Buttons
    static let actionButton = Font.system(size: 18, weight: .bold, design: .rounded)

    // MARK: - Data display
    static let badgeValue = Font.system(size: 16, weight: .bold, design: .rounded)
    static let statValue  = Font.system(size: 14, weight: .bold, design: .rounded)
    static let statLabel  = Font.system(size: 10)
}
