//
//  DewTimeTests.swift
//  DewTimeTests
//
//  Created by 糸長優矢 on 2026/05/22.
//

import Testing
import Foundation
@testable import DewTime

@MainActor
@Suite(.serialized)
struct DewTimeTests {

    @Test func setActiveKeepsOnlySelectedScheduleActive() async throws {
        let weekday = UserSchedule(name: "平日", targetDepartureTime: .now, isActive: true)
        let weekend = UserSchedule(name: "休日", targetDepartureTime: .now, isActive: false)

        UserSchedule.setActive(weekend, in: [weekday, weekend])

        #expect(weekday.isActive == false)
        #expect(weekend.isActive == true)
    }

    @Test func ensureSingleActiveChoosesOneScheduleWhenMultipleAreActive() async throws {
        let weekday = UserSchedule(name: "平日", targetDepartureTime: .now, isActive: true)
        let weekend = UserSchedule(name: "休日", targetDepartureTime: .now, isActive: true)

        UserSchedule.ensureSingleActive(in: [weekday, weekend])

        #expect([weekday, weekend].filter(\.isActive).count == 1)
    }

    @MainActor
    @Test func fishSpeciesTotalWaterRangesMatchPlan() async throws {
        #expect(FishSpecies.medaka.requiredTotalWaterRange == 50...90)
        #expect(FishSpecies.guppy.requiredTotalWaterRange == 80...130)
        #expect(FishSpecies.dolphin.requiredTotalWaterRange == 270...390)
        #expect(FishSpecies.shark.requiredTotalWaterRange == 290...430)
        #expect(FishSpecies.whaleShark.requiredTotalWaterRange == 350...500)

        for species in FishSpecies.allCases {
            for _ in 0..<20 {
                let requiredWater = Int(species.makeRequiredTotalWater())
                #expect(species.requiredTotalWaterRange.contains(requiredWater))
            }
        }
    }

    @MainActor
    @Test func growthStageUsesExpectedThresholds() async throws {
        #expect(GrowthStage.stage(for: 0.0) == .egg)
        #expect(GrowthStage.stage(for: 0.24) == .egg)
        #expect(GrowthStage.stage(for: 0.25) == .fry)
        #expect(GrowthStage.stage(for: 0.54) == .fry)
        #expect(GrowthStage.stage(for: 0.55) == .juvenile)
        #expect(GrowthStage.stage(for: 0.99) == .juvenile)
        #expect(GrowthStage.stage(for: 1.0) == .adult)
    }

