import Foundation
import SwiftData

@Model
final class ActiveFish {
    @Attribute(.unique) var id: UUID
    var speciesId: String
    var name: String
    var startedAt: Date
    var lastWateredAt: Date?
    var requiredTotalWater: Double
    var receivedWater: Double
    var isCompleted: Bool

    init(
        id: UUID = UUID(),
        speciesId: String,
        name: String,
        startedAt: Date = .now,
        lastWateredAt: Date? = nil,
        requiredTotalWater: Double,
        receivedWater: Double = 0,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.speciesId = speciesId
        self.name = name
        self.startedAt = startedAt
        self.lastWateredAt = lastWateredAt
        self.requiredTotalWater = requiredTotalWater
        self.receivedWater = receivedWater
        self.isCompleted = isCompleted
    }

    var species: FishSpecies {
        FishSpecies(rawValue: speciesId) ?? .medaka
    }

    var progress: Double {
        guard requiredTotalWater > 0 else { return 0 }
        return min(1.0, max(0.0, receivedWater / requiredTotalWater))
    }

    var growthStage: GrowthStage {
        GrowthStage.stage(for: progress)
    }
}
