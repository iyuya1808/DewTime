import Foundation

enum FishSpecies: String, CaseIterable, Identifiable {
    case medaka, guppy, shrimp, pufferfish, crab
    case turtle, squid, octopus, lobster, jellyfish
    case seal, dolphin, shark, whale, whaleShark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .medaka:     return "メダカ"
        case .guppy:      return "グッピー"
        case .shrimp:     return "ミナミヌマエビ"
        case .pufferfish: return "フグ"
        case .crab:       return "カニ"
        case .turtle:     return "ミドリガメ"
        case .squid:      return "イカ"
        case .octopus:    return "タコ"
        case .lobster:    return "ロブスター"
        case .jellyfish:  return "クラゲ"
        case .seal:       return "アザラシ"
        case .dolphin:    return "イルカ"
        case .shark:      return "サメ"
        case .whale:      return "クジラ"
        case .whaleShark: return "ジンベエザメ"
        }
    }

    /// 一覧・選択で表示する絵文字。種類の見分けが付くよう絵文字で表現する。
    var emoji: String {
        switch self {
        case .medaka:     return "🐟"
        case .guppy:      return "🐠"
        case .shrimp:     return "🦐"
        case .pufferfish: return "🐡"
        case .crab:       return "🦀"
        case .turtle:     return "🐢"
        case .squid:      return "🦑"
        case .octopus:    return "🐙"
        case .lobster:    return "🦞"
        case .jellyfish:  return "🪼"
        case .seal:       return "🦭"
        case .dolphin:    return "🐬"
        case .shark:      return "🦈"
        case .whale:      return "🐋"
        case .whaleShark: return "🐳"
        }
    }

    /// SF Symbol フォールバック（絵文字を使えない箇所向け）。
    var icon: String {
        switch self {
        case .whale, .whaleShark, .dolphin, .shark:
            return "fish.fill"
        default:
            return "fish.fill"
        }
    }

    var requiredWaterRatio: Double {
        switch self {
        case .medaka:     return 0.10
        case .guppy:      return 0.20
        case .shrimp:     return 0.30
        case .pufferfish: return 0.38
        case .crab:       return 0.45
        case .turtle:     return 0.50
        case .squid:      return 0.55
        case .octopus:    return 0.60
        case .lobster:    return 0.65
        case .jellyfish:  return 0.68
        case .seal:       return 0.72
        case .dolphin:    return 0.75
        case .shark:      return 0.80
        case .whale:      return 0.86
        case .whaleShark: return 0.92
        }
    }

    var requiredTotalWaterRange: ClosedRange<Int> {
        switch self {
        case .medaka:     return 50...90
        case .guppy:      return 80...130
        case .shrimp:     return 100...160
        case .pufferfish: return 130...190
        case .crab:       return 150...210
        case .turtle:     return 160...230
        case .squid:      return 175...250
        case .octopus:    return 190...270
        case .lobster:    return 210...300
        case .jellyfish:  return 230...330
        case .seal:       return 255...370
        case .dolphin:    return 270...390
        case .shark:      return 290...430
        case .whale:      return 320...460
        case .whaleShark: return 350...500
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
