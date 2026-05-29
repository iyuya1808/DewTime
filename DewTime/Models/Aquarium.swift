import Foundation
import SwiftData

/// 水槽成長の土台モデル。
///
/// 出発のたびに、その朝水槽に注いだ水量を `totalWaterCollected` に累積する。
/// 累積量が増えるほど水槽サイズ（`sizeTier`）が大きくなり、より大きな魚を飼える――
/// というゲーム要素の基盤となる。サイズ拡大の視覚化や大型魚の解放ロジックは次フェーズ。
///
/// アプリ内で 1 レコードのみ存在する想定（初回の出発時に lazy 生成）。
@Model
final class Aquarium {
    @Attribute(.unique) var id: UUID
    /// 累積で水槽に注がれた水（永続成長メトリック）。
    var totalWaterCollected: Double
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        totalWaterCollected: Double = 0,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.totalWaterCollected = totalWaterCollected
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// 累積水量のしきい値（暫定）。次フェーズでバランス調整する。
    static let tierThresholds: [Double] = [0, 500, 1500, 3000, 5000, 8000, 12000]

    /// 現在の水槽サイズ段階（0 始まり）。
    var sizeTier: Int {
        var tier = 0
        for (index, threshold) in Self.tierThresholds.enumerated() where totalWaterCollected >= threshold {
            tier = index
        }
        return tier
    }

    /// 水槽サイズ段階の表示名（暫定）。
    var sizeName: String {
        switch sizeTier {
        case 0: return "ミニ水槽"
        case 1: return "小型水槽"
        case 2: return "中型水槽"
        case 3: return "大型水槽"
        case 4: return "特大水槽"
        case 5: return "アクアリウム"
        default: return "大水族館"
        }
    }

    /// サイズ段階に応じた容量（暫定）。次フェーズの視覚化・解放条件で使う。
    var capacity: Double {
        Double(sizeTier + 1) * 500
    }
}