    @Test func defaultDepartureTimeStartsFifteenMinutesFromNextMinute() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 5,
            day: 31,
            hour: 10,
            minute: 7,
            second: 34
        )))

        let result = DepartureTimeDefaults.fifteenMinutesFromNow(now: now, calendar: calendar)
        let expected = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 5,
            day: 31,
            hour: 10,
            minute: 23,
            second: 0
        )))

        #expect(result == expected)
    }

    @MainActor
    @Test func timerViewModelCreatesAndPersistsSelectedSpecies() async throws {
        resetLocalTestState()
        defer { resetLocalTestState() }

        let store = AppDataStore()
        let schedule = UserSchedule(name: "平日", targetDepartureTime: .now.addingTimeInterval(600), isActive: true)

        let vm = TimerViewModel(schedule: schedule)
        await vm.selectSpecies(.dolphin, store: store)

        #expect(store.activeFishes.count == 1)
        #expect(store.activeFishes.first?.speciesId == FishSpecies.dolphin.rawValue)
        #expect(store.activeFishes.first?.receivedWater == 0)
        #expect(FishSpecies.dolphin.requiredTotalWaterRange.contains(Int(store.activeFishes.first?.requiredTotalWater ?? 0)))

        let restored = TimerViewModel(schedule: schedule)
        #expect(restored.selectedSpecies == .dolphin)
    }

    @MainActor
    @Test func departAddsWateringRecordWithoutCompletingWhenShort() async throws {
        resetLocalTestState()
        defer { resetLocalTestState() }

        let store = AppDataStore()
        let schedule = UserSchedule(name: "平日", targetDepartureTime: .now.addingTimeInterval(600), isActive: true)
        let vm = TimerViewModel(schedule: schedule)
        await vm.selectSpecies(.shark, store: store)

        let fish = try #require(store.activeFishes.first)
        fish.requiredTotalWater = 300
        fish.receivedWater = 0

        await vm.depart(store: store)

        #expect(store.careRecords.count == 1)
        #expect(store.careRecords.first?.speciesId == FishSpecies.shark.rawValue)
        #expect(store.careRecords.first?.waterAmount == 100)
        #expect(store.careRecords.first?.totalWaterAfter == 100)
        #expect(store.careRecords.first?.completedGrowth == false)
        #expect(store.collectedFishes.isEmpty)
        #expect(store.activeFishes.first?.receivedWater == 100)
        #expect(store.activeFishes.first?.isCompleted == false)
        #expect(vm.activeFish != nil)

        vm.reset()
    }

    @MainActor
    @Test func departCompletesFishAndCreatesCollectionRecordWhenEnoughWater() async throws {
        resetLocalTestState()
        defer { resetLocalTestState() }

        let store = AppDataStore()
        let schedule = UserSchedule(name: "平日", targetDepartureTime: .now.addingTimeInterval(600), isActive: true)
        let vm = TimerViewModel(schedule: schedule)
        await vm.selectSpecies(.medaka, store: store)

        let fish = try #require(store.activeFishes.first)
        fish.requiredTotalWater = 80
        fish.receivedWater = 20

        await vm.depart(store: store)

        #expect(store.careRecords.count == 1)
        #expect(store.careRecords.first?.waterAmount == 100)
        #expect(store.careRecords.first?.totalWaterAfter == 80)
        #expect(store.careRecords.first?.growthStage == .adult)
        #expect(store.careRecords.first?.completedGrowth == true)
        #expect(store.collectedFishes.count == 1)
        #expect(store.collectedFishes.first?.speciesId == FishSpecies.medaka.rawValue)
        #expect(store.collectedFishes.first?.succeeded == true)
        #expect(store.activeFishes.first?.receivedWater == 80)
        #expect(store.activeFishes.first?.isCompleted == true)
        #expect(vm.activeFish == nil)

        vm.reset()
    }

    @MainActor
    @Test func completedFishKeepsCustomNameInCollectionRecord() async throws {
        resetLocalTestState()
        defer { resetLocalTestState() }

        let store = AppDataStore()
        let schedule = UserSchedule(name: "平日", targetDepartureTime: .now.addingTimeInterval(600), isActive: true)
        let vm = TimerViewModel(schedule: schedule)
        await vm.selectSpecies(.medaka, store: store)

        let fish = try #require(store.activeFishes.first)
        fish.requiredTotalWater = 80
        fish.receivedWater = 20
        await store.renameActiveFish(fish, name: "しずく")

        await vm.depart(store: store)

        #expect(store.collectedFishes.first?.name == "しずく")

        vm.reset()
    }

    @MainActor
    @Test func aquariumTierUnlocksLargerSpecies() async throws {
        #expect(FishSpecies.medaka.isUnlocked(aquariumTier: 0))
        #expect(FishSpecies.dolphin.isUnlocked(aquariumTier: 4))
        #expect(!FishSpecies.dolphin.isUnlocked(aquariumTier: 3))
        #expect(FishSpecies.whaleShark.requiredAquariumName == "大水族館")
    }

    @MainActor
    @Test func liveActivityAttributesContainRoutineSegments() async throws {
        resetLocalTestState()
        defer { resetLocalTestState() }

        let schedule = makeScheduleForLiveActivityTests()
        let vm = TimerViewModel(schedule: schedule)

        vm.start()

        let attributes = try #require(vm.liveActivityAttributes())
        #expect(attributes.scheduleName == "平日")
        #expect(attributes.segments.count == 2)
        #expect(attributes.segments[0].name == "ハミガキ")
        #expect(attributes.segments[0].startOffset == 0)
        #expect(attributes.segments[0].endOffset == 180)
        #expect(attributes.segments[1].startOffset == 180)

        vm.reset()
    }

    @MainActor
    @Test func liveActivityContentStateMirrorsTimerAndFishState() async throws {
        resetLocalTestState()
        defer { resetLocalTestState() }

        let store = AppDataStore()
        let schedule = makeScheduleForLiveActivityTests()
        let vm = TimerViewModel(schedule: schedule)

        await vm.selectSpecies(.guppy, store: store)
        let fish = try #require(store.activeFishes.first)
        fish.requiredTotalWater = 120
        fish.receivedWater = 30

        vm.start()

        let state = vm.liveActivityContentState()
        #expect(state.status == .running)
        #expect(state.currentTaskName == "ハミガキ")
        #expect(state.nextTaskName == "着替え")
        #expect(state.selectedSpeciesName == FishSpecies.guppy.displayName)
        #expect(state.fishEmoji == FishSpecies.guppy.emoji)
        #expect(state.receivedWater == 30)
        #expect(state.requiredWater == 120)
        #expect(state.projectedWater == 120)
        #expect(state.growthStageName == GrowthStage.adult.displayName)

        vm.reset()
    }

    @MainActor
    @Test func liveActivityFinishedStatesUseTerminalLabels() async throws {
        resetLocalTestState()
        defer { resetLocalTestState() }

        let schedule = makeScheduleForLiveActivityTests()
        let vm = TimerViewModel(schedule: schedule)
        vm.start()

        let departed = vm.liveActivityContentState(status: .departed)
        let cancelled = vm.liveActivityContentState(status: .cancelled)

        #expect(departed.currentTaskName == "出発完了")
        #expect(departed.nextTaskName == nil)
        #expect(cancelled.currentTaskName == "キャンセル")
        #expect(cancelled.nextTaskName == nil)

        vm.reset()
    }

    @MainActor
    @Test func cloudSnapshotRoundTripsStoreModelsAndRoutineParent() async throws {
        let userId = UUID()
        let store = AppDataStore(enableCloudSync: false)
        let schedule = UserSchedule(name: "朝", targetDepartureTime: .now, isActive: true)
        let routine = RoutineItem(name: "準備", durationSeconds: 120, colorHex: "#38BDF8", orderIndex: 0, schedule: schedule)
        schedule.items = [routine]
        store.schedules = [schedule]
        store.activeFishes = [
            ActiveFish(speciesId: FishSpecies.guppy.rawValue, name: FishSpecies.guppy.displayName, requiredTotalWater: 100)
        ]
        store.collectedFishes = [
            CollectedFish(name: FishSpecies.medaka.displayName, speciesId: FishSpecies.medaka.rawValue, succeeded: true, waterRatio: 1)
        ]
        store.careRecords = [
            FishCareRecord(
                speciesId: FishSpecies.medaka.rawValue,
                waterAmount: 80,
                totalWaterAfter: 80,
                requiredTotalWater: 80,
                growthStage: .adult,
                completedGrowth: true
            )
        ]
        store.aquariums = [Aquarium(totalWaterCollected: 500)]
        store.profiles = [UserProfile(nickname: "Yuya", avatarEmoji: "🐬")]

        let snapshot = store.makeCloudSnapshot(userId: userId)
        let restored = AppDataStore(enableCloudSync: false)
        restored.applyCloudSnapshot(snapshot)

        #expect(restored.schedules.count == 1)
        #expect(restored.schedules.first?.items.count == 1)
        #expect(restored.schedules.first?.items.first?.schedule?.id == schedule.id)
        #expect(restored.activeFishes.first?.speciesId == FishSpecies.guppy.rawValue)
        #expect(restored.collectedFishes.first?.speciesId == FishSpecies.medaka.rawValue)
        #expect(restored.careRecords.first?.growthStage == .adult)
        #expect(restored.aquariums.first?.totalWaterCollected == 500)
        #expect(restored.profiles.first?.nickname == "Yuya")
    }

    @MainActor
    @Test func cloudEmptyUploadsLocalCacheOnLoad() async throws {
        resetLocalTestState()
        defer { resetLocalTestState() }

        let userId = UUID()
        let localStore = AppDataStore(enableCloudSync: false)
        await localStore.addSchedule(name: "ローカル朝", targetDepartureTime: .now)

        let cloud = FakeCloudDataService(initialSnapshot: CloudSnapshot())
        let syncingStore = AppDataStore(
            cloudDataService: cloud,
            enableCloudSync: true,
            cloudUserIdProvider: { userId }
        )

        await syncingStore.load()

        #expect(syncingStore.schedules.first?.name == "ローカル朝")
        #expect(cloud.savedSnapshots.last?.schedules.first?.name == "ローカル朝")
        #expect(cloud.savedUserIds.last == userId)
    }

    @MainActor
    @Test func cloudDataWinsOverLocalCacheOnLoad() async throws {
        resetLocalTestState()
        defer { resetLocalTestState() }

        let userId = UUID()
        let localStore = AppDataStore(enableCloudSync: false)
        await localStore.addSchedule(name: "端末側", targetDepartureTime: .now)

        let cloudSchedule = CloudSchedule(
            id: UUID(),
            userId: userId,
            name: "クラウド側",
            targetDepartureTime: .now,
            isActive: true,
            createdAt: .now,
            updatedAt: .now
        )
        let cloud = FakeCloudDataService(initialSnapshot: CloudSnapshot(schedules: [cloudSchedule]))
        let syncingStore = AppDataStore(
            cloudDataService: cloud,
            enableCloudSync: true,
            cloudUserIdProvider: { userId }
        )

        await syncingStore.load()

        #expect(syncingStore.schedules.map(\.name) == ["クラウド側"])
        let cachedStore = AppDataStore(enableCloudSync: false)
        await cachedStore.load()
        #expect(cachedStore.schedules.map(\.name) == ["クラウド側"])
    }

    @MainActor
    @Test func resetAquariumDeletesOnlyAquariumCloudData() async throws {
        resetLocalTestState()
        defer { resetLocalTestState() }

        let userId = UUID()
        let cloud = FakeCloudDataService(initialSnapshot: CloudSnapshot())
        let store = AppDataStore(
            cloudDataService: cloud,
            enableCloudSync: true,
            cloudUserIdProvider: { userId }
        )
        store.schedules = [UserSchedule(name: "残す", targetDepartureTime: .now, isActive: true)]
        store.activeFishes = [ActiveFish(speciesId: FishSpecies.medaka.rawValue, name: "メダカ", requiredTotalWater: 80)]
        store.collectedFishes = [CollectedFish(name: "メダカ", speciesId: FishSpecies.medaka.rawValue, succeeded: true, waterRatio: 1)]
        store.careRecords = [
            FishCareRecord(
                speciesId: FishSpecies.medaka.rawValue,
                waterAmount: 80,
                totalWaterAfter: 80,
                requiredTotalWater: 80,
                growthStage: .adult,
                completedGrowth: true
            )
        ]
        store.aquariums = [Aquarium(totalWaterCollected: 100)]

        await store.resetAquarium()

        #expect(cloud.deletedAquariumUserIds == [userId])
        #expect(store.schedules.first?.name == "残す")
        #expect(store.activeFishes.isEmpty)
        #expect(store.collectedFishes.isEmpty)
        #expect(store.careRecords.isEmpty)
        #expect(store.aquariums.isEmpty)
    }

    @MainActor
    @Test func resetAllDeletesCloudAndSeedsDefaultSchedule() async throws {
        resetLocalTestState()
        defer { resetLocalTestState() }

        let userId = UUID()
        let cloud = FakeCloudDataService(initialSnapshot: CloudSnapshot())
        let store = AppDataStore(
            cloudDataService: cloud,
            enableCloudSync: true,
            cloudUserIdProvider: { userId }
        )
        store.schedules = [UserSchedule(name: "消す", targetDepartureTime: .now, isActive: true)]
        store.profiles = [UserProfile(nickname: "消す")]

        await store.resetAll()

        #expect(cloud.deletedAllUserIds == [userId])
        #expect(store.schedules.count == 1)
        #expect(store.schedules.first?.name == "平日通常モード")
        #expect(store.profiles.isEmpty)
        #expect(cloud.savedSnapshots.last?.schedules.first?.name == "平日通常モード")
    }

    @MainActor
    @Test func cloudLoadPurchasesUpdatesStoreDeveloperSupportState() async throws {
        resetLocalTestState()
        defer { resetLocalTestState() }

        let userId = UUID()
        let cloud = FakeCloudDataService(initialSnapshot: CloudSnapshot())
        cloud.purchases = [
            CloudPurchase(
                id: UUID(),
                userId: userId,
                productId: "com.dewtime.support.tier1",
                originalTransactionId: "tx_123",
                purchasedAt: .now,
                createdAt: .now
            )
        ]

        let store = AppDataStore(
            cloudDataService: cloud,
            enableCloudSync: true,
            cloudUserIdProvider: { userId }
        )

        #expect(store.isDeveloperSupported == false)
        await store.load()
        #expect(store.isDeveloperSupported == true)
    }

    @MainActor
    @Test func updateDeveloperSupportStatusSavesToCloud() async throws {
        resetLocalTestState()
        defer { resetLocalTestState() }

        let userId = UUID()
        let cloud = FakeCloudDataService(initialSnapshot: CloudSnapshot())
        let store = AppDataStore(
            cloudDataService: cloud,
            enableCloudSync: true,
            cloudUserIdProvider: { userId }
        )

        await store.updateDeveloperSupportStatus(productId: "com.dewtime.support.tier2", originalTransactionId: "tx_999")

        #expect(store.isDeveloperSupported == true)
        #expect(cloud.savedPurchases.count == 1)
        #expect(cloud.savedPurchases.first?.originalTransactionId == "tx_999")
        #expect(cloud.savedPurchases.first?.productId == "com.dewtime.support.tier2")
    }

    private func makeScheduleForLiveActivityTests() -> UserSchedule {
        let schedule = UserSchedule(name: "平日", targetDepartureTime: .now.addingTimeInterval(600), isActive: true)
        let brushing = RoutineItem(name: "ハミガキ", durationSeconds: 180, colorHex: "#38BDF8", orderIndex: 0, schedule: schedule)
        let clothes = RoutineItem(name: "着替え", durationSeconds: 420, colorHex: "#34D399", orderIndex: 1, schedule: schedule)
        schedule.items = [brushing, clothes]
        return schedule
    }

    private func resetLocalTestState() {
        [
            "dew.timer.scheduleId",
            "dew.timer.startedAt",
            "dew.timer.departed",
            "dew.timer.finalWaterLevel",
            "dew.timer.finalDelaySeconds",
            "dew.timer.selectedSpecies",
            "local_schedules",
            "local_routine_items",
            "local_active_fishes",
            "local_collected_fishes",
            "local_care_records",
            "local_aquariums",
            "local_profiles",
            "local_is_developer_supported"
        ].forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }

}

