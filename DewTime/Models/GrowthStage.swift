import Foundation

enum GrowthStage: String, CaseIterable, Identifiable {
    case egg, fry, juvenile, adult

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .egg: return "卵"
        case .fry: return "稚魚"
        case .juvenile: return "幼魚"
        case .adult: return "成魚"
        }
    }

    var message: String {
        switch self {
        case .egg: return "卵を水槽に入れました"
        case .fry: return "稚魚が生まれました"
        case .juvenile: return "幼魚に育ちました"
        case .adult: return "成魚に育ちました"
        }
    }

    var icon: String {
        switch self {
        case .egg: return "circle.dotted"
        case .fry: return "fish"
        case .juvenile: return "fish.fill"
        case .adult: return "sparkles"
        }
    }

    static func stage(for progress: Double) -> GrowthStage {
        if progress >= 1.0 { return .adult }
        if progress >= 0.55 { return .juvenile }
        if progress >= 0.25 { return .fry }
        return .egg
    }
}
