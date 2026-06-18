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

    @MainActor
    @Test func fishSpeciesDisplaySizesReflectBodyScale() async throws {
        #expect(FishSpecies.shrimp.displaySize(for: .aquarium) < FishSpecies.guppy.displaySize(for: .aquarium))
        #expect(FishSpecies.guppy.displaySize(for: .aquarium) < FishSpecies.dolphin.displaySize(for: .aquarium))
        #expect(FishSpecies.dolphin.displaySize(for: .aquarium) < FishSpecies.whaleShark.displaySize(for: .aquarium))
        #expect(FishSpecies.guppy.displaySize(for: .timer) > FishSpecies.guppy.displaySize(for: .aquarium))
        #expect(FishSpecies.shrimp.aquariumSwimSpeed > FishSpecies.whale.aquariumSwimSpeed)
    }

    @MainActor
    @Test func fishSpeciesRequiredDeparturesMatchDifficulty() async throws {
        #expect(FishSpecies.medaka.requiredDepartures == 1)
        #expect(FishSpecies.guppy.requiredDepartures == 1)
        #expect(FishSpecies.turtle.requiredDepartures == 3)
        #expect(FishSpecies.dolphin.requiredDepartures == 5)
        #expect(FishSpecies.shark.requiredDepartures == 5)
        #expect(FishSpecies.whaleShark.requiredDepartures == 7)
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

    @Test func fishGachaEligibleSpeciesRespectsAquariumTier() {
        let tier0 = FishGachaService.eligibleSpecies(tier: 0)
        #expect(tier0.contains(.medaka))
        #expect(!tier0.contains(.whale))

        let tier6 = FishGachaService.eligibleSpecies(tier: 6)
        #expect(tier6.count == FishSpecies.allCases.count)
    }

    @Test func fishGachaRollSpeciesStaysWithinTierPool() {
        struct FixedRNG: RandomNumberGenerator {
            var value: UInt64
            mutating func next() -> UInt64 { value }
        }

        var rng: FixedRNG = FixedRNG(value: 0)
        let species = FishGachaService.rollSpecies(tier: 0, rng: &rng)
        #expect(species.requiredAquariumTier <= 0)
    }

    @MainActor
    @Test func recordDepartureAwardsShizukuAndBonusFeedOnTime() async throws {
        resetLocalTestState()
        defer { resetLocalTestState() }

        let store = AppDataStore(enableCloudSync: false)
        store.aquariums = [Aquarium(totalDepartures: 5, bonusFeedStock: 1)]

        await store.recordDeparture(earnedDrop: true)

        #expect(store.aquarium().totalDepartures == 6)
        #expect(store.aquarium().bonusFeedStock == 2)
        #expect(store.careRecords.count == 1)
        #expect(store.careRecords.first?.isDepartureLog == true)
        #expect(store.careRecords.first?.departuresAfter == 6)
        #expect(store.careRecords.first?.bonusFeedAwarded == true)
    }

    @MainActor
    @Test func recordDepartureSkipsRewardsWhenDelayed() async throws {
        resetLocalTestState()
        defer { resetLocalTestState() }

        let store = AppDataStore(enableCloudSync: false)
        store.aquariums = [Aquarium(totalDepartures: 5, bonusFeedStock: 1)]

        await store.recordDeparture(earnedDrop: false)

        #expect(store.aquarium().totalDepartures == 5)
        #expect(store.aquarium().bonusFeedStock == 1)
    }

    @MainActor
    @Test func spawnFishFromFeedAddsFishWhenUnderCapacity() async throws {
        resetLocalTestState()
        defer { resetLocalTestState() }

        let store = AppDataStore(enableCloudSync: false)
        store.aquariums = [Aquarium(totalDepartures: 0)]

        let fish = await store.spawnFishFromFeed()
        #expect(fish != nil)
        #expect(store.collectedFishes.count == 1)
        #expect(store.aquariumFish().count == 1)
    }

    @MainActor
    @Test func spawnFishFromFeedReturnsNilAtCapacity() async throws {
        resetLocalTestState()
        defer { resetLocalTestState() }

        let store = AppDataStore(enableCloudSync: false)
        let aquarium = Aquarium(totalDepartures: 0)
        store.aquariums = [aquarium]
        for index in 0..<aquarium.fishCapacity {
            store.collectedFishes.append(
                CollectedFish(name: "魚\(index)", speciesId: FishSpecies.medaka.rawValue, succeeded: true, waterRatio: 1)
            )
        }

        let fish = await store.spawnFishFromFeed()
        #expect(fish == nil)
        #expect(store.collectedFishes.count == aquarium.fishCapacity)
    }

    @MainActor
    @Test func consumeBonusFeedIfAvailableDecrementsStock() async throws {
        resetLocalTestState()
        defer { resetLocalTestState() }

        let store = AppDataStore(enableCloudSync: false)
        store.aquariums = [Aquarium(bonusFeedStock: 2)]

        #expect(store.consumeBonusFeedIfAvailable())
        #expect(store.aquarium().bonusFeedStock == 1)
        #expect(store.consumeBonusFeedIfAvailable())
        #expect(store.aquarium().bonusFeedStock == 0)
        #expect(!store.consumeBonusFeedIfAvailable())
    }

    @MainActor
    @Test func syncAchievementFeedRewardsGrantsFeedOnce() async throws {
        resetLocalTestState()
        defer { resetLocalTestState() }

        let store = AppDataStore(enableCloudSync: false)
        store.aquariums = [Aquarium(bonusFeedStock: 0)]
        store.collectedFishes = [
            CollectedFish(name: "メダカ", speciesId: FishSpecies.medaka.rawValue, succeeded: true, waterRatio: 1)
        ]

        let granted = store.syncAchievementFeedRewards()
        #expect(granted == Achievement.firstAdult.feedReward)
        #expect(store.aquarium().bonusFeedStock == Achievement.firstAdult.feedReward)
        #expect(store.profile().claimedAchievementRewardIds.contains(Achievement.firstAdult.id))

        let secondGrant = store.syncAchievementFeedRewards()
        #expect(secondGrant == 0)
        #expect(store.aquarium().bonusFeedStock == Achievement.firstAdult.feedReward)
    }

    @MainActor
    @Test func syncAchievementFeedRewardsRunsDuringSaveToLocal() async throws {
        resetLocalTestState()
        defer { resetLocalTestState() }

        let store = AppDataStore(enableCloudSync: false)
        store.aquariums = [Aquarium(bonusFeedStock: 0)]
        store.collectedFishes = [
            CollectedFish(name: "メダカ", speciesId: FishSpecies.medaka.rawValue, succeeded: true, waterRatio: 1)
        ]

        await store.saveAll()
        #expect(store.aquarium().bonusFeedStock == Achievement.firstAdult.feedReward)
    }

    @Test func achievementCatalogHasProgressiveTiers() {
        #expect(Achievement.allCases.count >= 35)
        #expect(AchievementCategory.streak.achievements.map(\.id) == [
            Achievement.streak3.id, Achievement.streak7.id, Achievement.streak14.id,
            Achievement.streak30.id, Achievement.streak60.id, Achievement.streak100.id
        ])
        #expect(Achievement.streak14.feedReward > Achievement.streak3.feedReward)
    }

    @MainActor
    @Test func aquariumFishPrefersNewestFish() async throws {
        resetLocalTestState()
        defer { resetLocalTestState() }

        let store = AppDataStore(enableCloudSync: false)
        store.aquariums = [Aquarium(totalDepartures: 10)]
        let older = CollectedFish(name: "古い", speciesId: FishSpecies.medaka.rawValue, recordedAt: .now.addingTimeInterval(-100), succeeded: true, waterRatio: 1)
        let newer = CollectedFish(name: "新しい", speciesId: FishSpecies.guppy.rawValue, recordedAt: .now, succeeded: true, waterRatio: 1)
        store.collectedFishes = [older, newer]

        #expect(store.aquariumFish().map(\.id) == [newer.id, older.id])
    }

    @MainActor
    @Test func bonusFeedStockRoundTripThroughLocalPersistence() async throws {
        resetLocalTestState()
        defer { resetLocalTestState() }

        let store = AppDataStore(enableCloudSync: false)
        store.aquariums = [Aquarium(totalDepartures: 12, bonusFeedStock: 3)]
        await store.saveAll()

        let restored = AppDataStore(enableCloudSync: false)
        await restored.loadLocalCache()

        #expect(restored.aquariums.first?.bonusFeedStock == 3)
        #expect(restored.aquariums.first?.totalDepartures == 12)
    }

    @MainActor
    @Test func cloudSnapshotRoundTripsBonusFeedStock() async throws {
        let userId = UUID()
        let store = AppDataStore(enableCloudSync: false)
        store.aquariums = [Aquarium(totalDepartures: 30, bonusFeedStock: 4)]

        let snapshot = store.makeCloudSnapshot(userId: userId)
        let restored = AppDataStore(enableCloudSync: false)
        restored.applyCloudSnapshot(snapshot)

        #expect(restored.aquariums.first?.bonusFeedStock == 4)
        #expect(restored.aquariums.first?.totalDepartures == 30)
    }

    @MainActor
    @Test func timerDepartAwardsAquariumRewards() async throws {
        resetLocalTestState()
        defer { resetLocalTestState() }

        let store = AppDataStore(enableCloudSync: false)
        store.aquariums = [Aquarium(totalDepartures: 2, bonusFeedStock: 0)]
        let target = Date.now.addingTimeInterval(600)
        let vm = TimerViewModel(targetDepartureTime: target)
        vm.start()

        await vm.depart(store: store)

        #expect(vm.finalEarnedDrop)
        #expect(vm.finalBonusFeedAwarded)
        #expect(vm.finalAquariumDepartures == 3)
        #expect(store.aquarium().totalDepartures == 3)
        #expect(store.aquarium().bonusFeedStock == 1)
        #expect(store.collectedFishes.isEmpty)

        vm.reset()
    }

    @MainActor
    @Test func recoverDepartedSessionRetriesUnsavedDeparture() async throws {
        resetLocalTestState()
        defer { resetLocalTestState() }

        let store = AppDataStore(enableCloudSync: false)
        store.aquariums = [Aquarium(totalDepartures: 1, bonusFeedStock: 0)]
        let target = Date.now.addingTimeInterval(600)
        let vm = TimerViewModel(targetDepartureTime: target)
        vm.start()

        await vm.depart(store: store)
        #expect(store.aquarium().totalDepartures == 2)

        vm.reset()
        store.careRecords.removeAll()
        store.aquariums = [Aquarium(totalDepartures: 1, bonusFeedStock: 0)]

        let ud = UserDefaults.standard
        ud.set(target, forKey: "dew.timer.targetDepartureTime")
        ud.set(Date.now.addingTimeInterval(-120), forKey: "dew.timer.startedAt")
        ud.set(true, forKey: "dew.timer.departed")
        ud.set(0.2, forKey: "dew.timer.finalWaterLevel")
        ud.set(0, forKey: "dew.timer.finalDelaySeconds")
        ud.set(false, forKey: "dew.timer.departurePersisted")

        let restored = TimerViewModel(targetDepartureTime: target)
        #expect(restored.departed)

        await restored.recoverDepartedSession(store: store)

        #expect(store.aquarium().totalDepartures == 2)
        #expect(store.aquarium().bonusFeedStock == 1)
        #expect(restored.departurePersisted)
        #expect(restored.finalEarnedDrop)
        #expect(restored.finalAquariumDepartures == 2)

        restored.reset()
    }

    @MainActor
    @Test func recoverDepartedSessionSkipsAlreadySavedDeparture() async throws {
        resetLocalTestState()
        defer { resetLocalTestState() }

        let store = AppDataStore(enableCloudSync: false)
        store.aquariums = [Aquarium(totalDepartures: 4, bonusFeedStock: 2)]
        let target = Date.now.addingTimeInterval(600)
        let startedAt = Date.now.addingTimeInterval(-180)

        store.careRecords.append(
            FishCareRecord(
                speciesId: FishCareRecord.departureLogMarker,
                recordedAt: startedAt.addingTimeInterval(60),
                departuresAfter: 4,
                earnedDrop: true,
                growthStage: .egg,
                completedGrowth: true
            )
        )

        let ud = UserDefaults.standard
        ud.set(target, forKey: "dew.timer.targetDepartureTime")
        ud.set(startedAt, forKey: "dew.timer.startedAt")
        ud.set(true, forKey: "dew.timer.departed")
        ud.set(0.1, forKey: "dew.timer.finalWaterLevel")
        ud.set(0, forKey: "dew.timer.finalDelaySeconds")

        let restored = TimerViewModel(targetDepartureTime: target)
        await restored.recoverDepartedSession(store: store)

        #expect(store.aquarium().totalDepartures == 4)
        #expect(store.careRecords.count == 1)
        #expect(restored.finalAquariumDepartures == 4)

        restored.reset()
    }

    @MainActor
    @Test func aquariumTierUnlocksLargerSpecies() async throws {
        #expect(FishSpecies.medaka.isUnlocked(aquariumTier: 0))
        #expect(FishSpecies.dolphin.isUnlocked(aquariumTier: 4))
        #expect(!FishSpecies.dolphin.isUnlocked(aquariumTier: 3))
        #expect(FishSpecies.whaleShark.requiredAquariumName == "大水族館")
    }

    @Test func aquariumFishCapacityGrowsWithTier() {
        #expect(Aquarium(totalDepartures: 0).fishCapacity == 5)
        #expect(Aquarium(totalDepartures: 10).fishCapacity == 10)
        #expect(Aquarium(totalDepartures: 30).fishCapacity == 20)
        #expect(Aquarium(totalDepartures: 200).fishCapacity == 100)
        #expect(Aquarium(totalDepartures: 45).departuresUntilNextTier == 15)
        #expect(Aquarium(totalDepartures: 200).isMaxTier)
    }

    @MainActor
    @Test func timerViewModelComputesRemainingSecondsAndWaterLevel() async throws {
        let target = Date.now.addingTimeInterval(600)
        let vm = TimerViewModel(targetDepartureTime: target)
        vm.start(initialLevel: 1.0)

        #expect(vm.remainingSeconds > 590)
        #expect(vm.remainingSeconds <= 600)
        #expect(vm.waterLevel > 0.9)

        vm.reset()
    }

    @MainActor
    @Test func liveActivityAttributesUseEmptySegments() async throws {
        resetLocalTestState()
        defer { resetLocalTestState() }

        let vm = TimerViewModel(targetDepartureTime: .now.addingTimeInterval(600))
        vm.start()

        let attributes = try #require(vm.liveActivityAttributes())
        #expect(attributes.scheduleName == "DewTime")
        #expect(attributes.segments.isEmpty)

        vm.reset()
    }

    @MainActor
    @Test func liveActivityContentStateMirrorsTimerAndAquariumState() async throws {
        resetLocalTestState()
        defer { resetLocalTestState() }

        let store = AppDataStore()
        store.aquariums = [Aquarium(totalDepartures: 9, bonusFeedStock: 2)]
        let vm = TimerViewModel(targetDepartureTime: .now.addingTimeInterval(600))
        vm.bindStore(store)

        vm.start()

        let state = vm.liveActivityContentState(store: store)
        #expect(state.status == .running)
        #expect(state.currentTaskName.hasPrefix("残り "))
        #expect(state.nextTaskName == nil)
        #expect(state.phaseIndex == -1)
        #expect(state.aquariumTier == 1)
        #expect(state.aquariumDepartures == 10)
        #expect(state.bonusFeedStock == 2)

        vm.reset()
    }

    @MainActor
    @Test func liveActivityFinishedStatesUseTerminalLabels() async throws {
        resetLocalTestState()
        defer { resetLocalTestState() }

        let store = AppDataStore()
        let vm = TimerViewModel(targetDepartureTime: .now.addingTimeInterval(600))
        vm.start()

        let departed = vm.liveActivityContentState(store: store, status: .departed)
        let cancelled = vm.liveActivityContentState(store: store, status: .cancelled)

        #expect(departed.currentTaskName == "出発完了")
        #expect(departed.nextTaskName == nil)
        #expect(cancelled.currentTaskName == "キャンセル")
        #expect(cancelled.nextTaskName == nil)

        vm.reset()
    }

    @MainActor
    @Test func cloudSnapshotRoundTripsStoreModels() async throws {
        let userId = UUID()
        let store = AppDataStore(enableCloudSync: false)
        store.activeFishes = [
            ActiveFish(speciesId: FishSpecies.guppy.rawValue, name: FishSpecies.guppy.displayName)
        ]
        store.collectedFishes = [
            CollectedFish(name: FishSpecies.medaka.displayName, speciesId: FishSpecies.medaka.rawValue, succeeded: true, waterRatio: 1)
        ]
        store.careRecords = [
            FishCareRecord(
                speciesId: FishSpecies.medaka.rawValue,
                departuresAfter: 1,
                earnedDrop: true,
                growthStage: .adult,
                completedGrowth: true
            )
        ]
        store.aquariums = [Aquarium(totalDepartures: 500)]
        store.profiles = [UserProfile(nickname: "Yuya", avatarEmoji: "🐬")]

        let snapshot = store.makeCloudSnapshot(userId: userId)
        let restored = AppDataStore(enableCloudSync: false)
        restored.applyCloudSnapshot(snapshot)

        #expect(restored.activeFishes.first?.speciesId == FishSpecies.guppy.rawValue)
        #expect(restored.collectedFishes.first?.speciesId == FishSpecies.medaka.rawValue)
        #expect(restored.careRecords.first?.growthStage == .adult)
        #expect(restored.aquariums.first?.totalDepartures == 500)
        #expect(restored.profiles.first?.nickname == "Yuya")
    }

    @MainActor
    @Test func cloudEmptyUploadsLocalCacheOnLoad() async throws {
        resetLocalTestState()
        defer { resetLocalTestState() }

        let userId = UUID()
        let localStore = AppDataStore(enableCloudSync: false)
        localStore.aquariums = [Aquarium(totalDepartures: 3)]
        await localStore.saveAll()

        let cloud = FakeCloudDataService(initialSnapshot: CloudSnapshot())
        let syncingStore = AppDataStore(
            cloudDataService: cloud,
            enableCloudSync: true,
            cloudUserIdProvider: { userId }
        )

        await syncingStore.load()

        #expect(syncingStore.aquariums.first?.totalDepartures == 3)
        #expect(cloud.savedSnapshots.last?.aquariums.first?.totalDepartures == 3)
        #expect(cloud.savedUserIds.last == userId)
    }

    @MainActor
    @Test func cloudDataWinsOverLocalCacheOnLoad() async throws {
        resetLocalTestState()
        defer { resetLocalTestState() }

        let userId = UUID()
        let localStore = AppDataStore(enableCloudSync: false)
        localStore.aquariums = [Aquarium(totalDepartures: 1)]
        await localStore.saveAll()

        let cloudAquarium = CloudAquarium(
            id: UUID(),
            userId: userId,
            totalDepartures: 99,
            bonusFeedStock: 0,
            createdAt: .now,
            updatedAt: .now
        )
        let cloud = FakeCloudDataService(initialSnapshot: CloudSnapshot(aquariums: [cloudAquarium]))
        let syncingStore = AppDataStore(
            cloudDataService: cloud,
            enableCloudSync: true,
            cloudUserIdProvider: { userId }
        )

        await syncingStore.load()

        #expect(syncingStore.aquariums.first?.totalDepartures == 99)
        let cachedStore = AppDataStore(enableCloudSync: false)
        await cachedStore.loadLocalCache()
        #expect(cachedStore.aquariums.first?.totalDepartures == 99)
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
        store.activeFishes = [ActiveFish(speciesId: FishSpecies.medaka.rawValue, name: "メダカ")]
        store.profiles = [UserProfile(nickname: "残す")]
        store.collectedFishes = [CollectedFish(name: "メダカ", speciesId: FishSpecies.medaka.rawValue, succeeded: true, waterRatio: 1)]
        store.careRecords = [
            FishCareRecord(
                speciesId: FishSpecies.medaka.rawValue,
                departuresAfter: 1,
                earnedDrop: true,
                growthStage: .adult,
                completedGrowth: true
            )
        ]
        store.aquariums = [Aquarium(totalDepartures: 100)]

        await store.resetAquarium()

        #expect(cloud.deletedAquariumUserIds == [userId])
        #expect(store.profiles.first?.nickname == "残す")
        #expect(store.activeFishes.isEmpty)
        #expect(store.collectedFishes.isEmpty)
        #expect(store.careRecords.isEmpty)
        #expect(store.aquariums.isEmpty)
    }

    @MainActor
    @Test func resetAllDeletesCloudData() async throws {
        resetLocalTestState()
        defer { resetLocalTestState() }

        let userId = UUID()
        let cloud = FakeCloudDataService(initialSnapshot: CloudSnapshot())
        let store = AppDataStore(
            cloudDataService: cloud,
            enableCloudSync: true,
            cloudUserIdProvider: { userId }
        )
        store.profiles = [UserProfile(nickname: "消す")]
        store.aquariums = [Aquarium(totalDepartures: 10)]

        await store.resetAll()

        #expect(cloud.deletedAllUserIds == [userId])
        #expect(store.aquariums.isEmpty)
        #expect(store.profiles.first?.nickname == "あなた")
        #expect(cloud.savedSnapshots.last?.aquariums.isEmpty == true)
        #expect(cloud.savedSnapshots.last?.profiles.count == 1)
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

    private func resetLocalTestState() {
        [
            "dew.timer.scheduleId",
            "dew.timer.targetDepartureTime",
            "dew.timer.startedAt",
            "dew.timer.departed",
            "dew.timer.finalWaterLevel",
            "dew.timer.finalDelaySeconds",
            "dew.timer.initialWaterLevel",
            "dew.timer.departurePersisted",
            "dew.timer.selectedSpecies",
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
