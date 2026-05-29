import Foundation

enum FlowerSpecies: String, CaseIterable, Identifiable {
    case clover, cactus, daisy, lavender, bamboo
    case iris, lily, rose, hydrangea, tulip
    case lotus, sakura, sunflower, orchid, plumeria

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .clover:    return "クローバー"
        case .cactus:    return "サボテン"
        case .daisy:     return "デイジー"
        case .lavender:  return "ラベンダー"
        case .bamboo:    return "タケ"
        case .iris:      return "アヤメ"
        case .lily:      return "ユリ"
        case .rose:      return "ローズ"
        case .hydrangea: return "アジサイ"
        case .tulip:     return "チューリップ"
        case .lotus:     return "ハス"
        case .sakura:    return "さくら"
        case .sunflower: return "ひまわり"
        case .orchid:    return "ラン"
        case .plumeria:  return "プルメリア"
        }
    }

    var icon: String {
        switch self {
        case .clover:    return "leaf.arrow.circlepath"
        case .cactus:    return "leaf.fill"
        case .daisy:     return "camera.macro"
        case .lavender:  return "wind"
        case .bamboo:    return "chart.bar.fill"
        case .iris:      return "star.fill"
        case .lily:      return "moon.fill"
        case .rose:      return "rosette"
        case .hydrangea: return "hexagon.fill"
        case .tulip:     return "flame.fill"
        case .lotus:     return "seal.fill"
        case .sakura:    return "allergens"
        case .sunflower: return "sun.max.fill"
        case .orchid:    return "sparkle"
        case .plumeria:  return "tropicalstorm"
        }
    }

    var requiredWaterRatio: Double {
        switch self {
        case .clover:    return 0.10
        case .cactus:    return 0.20
        case .daisy:     return 0.30
        case .lavender:  return 0.38
        case .bamboo:    return 0.45
        case .iris:      return 0.50
        case .lily:      return 0.55
        case .rose:      return 0.60
        case .hydrangea: return 0.65
        case .tulip:     return 0.68
        case .lotus:     return 0.72
        case .sakura:    return 0.75
        case .sunflower: return 0.80
        case .orchid:    return 0.86
        case .plumeria:  return 0.92
        }
    }

    var requiredTotalWaterRange: ClosedRange<Int> {
        switch self {
        case .clover:    return 50...90
        case .cactus:    return 80...130
        case .daisy:     return 100...160
        case .lavender:  return 130...190
        case .bamboo:    return 150...210
        case .iris:      return 160...230
        case .lily:      return 175...250
        case .rose:      return 190...270
        case .hydrangea: return 210...300
        case .tulip:     return 230...330
        case .lotus:     return 255...370
        case .sakura:    return 270...390
        case .sunflower: return 290...430
        case .orchid:    return 320...460
        case .plumeria:  return 350...500
        }
    }

    func makeRequiredTotalWater() -> Double {
        Double(Int.random(in: requiredTotalWaterRange))
    }

    var requiredWaterPercentText: String {
        "\(Int((requiredWaterRatio * 100).rounded()))%"
    }

    var requiredTotalWaterRangeText: String {
        "\(requiredTotalWaterRange.lowerBound)-\(requiredTotalWaterRange.upperBound)pt"
    }

    var difficultyLabel: String {
        switch requiredWaterRatio {
        case ..<0.25: return "かんたん"
        case ..<0.50: return "やさしい"
        case ..<0.70: return "ふつう"
        case ..<0.85: return "むずかしい"
        default: return "超むずかしい"
        }
    }
}
