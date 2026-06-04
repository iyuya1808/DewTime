import Foundation
import Supabase

enum CloudDataError: LocalizedError {
    case unauthenticated

    var errorDescription: String? {
        switch self {
        case .unauthenticated:
            return "ログイン状態を確認できませんでした"
        }
    }
}

@MainActor
protocol CloudDataServicing {
    func loadAll(userId: UUID) async throws -> CloudSnapshot
    func saveAll(snapshot: CloudSnapshot, userId: UUID) async throws
    func deleteAquariumData(userId: UUID) async throws
    func deleteAll(userId: UUID) async throws
    func loadPurchases(userId: UUID) async throws -> [CloudPurchase]
    func savePurchase(_ purchase: CloudPurchase) async throws
}

struct CloudSnapshot: Equatable {
    var schedules: [CloudSchedule]
    var routineItems: [CloudRoutineItem]
    var activeFishes: [CloudActiveFish]
    var collectedFishes: [CloudCollectedFish]
    var careRecords: [CloudCareRecord]
    var aquariums: [CloudAquarium]
    var profiles: [CloudProfile]

    init(
        schedules: [CloudSchedule] = [],
        routineItems: [CloudRoutineItem] = [],
        activeFishes: [CloudActiveFish] = [],
        collectedFishes: [CloudCollectedFish] = [],
        careRecords: [CloudCareRecord] = [],
        aquariums: [CloudAquarium] = [],
        profiles: [CloudProfile] = []
    ) {
        self.schedules = schedules
        self.routineItems = routineItems
        self.activeFishes = activeFishes
        self.collectedFishes = collectedFishes
        self.careRecords = careRecords
        self.aquariums = aquariums
        self.profiles = profiles
    }

    var isEmpty: Bool {
        schedules.isEmpty
            && routineItems.isEmpty
            && activeFishes.isEmpty
            && collectedFishes.isEmpty
            && careRecords.isEmpty
            && aquariums.isEmpty
            && profiles.isEmpty
    }
}

