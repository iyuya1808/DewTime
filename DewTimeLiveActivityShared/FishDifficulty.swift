import Foundation

/// 魚種の難易度（表示文字列ではなく内部キーで比較する）。
enum FishDifficulty: Int, CaseIterable, Comparable {
    case veryEasy = 0
    case easy
    case normal
    case hard
    case veryHard

    static func < (lhs: FishDifficulty, rhs: FishDifficulty) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    static func from(requiredWaterRatio: Double) -> FishDifficulty {
        switch requiredWaterRatio {
        case ..<0.25: return .veryEasy
        case ..<0.50: return .easy
        case ..<0.70: return .normal
        case ..<0.85: return .hard
        default: return .veryHard
        }
    }

    /// 図鑑フィルタ用の粗い難易度帯。
    var filterBand: DifficultyFilterBand {
        switch self {
        case .veryEasy, .easy: return .easy
        case .normal: return .normal
        case .hard, .veryHard: return .hard
        }
    }

    var displayName: String {
        switch self {
        case .veryEasy:
            return LocalizationManager.shared.localized("fish.difficulty.very_easy", default: "かんたん")
        case .easy:
            return LocalizationManager.shared.localized("fish.difficulty.easy", default: "易しい")
        case .normal:
            return LocalizationManager.shared.localized("fish.difficulty.normal", default: "普通")
        case .hard:
            return LocalizationManager.shared.localized("fish.difficulty.hard", default: "難しい")
        case .veryHard:
            return LocalizationManager.shared.localized("fish.difficulty.very_hard", default: "超難しい")
        }
    }
}

/// 図鑑の難易度フィルタ（ローカライズ非依存の内部キー）。
enum DifficultyFilterBand: String, CaseIterable, Identifiable {
    case all
    case easy
    case normal
    case hard

    var id: String { rawValue }

    var starCount: Int {
        switch self {
        case .all: return 0
        case .easy: return 1
        case .normal: return 2
        case .hard: return 3
        }
    }

    static var selectableCases: [DifficultyFilterBand] {
        [.easy, .normal, .hard]
    }

    var displayName: String {
        switch self {
        case .all:
            return LocalizationManager.shared.localized("collection.filter.all", default: "すべて")
        case .easy:
            return LocalizationManager.shared.localized("fish.difficulty.easy", default: "易しい")
        case .normal:
            return LocalizationManager.shared.localized("fish.difficulty.normal", default: "普通")
        case .hard:
            return LocalizationManager.shared.localized("fish.difficulty.hard", default: "難しい")
        }
    }
}
