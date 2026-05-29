import Foundation
import SwiftData

@Model
final class PlantWateringRecord {
    @Attribute(.unique) var id: UUID
    var speciesId: String
    var recordedAt: Date
    var waterAmount: Double
    var totalWaterAfter: Double
    var requiredTotalWater: Double
    var growthStageRawValue: String
    var completedGrowth: Bool

    init(
        id: UUID = UUID(),
        speciesId: String,
        recordedAt: Date = .now,
        waterAmount: Double,
        totalWaterAfter: Double,
        requiredTotalWater: Double,
        growthStage: GrowthStage,
        completedGrowth: Bool
    ) {
        self.id = id
        self.speciesId = speciesId
        self.recordedAt = recordedAt
        self.waterAmount = waterAmount
        self.totalWaterAfter = totalWaterAfter
        self.requiredTotalWater = requiredTotalWater
        self.growthStageRawValue = growthStage.rawValue
        self.completedGrowth = completedGrowth
    }

    var species: FlowerSpecies {
        FlowerSpecies(rawValue: speciesId) ?? .cactus
    }

    var growthStage: GrowthStage {
        GrowthStage(rawValue: growthStageRawValue) ?? .seed
    }

    var progress: Double {
        guard requiredTotalWater > 0 else { return 0 }
        return min(1.0, max(0.0, totalWaterAfter / requiredTotalWater))
    }
}
