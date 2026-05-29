import Foundation

enum GrowthStage: String, CaseIterable, Identifiable {
    case seed, sprout, leaves, bloom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .seed: return "種"
        case .sprout: return "芽"
        case .leaves: return "葉っぱ"
        case .bloom: return "開花"
        }
    }

    var message: String {
        switch self {
        case .seed: return "種をまきました"
        case .sprout: return "芽が出ました"
        case .leaves: return "葉っぱが出てきました"
        case .bloom: return "花が咲きました"
        }
    }

    var icon: String {
        switch self {
        case .seed: return "circle.dotted"
        case .sprout: return "leaf.fill"
        case .leaves: return "laurel.leading"
        case .bloom: return "sparkles"
        }
    }

    static func stage(for progress: Double) -> GrowthStage {
        if progress >= 1.0 { return .bloom }
        if progress >= 0.55 { return .leaves }
        if progress >= 0.25 { return .sprout }
        return .seed
    }
}
