import Foundation
import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .system: return "システム"
        case .light: return "ライト"
        case .dark: return "ダーク"
        }
    }
}

enum AquariumTheme: String, CaseIterable, Identifiable {
    case dewBlue = "dewBlue"
    case deepOcean = "deepOcean"
    case coralPink = "coralPink"
    case emeraldLagoon = "emeraldLagoon"

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .dewBlue: return "Dew Blue"
        case .deepOcean: return "Deep Ocean"
        case .coralPink: return "Coral Pink"
        case .emeraldLagoon: return "Emerald Lagoon"
        }
    }

    func tankColors(isDark: Bool, isOverdue: Bool) -> (top: Color, middle: Color, bottom: Color, glow: Color) {
        if isOverdue {
            return (
                Color(red: 0.95, green: 0.35, blue: 0.25),
                Color(red: 0.98, green: 0.24, blue: 0.20),
                Color(red: 0.70, green: 0.15, blue: 0.10),
                Color.orange
            )
        }

        switch self {
        case .dewBlue:
            if isDark {
                return (
                    Color(red: 0.15, green: 0.55, blue: 0.75),
                    Color(red: 0.04, green: 0.20, blue: 0.38),
                    Color(red: 0.01, green: 0.08, blue: 0.22),
                    Color(red: 0.00, green: 0.70, blue: 0.85)
                )
            } else {
                return (
                    Color(red: 0.42, green: 0.94, blue: 1.0),
                    Color(red: 0.25, green: 0.75, blue: 0.98),
                    Color(red: 0.05, green: 0.40, blue: 0.85),
                    Color(hex: "#0EC5FF")
                )
            }
        case .deepOcean:
            if isDark {
                return (
                    Color(red: 0.04, green: 0.20, blue: 0.45),
                    Color(red: 0.02, green: 0.10, blue: 0.28),
                    Color(red: 0.00, green: 0.04, blue: 0.15),
                    Color(red: 0.05, green: 0.30, blue: 0.70)
                )
            } else {
                return (
                    Color(red: 0.10, green: 0.45, blue: 0.85),
                    Color(red: 0.05, green: 0.25, blue: 0.60),
                    Color(red: 0.01, green: 0.10, blue: 0.35),
                    Color(red: 0.10, green: 0.50, blue: 0.95)
                )
            }
        case .coralPink:
            if isDark {
                return (
                    Color(red: 0.60, green: 0.30, blue: 0.35),
                    Color(red: 0.40, green: 0.15, blue: 0.20),
                    Color(red: 0.22, green: 0.05, blue: 0.08),
                    Color(red: 0.75, green: 0.20, blue: 0.40)
                )
            } else {
                return (
                    Color(red: 1.0, green: 0.70, blue: 0.75),
                    Color(red: 1.0, green: 0.50, blue: 0.55),
                    Color(red: 0.85, green: 0.25, blue: 0.35),
                    Color(red: 1.0, green: 0.45, blue: 0.60)
                )
            }
        case .emeraldLagoon:
            if isDark {
                return (
                    Color(red: 0.12, green: 0.50, blue: 0.42),
                    Color(red: 0.04, green: 0.30, blue: 0.24),
                    Color(red: 0.01, green: 0.15, blue: 0.12),
                    Color(red: 0.08, green: 0.60, blue: 0.48)
                )
            } else {
                return (
                    Color(red: 0.40, green: 0.98, blue: 0.80),
                    Color(red: 0.10, green: 0.80, blue: 0.65),
                    Color(red: 0.02, green: 0.45, blue: 0.38),
                    Color(red: 0.15, green: 0.90, blue: 0.75)
                )
            }
        }
    }

    func tankBackgroundColors(isDark: Bool) -> [Color] {
        switch self {
        case .dewBlue:
            return isDark
                ? [Color(red: 0.005, green: 0.02, blue: 0.08), Color(red: 0.015, green: 0.05, blue: 0.14)]
                : [Color(red: 0.02, green: 0.07, blue: 0.18), Color(red: 0.03, green: 0.14, blue: 0.27)]
        case .deepOcean:
            return isDark
                ? [Color(red: 0.002, green: 0.01, blue: 0.04), Color(red: 0.008, green: 0.03, blue: 0.10)]
                : [Color(red: 0.01, green: 0.04, blue: 0.12), Color(red: 0.02, green: 0.08, blue: 0.20)]
        case .coralPink:
            return isDark
                ? [Color(red: 0.08, green: 0.01, blue: 0.02), Color(red: 0.12, green: 0.02, blue: 0.04)]
                : [Color(red: 0.15, green: 0.05, blue: 0.08), Color(red: 0.22, green: 0.08, blue: 0.12)]
        case .emeraldLagoon:
            return isDark
                ? [Color(red: 0.005, green: 0.04, blue: 0.04), Color(red: 0.01, green: 0.08, blue: 0.08)]
                : [Color(red: 0.02, green: 0.14, blue: 0.14), Color(red: 0.03, green: 0.20, blue: 0.18)]
        }
    }

    func liveAquariumColors(isDark: Bool) -> [Color] {
        switch self {
        case .dewBlue:
            return isDark
                ? [Color(red: 0.03, green: 0.08, blue: 0.20), Color(red: 0.02, green: 0.05, blue: 0.14), Color(red: 0.01, green: 0.02, blue: 0.08)]
                : [Color(red: 0.36, green: 0.74, blue: 0.92), Color(red: 0.13, green: 0.46, blue: 0.78), Color(red: 0.06, green: 0.28, blue: 0.55)]
        case .deepOcean:
            return isDark
                ? [Color(red: 0.02, green: 0.05, blue: 0.18), Color(red: 0.01, green: 0.03, blue: 0.12), Color(red: 0.00, green: 0.01, blue: 0.06)]
                : [Color(red: 0.20, green: 0.50, blue: 0.85), Color(red: 0.08, green: 0.28, blue: 0.62), Color(red: 0.02, green: 0.12, blue: 0.40)]
        case .coralPink:
            return isDark
                ? [Color(red: 0.18, green: 0.06, blue: 0.10), Color(red: 0.12, green: 0.03, blue: 0.06), Color(red: 0.06, green: 0.01, blue: 0.02)]
                : [Color(red: 0.98, green: 0.65, blue: 0.70), Color(red: 0.88, green: 0.40, blue: 0.48), Color(red: 0.70, green: 0.20, blue: 0.30)]
        case .emeraldLagoon:
            return isDark
                ? [Color(red: 0.04, green: 0.16, blue: 0.14), Color(red: 0.02, green: 0.10, blue: 0.08), Color(red: 0.01, green: 0.05, blue: 0.04)]
                : [Color(red: 0.38, green: 0.88, blue: 0.72), Color(red: 0.12, green: 0.65, blue: 0.52), Color(red: 0.04, green: 0.40, blue: 0.32)]
        }
    }

    func liveAquariumLightRayColor(isDark: Bool) -> Color {
        switch self {
        case .dewBlue:
            return isDark ? Color(red: 0.35, green: 0.75, blue: 1.0).opacity(0.06) : Color.white.opacity(0.10)
        case .deepOcean:
            return isDark ? Color(red: 0.25, green: 0.55, blue: 0.95).opacity(0.05) : Color.white.opacity(0.08)
        case .coralPink:
            return isDark ? Color(red: 0.95, green: 0.55, blue: 0.65).opacity(0.07) : Color.white.opacity(0.12)
        case .emeraldLagoon:
            return isDark ? Color(red: 0.35, green: 0.95, blue: 0.75).opacity(0.07) : Color.white.opacity(0.11)
        }
    }

    func liveAquariumSandColors(isDark: Bool) -> [Color] {
        switch self {
        case .dewBlue, .deepOcean:
            return isDark
                ? [Color(red: 0.22, green: 0.26, blue: 0.38), Color(red: 0.13, green: 0.15, blue: 0.24)]
                : [Color(red: 0.93, green: 0.86, blue: 0.66), Color(red: 0.82, green: 0.72, blue: 0.50)]
        case .coralPink:
            return isDark
                ? [Color(red: 0.32, green: 0.20, blue: 0.24), Color(red: 0.20, green: 0.12, blue: 0.15)]
                : [Color(red: 0.95, green: 0.80, blue: 0.78), Color(red: 0.84, green: 0.66, blue: 0.64)]
        case .emeraldLagoon:
            return isDark
                ? [Color(red: 0.20, green: 0.28, blue: 0.26), Color(red: 0.12, green: 0.18, blue: 0.16)]
                : [Color(red: 0.90, green: 0.88, blue: 0.74), Color(red: 0.78, green: 0.75, blue: 0.58)]
        }
    }

    func liveAquariumSeaweedColors(isDark: Bool) -> [Color] {
        switch self {
        case .dewBlue, .deepOcean:
            return isDark
                ? [
                    Color(red: 0.08, green: 0.28, blue: 0.22),
                    Color(red: 0.12, green: 0.34, blue: 0.26),
                    Color(red: 0.07, green: 0.26, blue: 0.20),
                    Color(red: 0.14, green: 0.36, blue: 0.28),
                    Color(red: 0.10, green: 0.30, blue: 0.24)
                ]
                : [
                    Color(red: 0.18, green: 0.55, blue: 0.36),
                    Color(red: 0.25, green: 0.62, blue: 0.42),
                    Color(red: 0.16, green: 0.50, blue: 0.34),
                    Color(red: 0.28, green: 0.66, blue: 0.45),
                    Color(red: 0.22, green: 0.58, blue: 0.40)
                ]
        case .coralPink:
            return isDark
                ? [
                    Color(red: 0.24, green: 0.10, blue: 0.18),
                    Color(red: 0.30, green: 0.14, blue: 0.22),
                    Color(red: 0.22, green: 0.08, blue: 0.16),
                    Color(red: 0.34, green: 0.16, blue: 0.26),
                    Color(red: 0.28, green: 0.12, blue: 0.20)
                ]
                : [
                    Color(red: 0.58, green: 0.22, blue: 0.40),
                    Color(red: 0.66, green: 0.28, blue: 0.48),
                    Color(red: 0.52, green: 0.18, blue: 0.36),
                    Color(red: 0.70, green: 0.34, blue: 0.54),
                    Color(red: 0.60, green: 0.26, blue: 0.44)
                ]
        case .emeraldLagoon:
            return isDark
                ? [
                    Color(red: 0.06, green: 0.30, blue: 0.18),
                    Color(red: 0.10, green: 0.36, blue: 0.22),
                    Color(red: 0.05, green: 0.26, blue: 0.16),
                    Color(red: 0.12, green: 0.40, blue: 0.24),
                    Color(red: 0.08, green: 0.32, blue: 0.20)
                ]
                : [
                    Color(red: 0.25, green: 0.66, blue: 0.30),
                    Color(red: 0.32, green: 0.75, blue: 0.38),
                    Color(red: 0.20, green: 0.60, blue: 0.26),
                    Color(red: 0.38, green: 0.82, blue: 0.45),
                    Color(red: 0.28, green: 0.70, blue: 0.34)
                ]
        }
    }
}

