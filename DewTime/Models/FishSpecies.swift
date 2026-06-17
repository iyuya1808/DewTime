import CoreGraphics
import Foundation

enum FishDisplayContext {
    /// タイマータブの水タンク内（1匹が泳ぐ）
    case timer
    /// 水槽タブのライブ水槽（複数匹が泳ぐ）
    case aquarium
}

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

    /// 種ごとの見た目の大きさ（0=最小 … 1=最大）。描画サイズ・泳ぎ速度の基準。
    var visualSizeFactor: Double {
        switch self {
        case .shrimp:     return 0.05
        case .medaka:     return 0.10
        case .guppy:      return 0.15
        case .pufferfish: return 0.28
        case .crab:       return 0.32
        case .turtle:     return 0.38
        case .squid:      return 0.42
        case .lobster:    return 0.44
        case .octopus:    return 0.48
        case .jellyfish:  return 0.52
        case .seal:       return 0.58
        case .dolphin:    return 0.68
        case .shark:      return 0.78
        case .whale:      return 0.90
        case .whaleShark: return 1.0
        }
    }

    /// 画面上の描画サイズ（pt）。小型魚と大型魚の差がはっきり出るよう非線形にスケールする。
    func displaySize(for context: FishDisplayContext) -> CGFloat {
        let (minSize, maxSize): (CGFloat, CGFloat) = switch context {
        case .timer:    (28, 165)
        case .aquarium: (20, 105)
        }
        // 指数 > 1 で小型魚を抑え、大型魚をより大きく見せる
        let t = CGFloat(pow(visualSizeFactor, 1.25))
        return minSize + t * (maxSize - minSize)
    }

    /// 水槽内の巡航速度（正規化単位/秒）。小さい魚ほど速く泳ぐ。
    var aquariumSwimSpeed: CGFloat {
        0.14 - CGFloat(visualSizeFactor) * 0.08
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

    /// 成魚になるために必要なしずく数（オンタイム出発の回数）。
    var requiredDepartures: Int {
        switch requiredWaterRatio {
        case ..<0.25: return 1
        case ..<0.50: return 2
        case ..<0.70: return 3
        case ..<0.85: return 5
        default:      return 7
        }
    }

    var requiredDeparturesText: String {
        "\(requiredDepartures)しずく"
    }

    var requiredWaterPercentText: String {
        "\(Int((requiredWaterRatio * 100).rounded()))%"
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

    /// 飼育に必要な水槽サイズ段階。水槽が育つほど大型の魚が選べる。
    var requiredAquariumTier: Int {
        switch self {
        case .medaka, .guppy, .shrimp:
            return 0
        case .pufferfish, .crab, .turtle:
            return 1
        case .squid, .octopus, .lobster:
            return 2
        case .jellyfish, .seal:
            return 3
        case .dolphin, .shark:
            return 4
        case .whale:
            return 5
        case .whaleShark:
            return 6
        }
    }

    var requiredAquariumName: String {
        Aquarium.sizeName(for: requiredAquariumTier)
    }

    func isUnlocked(aquariumTier: Int) -> Bool {
        aquariumTier >= requiredAquariumTier
    }
}