@MainActor
private final class FakeCloudDataService: CloudDataServicing {
    var snapshot: CloudSnapshot
    var savedSnapshots: [CloudSnapshot] = []
    var savedUserIds: [UUID] = []
    var deletedAquariumUserIds: [UUID] = []
    var deletedAllUserIds: [UUID] = []
    var purchases: [CloudPurchase] = []
    var savedPurchases: [CloudPurchase] = []

    init(initialSnapshot: CloudSnapshot) {
        snapshot = initialSnapshot
    }

    func loadAll(userId: UUID) async throws -> CloudSnapshot {
        snapshot
    }

    func saveAll(snapshot: CloudSnapshot, userId: UUID) async throws {
        savedSnapshots.append(snapshot)
        savedUserIds.append(userId)
        self.snapshot = snapshot
    }

    func deleteAquariumData(userId: UUID) async throws {
        deletedAquariumUserIds.append(userId)
        snapshot.activeFishes.removeAll()
        snapshot.collectedFishes.removeAll()
        snapshot.careRecords.removeAll()
        snapshot.aquariums.removeAll()
    }

    func deleteAll(userId: UUID) async throws {
        deletedAllUserIds.append(userId)
        snapshot = CloudSnapshot()
    }

    func loadPurchases(userId: UUID) async throws -> [CloudPurchase] {
        purchases
    }

    func savePurchase(_ purchase: CloudPurchase) async throws {
        savedPurchases.append(purchase)
        purchases.append(purchase)
    }
}