enum AppPreferences {
    enum Key: String {
        case notificationsEnabled = "dew.preferences.notificationsEnabled"
        case departureReminderEnabled = "dew.preferences.departureReminderEnabled"
        case departureReminderMinutes = "dew.preferences.departureReminderMinutes"
        case hapticsEnabled = "dew.preferences.hapticsEnabled"
        case appTheme = "dew.preferences.appTheme"
        case aquariumTheme = "dew.preferences.aquariumTheme"
    }

    static let reminderMinuteOptions = [3, 5, 10, 15]

    static var notificationsEnabled: Bool {
        bool(for: .notificationsEnabled, default: true)
    }

    static var departureReminderEnabled: Bool {
        bool(for: .departureReminderEnabled, default: true)
    }

    static var departureReminderMinutes: Int {
        let stored = UserDefaults.standard.object(forKey: Key.departureReminderMinutes.rawValue) as? Int ?? 5
        return reminderMinuteOptions.contains(stored) ? stored : 5
    }

    static var hapticsEnabled: Bool {
        bool(for: .hapticsEnabled, default: true)
    }

    static var appTheme: AppTheme {
        guard let stored = UserDefaults.standard.string(forKey: Key.appTheme.rawValue),
              let theme = AppTheme(rawValue: stored) else {
            return .system
        }
        return theme
    }

    static var aquariumTheme: AquariumTheme {
        guard let stored = UserDefaults.standard.string(forKey: Key.aquariumTheme.rawValue),
              let theme = AquariumTheme(rawValue: stored) else {
            return .dewBlue
        }
        return theme
    }

    private static func bool(for key: Key, default defaultValue: Bool) -> Bool {
        guard UserDefaults.standard.object(forKey: key.rawValue) != nil else {
            return defaultValue
        }
        return UserDefaults.standard.bool(forKey: key.rawValue)
    }
}
