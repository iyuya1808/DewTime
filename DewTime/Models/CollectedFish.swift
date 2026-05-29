import Foundation
import SwiftData

@Model
final class CollectedFish {
    @Attribute(.unique) var id: UUID
    var name: String
    var speciesId: String
    var recordedAt: Date
    var succeeded: Bool
    var waterRatio: Double

    init(
        id: UUID = UUID(),
        name: String,
        speciesId: String,
        recordedAt: Date = .now,
        succeeded: Bool,
        waterRatio: Double
    ) {
        self.id = id
        self.name = name
        self.speciesId = speciesId
        self.recordedAt = recordedAt
        self.succeeded = succeeded
        self.waterRatio = waterRatio
    }
}