struct CloudSchedule: Codable, Equatable, Identifiable {
    var id: UUID
    var userId: UUID
    var name: String
    var targetDepartureTime: Date
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case targetDepartureTime = "target_departure_time"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct CloudRoutineItem: Codable, Equatable, Identifiable {
    var id: UUID
    var userId: UUID
    var scheduleId: UUID
    var name: String
    var durationSeconds: Int
    var colorHex: String
    var orderIndex: Int
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case scheduleId = "schedule_id"
        case name
        case durationSeconds = "duration_seconds"
        case colorHex = "color_hex"
        case orderIndex = "order_index"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct CloudActiveFish: Codable, Equatable, Identifiable {
    var id: UUID
    var userId: UUID
    var speciesId: String
    var name: String
    var startedAt: Date
    var lastWateredAt: Date?
    var requiredTotalWater: Double
    var receivedWater: Double
    var isCompleted: Bool
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case speciesId = "species_id"
        case name
        case startedAt = "started_at"
        case lastWateredAt = "last_watered_at"
        case requiredTotalWater = "required_total_water"
        case receivedWater = "received_water"
        case isCompleted = "is_completed"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct CloudCollectedFish: Codable, Equatable, Identifiable {
    var id: UUID
    var userId: UUID
    var name: String
    var speciesId: String
    var recordedAt: Date
    var succeeded: Bool
    var waterRatio: Double
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case speciesId = "species_id"
        case recordedAt = "recorded_at"
        case succeeded
        case waterRatio = "water_ratio"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct CloudCareRecord: Codable, Equatable, Identifiable {
    var id: UUID
    var userId: UUID
    var speciesId: String
    var recordedAt: Date
    var waterAmount: Double
    var totalWaterAfter: Double
    var requiredTotalWater: Double
    var growthStageRawValue: String
    var completedGrowth: Bool
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case speciesId = "species_id"
        case recordedAt = "recorded_at"
        case waterAmount = "water_amount"
        case totalWaterAfter = "total_water_after"
        case requiredTotalWater = "required_total_water"
        case growthStageRawValue = "growth_stage_raw_value"
        case completedGrowth = "completed_growth"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct CloudAquarium: Codable, Equatable, Identifiable {
    var id: UUID
    var userId: UUID
    var totalWaterCollected: Double
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case totalWaterCollected = "total_water_collected"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct CloudProfile: Codable, Equatable, Identifiable {
    var id: UUID
    var userId: UUID
    var nickname: String
    var avatarEmoji: String
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case nickname
        case avatarEmoji = "avatar_emoji"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct CloudPurchase: Codable, Equatable, Identifiable {
    var id: UUID
    var userId: UUID
    var productId: String
    var originalTransactionId: String
    var purchasedAt: Date
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case productId = "product_id"
        case originalTransactionId = "original_transaction_id"
        case purchasedAt = "purchased_at"
        case createdAt = "created_at"
    }
}

@MainActor
final class SupabaseDataService: CloudDataServicing {
    static let shared = SupabaseDataService()

    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    func loadAll(userId: UUID) async throws -> CloudSnapshot {
        let schedules: [CloudSchedule] = try await select("user_schedules", userId: userId)
        let routineItems: [CloudRoutineItem] = try await select("routine_items", userId: userId)
        let activeFishes: [CloudActiveFish] = try await select("active_fishes", userId: userId)
        let collectedFishes: [CloudCollectedFish] = try await select("collected_fishes", userId: userId)
        let careRecords: [CloudCareRecord] = try await select("fish_care_records", userId: userId)
        let aquariums: [CloudAquarium] = try await select("aquariums", userId: userId)
        let profiles: [CloudProfile] = try await select("user_profiles", userId: userId)

        return CloudSnapshot(
            schedules: schedules.sorted { $0.name < $1.name },
            routineItems: routineItems.sorted { $0.orderIndex < $1.orderIndex },
            activeFishes: activeFishes.sorted { $0.startedAt > $1.startedAt },
            collectedFishes: collectedFishes.sorted { $0.recordedAt > $1.recordedAt },
            careRecords: careRecords.sorted { $0.recordedAt > $1.recordedAt },
            aquariums: aquariums,
            profiles: profiles
        )
    }

    func saveAll(snapshot: CloudSnapshot, userId: UUID) async throws {
        try await deleteAll(userId: userId)
        try await upsert("user_schedules", values: snapshot.schedules)
        try await upsert("routine_items", values: snapshot.routineItems)
        try await upsert("active_fishes", values: snapshot.activeFishes)
        try await upsert("collected_fishes", values: snapshot.collectedFishes)
        try await upsert("fish_care_records", values: snapshot.careRecords)
        try await upsert("aquariums", values: snapshot.aquariums)
        try await upsert("user_profiles", values: snapshot.profiles)
    }

    func deleteAquariumData(userId: UUID) async throws {
        try await delete("fish_care_records", userId: userId)
        try await delete("collected_fishes", userId: userId)
        try await delete("active_fishes", userId: userId)
        try await delete("aquariums", userId: userId)
    }

    func deleteAll(userId: UUID) async throws {
        try await delete("routine_items", userId: userId)
        try await delete("fish_care_records", userId: userId)
        try await delete("collected_fishes", userId: userId)
        try await delete("active_fishes", userId: userId)
        try await delete("aquariums", userId: userId)
        try await delete("user_profiles", userId: userId)
        try await delete("user_schedules", userId: userId)
    }

    func loadPurchases(userId: UUID) async throws -> [CloudPurchase] {
        try await select("user_purchases", userId: userId)
    }

    func savePurchase(_ purchase: CloudPurchase) async throws {
        try await upsert("user_purchases", values: [purchase])
    }

    private func select<T: Decodable>(_ table: String, userId: UUID) async throws -> [T] {
        try await client
            .from(table)
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
    }

    private func upsert<T: Encodable>(_ table: String, values: [T]) async throws {
        guard !values.isEmpty else { return }
        try await client
            .from(table)
            .upsert(values, onConflict: "id")
            .execute()
    }

    private func delete(_ table: String, userId: UUID) async throws {
        try await client
            .from(table)
            .delete()
            .eq("user_id", value: userId)
            .execute()
    }
}
