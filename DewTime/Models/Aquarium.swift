import Foundation
import Observation

/// 水槽成長の土台モデル。
///
/// オンタイム出発のたびに `totalDepartures` が増え、
/// 累積数が増えるほど水槽サイズ（`sizeTier`）が大きくなり、より大きな魚を飼える。
@Observable
final class Aquarium: Identifiable {
    var id: UUID
    var totalDepartures: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        totalDepartures: Int = 0,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.totalDepartures = totalDepartures
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static let tierThresholds: [Int] = [0, 10, 30, 60, 100, 150, 200]

    /// 各サイズ段階で泳がせられる成魚の上限（種類による表示制限は設けない）。
    static let fishCapacityByTier: [Int] = [5, 10, 20, 35, 50, 70, 100]

    static let maxTier = tierThresholds.count - 1

    var sizeTier: Int {
        var tier = 0
        for (index, threshold) in Self.tierThresholds.enumerated() where totalDepartures >= threshold {
            tier = index
        }
        return tier
    }

    var fishCapacity: Int {
        Self.fishCapacity(for: sizeTier)
    }

    var isMaxTier: Bool {
        sizeTier >= Self.maxTier
    }

    /// 次の段階までに必要なオンタイム出発の残り回数。最大段階では `nil`。
    var departuresUntilNextTier: Int? {
        guard !isMaxTier else { return nil }
        let nextThreshold = Self.tierThresholds[sizeTier + 1]
        return max(0, nextThreshold - totalDepartures)
    }

    /// 現在の段階内での成長進捗（0...1）。最大段階では 1。
    var progressToNextTier: Double {
        guard !isMaxTier else { return 1 }
        let currentThreshold = Self.tierThresholds[sizeTier]
        let nextThreshold = Self.tierThresholds[sizeTier + 1]
        let span = max(1, nextThreshold - currentThreshold)
        return min(1, max(0, Double(totalDepartures - currentThreshold) / Double(span)))
    }

    var sizeName: String {
        Self.sizeName(for: sizeTier)
    }

    static func fishCapacity(for tier: Int) -> Int {
        let clamped = max(0, min(tier, fishCapacityByTier.count - 1))
        return fishCapacityByTier[clamped]
    }

    static func sizeName(for tier: Int) -> String {
        switch tier {
        case 0: return "ミニ水槽"
        case 1: return "小型水槽"
        case 2: return "中型水槽"
        case 3: return "大型水槽"
        case 4: return "特大水槽"
        case 5: return "アクアリウム"
        default: return "大水族館"
        }
    }
}
