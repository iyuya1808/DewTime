import Foundation

/// 言語設定の解決と String Catalog 用 Bundle の提供。
/// App / Live Activity / Widget で共有する。
final class LocalizationManager: @unchecked Sendable {
    static let shared = LocalizationManager()
    static let languageDidChangeNotification = Notification.Name("DewTime.languageDidChange")
    static let storageKey = "dew.preferences.appLanguage"

    private let defaults: UserDefaults?

    private init() {
        defaults = UserDefaults(suiteName: SharedTimerWidgetState.appGroupIdentifier)
    }

    var language: AppLanguage {
        get {
            guard let raw = defaults?.string(forKey: Self.storageKey),
                  let value = AppLanguage(rawValue: raw) else {
                return .system
            }
            return value
        }
        set {
            defaults?.set(newValue.rawValue, forKey: Self.storageKey)
            NotificationCenter.default.post(name: Self.languageDidChangeNotification, object: nil)
        }
    }

    var locale: Locale {
        if let identifier = language.localeIdentifier {
            return Locale(identifier: identifier)
        }
        return .autoupdatingCurrent
    }

    private var resourceBundle: Bundle {
        Bundle(for: LocalizationManager.self)
    }

    var bundle: Bundle {
        guard let identifier = language.localeIdentifier,
              let path = resourceBundle.path(forResource: identifier, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return resourceBundle
        }
        return bundle
    }

    func localized(_ key: String, default defaultValue: String) -> String {
        let value = bundle.localizedString(forKey: key, value: defaultValue, table: "Localizable")
        if value != key || bundle != .main {
            return value
        }
        return defaultValue
    }

    func localized(_ key: String, default defaultValue: String, _ arguments: CVarArg...) -> String {
        let format = localized(key, default: defaultValue)
        return String(format: format, locale: locale, arguments: arguments)
    }
}
