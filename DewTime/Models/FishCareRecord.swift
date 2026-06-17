import Foundation
import Observation

@Observable
final class FishCareRecord: Identifiable {
    var id: UUID
    var speciesId: String
    var recordedAt: Date
    var departuresAfter: Int
    var earnedDrop: Bool
    var growthStageRawValue: String
    var completedGrowth: Bool

    init(
        id: UUID = UUID(),
        speciesId: String,
        recordedAt: Date = .now,
        departuresAfter: Int,
        earnedDrop: Bool,
        growthStage: GrowthStage,
        completedGrowth: Bool
    ) {
        self.id = id
        self.speciesId = speciesId
        self.recordedAt = recordedAt
        self.departuresAfter = departuresAfter
        self.earnedDrop = earnedDrop
        self.growthStageRawValue = growthStage.rawValue
        self.completedGrowth = completedGrowth
    }

    var species: FishSpecies {
        FishSpecies(rawValue: speciesId) ?? .medaka
    }

    var growthStage: GrowthStage {
        GrowthStage(rawValue: growthStageRawValue) ?? .egg
    }

    var progress: Double {
        let required = species.requiredDepartures
        guard required > 0 else { return 0 }
        return min(1.0, max(0.0, Double(departuresAfter) / Double(required)))
    }
}
