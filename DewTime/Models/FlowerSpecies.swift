import Foundation

enum FlowerSpecies: String, CaseIterable {
    case sunflower, tulip, rose, cactus, daisy

    var icon: String {
        switch self {
        case .sunflower: return "sun.max.fill"
        case .tulip:     return "flame.fill"
        case .rose:      return "rosette"
        case .cactus:    return "leaf.fill"
        case .daisy:     return "camera.macro"
        }
    }

    /// 水量に応じて花の種類を決める（水量が高いほど鮮やかな花）
    static func pick(for waterRatio: Double) -> FlowerSpecies {
        if waterRatio >= 0.8 { return .sunflower }
        if waterRatio >= 0.6 { return .tulip }
        if waterRatio >= 0.4 { return .rose }
        if waterRatio >= 0.2 { return .daisy }
        return .cactus
    }
}
