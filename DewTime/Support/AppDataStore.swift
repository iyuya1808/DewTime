import Foundation
import Observation

enum AppDataStoreError: LocalizedError {
    case invalidLocalData(String)

    var errorDescription: String? {
        switch self {
        case .invalidLocalData(let name):
            return "ローカルデータが壊れています: \(name)"
        }
    }
}

@Observable
@MainActor
final class AppDataStore {
    var schedules: [UserSchedule] = []
    var activeFishes: [ActiveFish] = []
    var collectedFishes: [CollectedFish] = []
    var careRecords: [FishCareRecord] = []
    var aquariums: [Aquarium] = []
    var profiles: [UserProfile] = []
    var isLoading = false
    var isSaving = false
    var errorMessage: String?

    private let schemaVersion = 1

    var isConfigured: Bool {
        return true
    }

    var activeSchedule: UserSchedule? {
        UserSchedule.active(in: schedules)
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try loadFromLocal()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "ローカルデータの読み込みに失敗しました"
            print("[DewTime] Local load failed: \(error)")
            if schedules.isEmpty {
                seedSampleDataLocally()
            }
        }
    }

    func saveAll() async {
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            try saveToLocal()
        } catch {
            errorMessage = "ローカルデータの保存に失敗しました"
            print("[DewTime] Local save failed: \(error)")
        }
    }

    func addSchedule(name: String, targetDepartureTime: Date) async {
        let schedule = UserSchedule(
            name: name,
            targetDepartureTime: targetDepartureTime,
            isActive: schedules.isEmpty
        )
        schedules.append(schedule)
        await saveAll()
    }

    func deleteSchedules(_ deleting: [UserSchedule]) async {
        let deletingIds = Set(deleting.map(\.id))
        let shouldPickNextActive = deleting.contains(where: \.isActive)
        schedules.removeAll { deletingIds.contains($0.id) }

        if shouldPickNextActive, let next = schedules.first {
            UserSchedule.setActive(next, in: schedules)
        }
        await saveAll()
    }

    func addRoutineItem(to schedule: UserSchedule, item: RoutineItem) async {
        item.schedule = schedule
        schedule.items.append(item)
        await saveAll()
    }

    func deleteRoutineItems(from schedule: UserSchedule, at offsets: IndexSet) async {
        let items = schedule.orderedItems
        let deletingIds = Set(offsets.compactMap { items.indices.contains($0) ? items[$0].id : nil })
        schedule.items.removeAll { deletingIds.contains($0.id) }
        reorderItems(in: schedule)
        await saveAll()
    }

    func reorderItems(in schedule: UserSchedule) {
        let items = schedule.orderedItems
        for (index, item) in items.enumerated() {
            item.orderIndex = index
        }
    }

    func resetSchedules() async {
        schedules.removeAll()
        seedSampleSchedules()
        await saveAll()
    }

    func resetAquarium() async {
        activeFishes.removeAll()
        collectedFishes.removeAll()
        careRecords.removeAll()
        aquariums.removeAll()
        await saveAll()
    }

    func resetAll() async {
        schedules.removeAll()
        activeFishes.removeAll()
        collectedFishes.removeAll()
        careRecords.removeAll()
        aquariums.removeAll()
        profiles.removeAll()
        seedSampleSchedules()
        await saveAll()
    }

    func activeFish(for species: FishSpecies) -> ActiveFish? {
        activeFishes
            .filter { !$0.isCompleted && $0.species == species }
            .sorted { $0.startedAt > $1.startedAt }
            .first
    }

    func latestActiveFish() -> ActiveFish? {
        activeFishes
            .filter { !$0.isCompleted }
            .sorted { $0.startedAt > $1.startedAt }
            .first
    }

    func createActiveFish(for species: FishSpecies) -> ActiveFish {
        if let existing = activeFish(for: species) {
            return existing
        }

        activeFishes
            .filter { !$0.isCompleted }
            .forEach { $0.isCompleted = true }

        let fish = ActiveFish(
            speciesId: species.rawValue,
            name: species.displayName,
            requiredTotalWater: species.makeRequiredTotalWater()
        )
        activeFishes.append(fish)
        return fish
    }

    func aquarium() -> Aquarium {
        if let existing = aquariums.first {
            return existing
        }
        let aquarium = Aquarium()
        aquariums.append(aquarium)
        return aquarium
    }

    func profile() -> UserProfile {
        if let existing = profiles.first {
            return existing
        }
        let profile = UserProfile()
        profiles.append(profile)
        return profile
    }

    func updateProfile(nickname: String, avatarEmoji: String) async {
        let profile = profile()
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.nickname = trimmed.isEmpty ? "あなた" : trimmed
        profile.avatarEmoji = avatarEmoji
        await saveAll()
    }

    func recordDeparture(
        species: FishSpecies,
        fish: ActiveFish,
        waterAmount: Double,
        totalWaterAfter: Double,
        growthStage: GrowthStage,
        completedGrowth: Bool
    ) async {
        fish.receivedWater = totalWaterAfter
        fish.lastWateredAt = .now
        fish.isCompleted = completedGrowth

        careRecords.append(
            FishCareRecord(
                speciesId: species.rawValue,
                recordedAt: .now,
                waterAmount: waterAmount,
                totalWaterAfter: totalWaterAfter,
                requiredTotalWater: fish.requiredTotalWater,
                growthStage: growthStage,
                completedGrowth: completedGrowth
            )
        )

        let aquarium = aquarium()
        aquarium.totalWaterCollected += waterAmount
        aquarium.updatedAt = .now

        if completedGrowth {
            collectedFishes.append(
                CollectedFish(
                    name: species.displayName,
                    speciesId: species.rawValue,
                    recordedAt: .now,
                    succeeded: true,
                    waterRatio: 1.0
                )
            )
        }

        await saveAll()
    }

    // MARK: - Local Save / Load

    private func loadFromLocal() throws {
        let defaults = UserDefaults.standard

        // schedules
        if let schedulesData = defaults.array(forKey: "local_schedules") as? [[String: Any]] {
            var schedulesById: [String: UserSchedule] = [:]
            let decodedSchedules = try schedulesData.map { data in
                let id = data["id"] as? String ?? UUID().uuidString
                let schedule = try decodeSchedule(id: id, data: data)
                schedulesById[schedule.id.uuidString] = schedule
                return schedule
            }

            // routineItems
            if let routineData = defaults.array(forKey: "local_routine_items") as? [[String: Any]] {
                let decodedRoutineItems = try routineData.map { data in
                    let id = data["id"] as? String ?? UUID().uuidString
                    return try decodeRoutineItem(id: id, data: data, schedulesById: schedulesById)
                }
                for schedule in decodedSchedules {
                    schedule.items = decodedRoutineItems.filter { $0.schedule?.id == schedule.id }
                }
            }

            schedules = decodedSchedules.sorted { $0.name < $1.name }
        }

        // activeFishes
        if let activeFishesData = defaults.array(forKey: "local_active_fishes") as? [[String: Any]] {
            activeFishes = try activeFishesData.map { data in
                let id = data["id"] as? String ?? UUID().uuidString
                return try decodeActiveFish(id: id, data: data)
            }.sorted { $0.startedAt > $1.startedAt }
        }

        // collectedFishes
        if let collectedFishesData = defaults.array(forKey: "local_collected_fishes") as? [[String: Any]] {
            collectedFishes = try collectedFishesData.map { data in
                let id = data["id"] as? String ?? UUID().uuidString
                return try decodeCollectedFish(id: id, data: data)
            }.sorted { $0.recordedAt > $1.recordedAt }
        }

        // careRecords
        if let careRecordsData = defaults.array(forKey: "local_care_records") as? [[String: Any]] {
            careRecords = try careRecordsData.map { data in
                let id = data["id"] as? String ?? UUID().uuidString
                return try decodeCareRecord(id: id, data: data)
            }.sorted { $0.recordedAt > $1.recordedAt }
        }

        // aquariums
        if let aquariumsData = defaults.array(forKey: "local_aquariums") as? [[String: Any]] {
            aquariums = try aquariumsData.map { data in
                let id = data["id"] as? String ?? UUID().uuidString
                return try decodeAquarium(id: id, data: data)
            }
        }

        // profiles
        if let profilesData = defaults.array(forKey: "local_profiles") as? [[String: Any]] {
            profiles = try profilesData.map { data in
                let id = data["id"] as? String ?? UUID().uuidString
                return try decodeProfile(id: id, data: data)
            }
        }

        if schedules.isEmpty {
            seedSampleSchedules()
            try saveToLocal()
        } else {
            UserSchedule.ensureSingleActive(in: schedules)
        }
    }

    private func saveToLocal() throws {
        let defaults = UserDefaults.standard

        defaults.set(schedules.map { encode(schedule: $0) }, forKey: "local_schedules")

        let routineItems = schedules.flatMap(\.items)
        defaults.set(routineItems.map { encode(routineItem: $0) }, forKey: "local_routine_items")

        defaults.set(activeFishes.map { encode(activeFish: $0) }, forKey: "local_active_fishes")
        defaults.set(collectedFishes.map { encode(collectedFish: $0) }, forKey: "local_collected_fishes")
        defaults.set(careRecords.map { encode(careRecord: $0) }, forKey: "local_care_records")
        defaults.set(aquariums.map { encode(aquarium: $0) }, forKey: "local_aquariums")
        defaults.set(profiles.map { encode(profile: $0) }, forKey: "local_profiles")
    }

    // MARK: - Seed

    private func seedSampleDataLocally() {
        schedules.removeAll()
        activeFishes.removeAll()
        collectedFishes.removeAll()
        careRecords.removeAll()
        aquariums.removeAll()
        seedSampleSchedules()
    }

    private func seedSampleSchedules() {
        let schedule = UserSchedule(
            name: "平日通常モード",
            targetDepartureTime: DepartureTimeDefaults.fifteenMinutesFromNow(),
            isActive: true
        )

        let definitions: [(String, Int, String)] = [
            ("ハミガキ", 180, "#4FC3F7"),
            ("洗顔", 120, "#81D4FA"),
            ("着替え", 300, "#FFB74D"),
            ("朝食", 600, "#FFCC80"),
            ("持ち物確認", 120, "#A5D6A7")
        ]

        schedule.items = definitions.enumerated().map { index, def in
            RoutineItem(
                name: def.0,
                durationSeconds: def.1,
                colorHex: def.2,
                orderIndex: index,
                schedule: schedule
            )
        }
        schedules = [schedule]
    }

    // MARK: - Encoders

    private func encode(schedule: UserSchedule) -> [String: Any] {
        [
            "id": schedule.id.uuidString,
            "name": schedule.name,
            "targetDepartureTime": schedule.targetDepartureTime,
            "isActive": schedule.isActive
        ]
    }

    private func encode(routineItem: RoutineItem) -> [String: Any] {
        [
            "id": routineItem.id.uuidString,
            "name": routineItem.name,
            "durationSeconds": routineItem.durationSeconds,
            "colorHex": routineItem.colorHex,
            "orderIndex": routineItem.orderIndex,
            "scheduleId": routineItem.schedule?.id.uuidString ?? ""
        ]
    }

    private func encode(activeFish: ActiveFish) -> [String: Any] {
        var data: [String: Any] = [
            "id": activeFish.id.uuidString,
            "speciesId": activeFish.speciesId,
            "name": activeFish.name,
            "startedAt": activeFish.startedAt,
            "requiredTotalWater": activeFish.requiredTotalWater,
            "receivedWater": activeFish.receivedWater,
            "isCompleted": activeFish.isCompleted
        ]
        if let lastWateredAt = activeFish.lastWateredAt {
            data["lastWateredAt"] = lastWateredAt
        }
        return data
    }

    private func encode(collectedFish: CollectedFish) -> [String: Any] {
        [
            "id": collectedFish.id.uuidString,
            "name": collectedFish.name,
            "speciesId": collectedFish.speciesId,
            "recordedAt": collectedFish.recordedAt,
            "succeeded": collectedFish.succeeded,
            "waterRatio": collectedFish.waterRatio
        ]
    }

    private func encode(careRecord: FishCareRecord) -> [String: Any] {
        [
            "id": careRecord.id.uuidString,
            "speciesId": careRecord.speciesId,
            "recordedAt": careRecord.recordedAt,
            "waterAmount": careRecord.waterAmount,
            "totalWaterAfter": careRecord.totalWaterAfter,
            "requiredTotalWater": careRecord.requiredTotalWater,
            "growthStageRawValue": careRecord.growthStageRawValue,
            "completedGrowth": careRecord.completedGrowth
        ]
    }

    private func encode(aquarium: Aquarium) -> [String: Any] {
        [
            "id": aquarium.id.uuidString,
            "totalWaterCollected": aquarium.totalWaterCollected,
            "createdAt": aquarium.createdAt,
            "updatedAt": aquarium.updatedAt
        ]
    }

    private func encode(profile: UserProfile) -> [String: Any] {
        [
            "id": profile.id.uuidString,
            "nickname": profile.nickname,
            "avatarEmoji": profile.avatarEmoji,
            "createdAt": profile.createdAt
        ]
    }

    // MARK: - Decoders

    private func decodeSchedule(id: String, data: [String: Any]) throws -> UserSchedule {
        UserSchedule(
            id: try uuid(id, label: "schedule.id"),
            name: string(data["name"], default: "スケジュール"),
            targetDepartureTime: try date(data["targetDepartureTime"], label: "schedule.targetDepartureTime"),
            isActive: bool(data["isActive"], default: false)
        )
    }

    private func decodeRoutineItem(
        id: String,
        data: [String: Any],
        schedulesById: [String: UserSchedule]
    ) throws -> RoutineItem {
        let scheduleId = string(data["scheduleId"], default: "")
        return RoutineItem(
            id: try uuid(id, label: "routineItem.id"),
            name: string(data["name"], default: "ルーティン"),
            durationSeconds: int(data["durationSeconds"], default: 0),
            colorHex: string(data["colorHex"], default: "#4FC3F7"),
            orderIndex: int(data["orderIndex"], default: 0),
            schedule: schedulesById[scheduleId]
        )
    }

    private func decodeActiveFish(id: String, data: [String: Any]) throws -> ActiveFish {
        ActiveFish(
            id: try uuid(id, label: "activeFish.id"),
            speciesId: string(data["speciesId"], default: FishSpecies.medaka.rawValue),
            name: string(data["name"], default: FishSpecies.medaka.displayName),
            startedAt: try date(data["startedAt"], label: "activeFish.startedAt"),
            lastWateredAt: optionalDate(data["lastWateredAt"]),
            requiredTotalWater: double(data["requiredTotalWater"], default: 1),
            receivedWater: double(data["receivedWater"], default: 0),
            isCompleted: bool(data["isCompleted"], default: false)
        )
    }

    private func decodeCollectedFish(id: String, data: [String: Any]) throws -> CollectedFish {
        CollectedFish(
            id: try uuid(id, label: "collectedFish.id"),
            name: string(data["name"], default: FishSpecies.medaka.displayName),
            speciesId: string(data["speciesId"], default: FishSpecies.medaka.rawValue),
            recordedAt: try date(data["recordedAt"], label: "collectedFish.recordedAt"),
            succeeded: bool(data["succeeded"], default: false),
            waterRatio: double(data["waterRatio"], default: 0)
        )
    }

    private func decodeCareRecord(id: String, data: [String: Any]) throws -> FishCareRecord {
        FishCareRecord(
            id: try uuid(id, label: "careRecord.id"),
            speciesId: string(data["speciesId"], default: FishSpecies.medaka.rawValue),
            recordedAt: try date(data["recordedAt"], label: "careRecord.recordedAt"),
            waterAmount: double(data["waterAmount"], default: 0),
            totalWaterAfter: double(data["totalWaterAfter"], default: 0),
            requiredTotalWater: double(data["requiredTotalWater"], default: 1),
            growthStage: GrowthStage(rawValue: string(data["growthStageRawValue"], default: GrowthStage.egg.rawValue)) ?? .egg,
            completedGrowth: bool(data["completedGrowth"], default: false)
        )
    }

    private func decodeAquarium(id: String, data: [String: Any]) throws -> Aquarium {
        Aquarium(
            id: try uuid(id, label: "aquarium.id"),
            totalWaterCollected: double(data["totalWaterCollected"], default: 0),
            createdAt: try date(data["createdAt"], label: "aquarium.createdAt"),
            updatedAt: try date(data["updatedAt"], label: "aquarium.updatedAt")
        )
    }

    private func decodeProfile(id: String, data: [String: Any]) throws -> UserProfile {
        UserProfile(
            id: try uuid(id, label: "profile.id"),
            nickname: string(data["nickname"], default: "あなた"),
            avatarEmoji: string(data["avatarEmoji"], default: "🐟"),
            createdAt: try date(data["createdAt"], label: "profile.createdAt")
        )
    }

    // MARK: - Value helpers

    private func uuid(_ value: String, label: String) throws -> UUID {
        guard let uuid = UUID(uuidString: value) else {
            throw AppDataStoreError.invalidLocalData(label)
        }
        return uuid
    }

    private func string(_ value: Any?, default defaultValue: String) -> String {
        value as? String ?? defaultValue
    }

    private func bool(_ value: Any?, default defaultValue: Bool) -> Bool {
        value as? Bool ?? defaultValue
    }

    private func int(_ value: Any?, default defaultValue: Int) -> Int {
        if let int = value as? Int { return int }
        if let number = value as? NSNumber { return number.intValue }
        return defaultValue
    }

    private func double(_ value: Any?, default defaultValue: Double) -> Double {
        if let double = value as? Double { return double }
        if let number = value as? NSNumber { return number.doubleValue }
        return defaultValue
    }

    private func date(_ value: Any?, label: String) throws -> Date {
        if let date = optionalDate(value) { return date }
        throw AppDataStoreError.invalidLocalData(label)
    }

    private func optionalDate(_ value: Any?) -> Date? {
        if value is NSNull { return nil }
        if let date = value as? Date { return date }
        if let seconds = value as? TimeInterval { return Date(timeIntervalSince1970: seconds) }
        if let number = value as? NSNumber { return Date(timeIntervalSince1970: number.doubleValue) }
        return nil
    }
}
