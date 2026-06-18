import Foundation

/// アプリ内言語設定。`system` は端末の言語設定に追従する。
enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case system
    case ja
    case en

    var id: String { rawValue }

    /// 設定 UI 用の表示名（言語名自体は各言語で固定表示）。
    var pickerLabel: String { L10n.Settings.languageName(self) }

    /// `nil` は端末ロケール追従を意味する。
    var localeIdentifier: String? {
        switch self {
        case .system: return nil
        case .ja: return "ja"
        case .en: return "en"
        }
    }
}
