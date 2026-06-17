import Foundation
import Observation

@Observable
final class ActiveFish: Identifiable {
    var id: UUID
    var speciesId: String
    var name: String
    var startedAt: Date
    var lastWateredAt: Date?
    var departures: Int
    var isCompleted: Bool

    init(
        id: UUID = UUID(),
        speciesId: String,
        name: String,
        startedAt: Date = .now,
        lastWateredAt: Date? = nil,
        departures: Int = 0,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.speciesId = speciesId
        self.name = name
        self.startedAt = startedAt
        self.lastWateredAt = lastWateredAt
        self.departures = departures
        self.isCompleted = isCompleted
    }

    var species: FishSpecies {
        FishSpecies(rawValue: speciesId) ?? .medaka
    }

    var progress: Double {
        let required = species.requiredDepartures
        guard required > 0 else { return 0 }
        return min(1.0, max(0.0, Double(departures) / Double(required)))
    }

    var growthStage: GrowthStage {
        GrowthStage.stage(for: progress)
    }
}
