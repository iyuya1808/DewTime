import Foundation
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Observation

enum AppDataStoreError: LocalizedError {
    case firebaseNotConfigured
    case authenticationFailed
    case noUser
    case invalidCloudData(String)

    var errorDescription: String? {
        switch self {
        case .firebaseNotConfigured:
            return "Firebaseが未設定です。GoogleService-Info.plistをDewTimeターゲットに追加してください。"
        case .authenticationFailed:
            return "Firebaseの匿名ログインに失敗しました。"
        case .noUser:
            return "Firebaseユーザーを取得できませんでした。"
        case .invalidCloudData(let name):
            return "Firestoreデータが壊れています: \(name)"
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
        FirebaseApp.app() != nil
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
            try await loadFromFirestore()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Firestoreからの読み込みに失敗しました"
            print("[DewTime] Firestore load failed: \(error)")
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
            try await saveToFirestore()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Firestoreへの保存に失敗しました"
            print("[DewTime] Firestore save failed: \(error)")
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

    // MARK: - Firestore

    private func loadFromFirestore() async throws {
        let userRef = try await userDocument()
        let schedulesSnapshot = try await documents(in: userRef.collection("schedules"))
        let routineItemsSnapshot = try await documents(in: userRef.collection("routineItems"))
        let activeFishesSnapshot = try await documents(in: userRef.collection("activeFishes"))
        let collectedFishesSnapshot = try await documents(in: userRef.collection("collectedFishes"))
        let careRecordsSnapshot = try await documents(in: userRef.collection("careRecords"))
        let aquariumsSnapshot = try await documents(in: userRef.collection("aquariums"))
        let profilesSnapshot = try await documents(in: userRef.collection("profiles"))

        var schedulesById: [String: UserSchedule] = [:]
        let decodedSchedules = try schedulesSnapshot.map { document in
            let schedule = try decodeSchedule(id: document.documentID, data: document.data())
            schedulesById[schedule.id.uuidString] = schedule
            return schedule
        }

        let decodedRoutineItems = try routineItemsSnapshot.map { document in
            try decodeRoutineItem(id: document.documentID, data: document.data(), schedulesById: schedulesById)
        }

        for schedule in decodedSchedules {
            schedule.items = decodedRoutineItems.filter { $0.schedule?.id == schedule.id }
        }

        schedules = decodedSchedules.sorted { $0.name < $1.name }
        activeFishes = try activeFishesSnapshot.map { try decodeActiveFish(id: $0.documentID, data: $0.data()) }
            .sorted { $0.startedAt > $1.startedAt }
        collectedFishes = try collectedFishesSnapshot.map { try decodeCollectedFish(id: $0.documentID, data: $0.data()) }
            .sorted { $0.recordedAt > $1.recordedAt }
        careRecords = try careRecordsSnapshot.map { try decodeCareRecord(id: $0.documentID, data: $0.data()) }
            .sorted { $0.recordedAt > $1.recordedAt }
        aquariums = try aquariumsSnapshot.map { try decodeAquarium(id: $0.documentID, data: $0.data()) }
        profiles = try profilesSnapshot.map { try decodeProfile(id: $0.documentID, data: $0.data()) }

        if schedules.isEmpty {
            seedSampleSchedules()
            try await saveToFirestore()
        } else {
            UserSchedule.ensureSingleActive(in: schedules)
        }
    }

    private func saveToFirestore() async throws {
        let userRef = try await userDocument()

        try await replaceCollection(
            userRef.collection("schedules"),
            with: schedules.map { ($0.id.uuidString, encode(schedule: $0)) }
        )

        let routineItems = schedules.flatMap(\.items)
        try await replaceCollection(
            userRef.collection("routineItems"),
            with: routineItems.map { ($0.id.uuidString, encode(routineItem: $0)) }
        )
        try await replaceCollection(
            userRef.collection("activeFishes"),
            with: activeFishes.map { ($0.id.uuidString, encode(activeFish: $0)) }
        )
        try await replaceCollection(
            userRef.collection("collectedFishes"),
            with: collectedFishes.map { ($0.id.uuidString, encode(collectedFish: $0)) }
        )
        try await replaceCollection(
            userRef.collection("careRecords"),
            with: careRecords.map { ($0.id.uuidString, encode(careRecord: $0)) }
        )
        try await replaceCollection(
            userRef.collection("aquariums"),
            with: aquariums.map { ($0.id.uuidString, encode(aquarium: $0)) }
        )
        try await replaceCollection(
            userRef.collection("profiles"),
            with: profiles.map { ($0.id.uuidString, encode(profile: $0)) }
        )

        try await setData([
            "schemaVersion": schemaVersion,
            "updatedAt": Date(),
            "bundleId": Bundle.main.bundleIdentifier ?? "unknown"
        ], at: userRef, merge: true)
    }

    private func userDocument() async throws -> DocumentReference {
        guard isConfigured else { throw AppDataStoreError.firebaseNotConfigured }
        let user = try await authenticatedUser()
        return Firestore.firestore().collection("users").document(user.uid)
    }

    private func authenticatedUser() async throws -> User {
        if let current = Auth.auth().currentUser {
            return current
        }

        return try await withCheckedThrowingContinuation { continuation in
            Auth.auth().signInAnonymously { result, error in
                if let user = result?.user {
                    continuation.resume(returning: user)
                } else {
                    continuation.resume(throwing: error ?? AppDataStoreError.authenticationFailed)
                }
            }
        }
    }

    private func replaceCollection(_ collection: CollectionReference, with entries: [(String, [String: Any])]) async throws {
        let existing = try await documents(in: collection)
        let batch = Firestore.firestore().batch()

        for document in existing {
            batch.deleteDocument(document.reference)
        }
        for (id, data) in entries {
            batch.setData(data, forDocument: collection.document(id))
        }

        try await commit(batch)
    }

    private func documents(in collection: CollectionReference) async throws -> [QueryDocumentSnapshot] {
        try await withCheckedThrowingContinuation { continuation in
            collection.getDocuments { snapshot, error in
                if let snapshot {
                    continuation.resume(returning: snapshot.documents)
                } else {
                    continuation.resume(throwing: error ?? AppDataStoreError.invalidCloudData(collection.path))
                }
            }
        }
    }

    private func setData(_ data: [String: Any], at document: DocumentReference, merge: Bool) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            document.setData(data, merge: merge) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func commit(_ batch: WriteBatch) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            batch.commit { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
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
            "name": schedule.name,
            "targetDepartureTime": schedule.targetDepartureTime,
            "isActive": schedule.isActive
        ]
    }

    private func encode(routineItem: RoutineItem) -> [String: Any] {
        [
            "name": routineItem.name,
            "durationSeconds": routineItem.durationSeconds,
            "colorHex": routineItem.colorHex,
            "orderIndex": routineItem.orderIndex,
            "scheduleId": routineItem.schedule?.id.uuidString ?? ""
        ]
    }

    private func encode(activeFish: ActiveFish) -> [String: Any] {
        [
            "speciesId": activeFish.speciesId,
            "name": activeFish.name,
            "startedAt": activeFish.startedAt,
            "lastWateredAt": activeFish.lastWateredAt ?? NSNull(),
            "requiredTotalWater": activeFish.requiredTotalWater,
            "receivedWater": activeFish.receivedWater,
            "isCompleted": activeFish.isCompleted
        ]
    }

    private func encode(collectedFish: CollectedFish) -> [String: Any] {
        [
            "name": collectedFish.name,
            "speciesId": collectedFish.speciesId,
            "recordedAt": collectedFish.recordedAt,
            "succeeded": collectedFish.succeeded,
            "waterRatio": collectedFish.waterRatio
        ]
    }

    private func encode(careRecord: FishCareRecord) -> [String: Any] {
        [
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
            "totalWaterCollected": aquarium.totalWaterCollected,
            "createdAt": aquarium.createdAt,
            "updatedAt": aquarium.updatedAt
        ]
    }

    private func encode(profile: UserProfile) -> [String: Any] {
        [
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
            throw AppDataStoreError.invalidCloudData(label)
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
        throw AppDataStoreError.invalidCloudData(label)
    }

    private func optionalDate(_ value: Any?) -> Date? {
        if value is NSNull { return nil }
        if let date = value as? Date { return date }
        if let timestamp = value as? Timestamp { return timestamp.dateValue() }
        if let seconds = value as? TimeInterval { return Date(timeIntervalSince1970: seconds) }
        if let number = value as? NSNumber { return Date(timeIntervalSince1970: number.doubleValue) }
        return nil
    }
}
