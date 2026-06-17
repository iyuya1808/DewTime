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

    var sizeTier: Int {
        var tier = 0
        for (index, threshold) in Self.tierThresholds.enumerated() where totalDepartures >= threshold {
            tier = index
        }
        return tier
    }

    var sizeName: String {
        Self.sizeName(for: sizeTier)
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
