//
//  DewTimeTests.swift
//  DewTimeTests
//
//  Created by 糸長優矢 on 2026/05/22.
//

import Testing
import Foundation
import SwiftData
@testable import DewTime

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

    @MainActor
    @Test func timerViewModelCreatesAndPersistsSelectedSpecies() async throws {
        UserDefaults.standard.removeObject(forKey: "dew.timer.selectedSpecies")
        let container = try makeInMemoryContainer()
        let schedule = UserSchedule(name: "平日", targetDepartureTime: .now.addingTimeInterval(600), isActive: true)

        let vm = TimerViewModel(schedule: schedule)
        vm.selectSpecies(.dolphin, context: container.mainContext)

        let fishes = try container.mainContext.fetch(FetchDescriptor<ActiveFish>())
        #expect(fishes.count == 1)
        #expect(fishes.first?.speciesId == FishSpecies.dolphin.rawValue)
        #expect(fishes.first?.receivedWater == 0)
        #expect(FishSpecies.dolphin.requiredTotalWaterRange.contains(Int(fishes.first?.requiredTotalWater ?? 0)))

        let restored = TimerViewModel(schedule: schedule)
        #expect(restored.selectedSpecies == .dolphin)

        UserDefaults.standard.removeObject(forKey: "dew.timer.selectedSpecies")
    }

    @MainActor
    @Test func departAddsWateringRecordWithoutCompletingWhenShort() async throws {
        UserDefaults.standard.removeObject(forKey: "dew.timer.selectedSpecies")
        let container = try makeInMemoryContainer()
        let schedule = UserSchedule(name: "平日", targetDepartureTime: .now.addingTimeInterval(600), isActive: true)
        let vm = TimerViewModel(schedule: schedule)
        vm.selectSpecies(.shark, context: container.mainContext)

        let fishesBefore = try container.mainContext.fetch(FetchDescriptor<ActiveFish>())
        let fish = try #require(fishesBefore.first)
        fish.requiredTotalWater = 300
        fish.receivedWater = 0

        vm.depart(context: container.mainContext)

        let records = try container.mainContext.fetch(FetchDescriptor<FishCareRecord>())
        let collected = try container.mainContext.fetch(FetchDescriptor<CollectedFish>())
        let fishesAfter = try container.mainContext.fetch(FetchDescriptor<ActiveFish>())

        #expect(records.count == 1)
        #expect(records.first?.speciesId == FishSpecies.shark.rawValue)
        #expect(records.first?.waterAmount == 100)
        #expect(records.first?.totalWaterAfter == 100)
        #expect(records.first?.completedGrowth == false)
        #expect(collected.isEmpty)
        #expect(fishesAfter.first?.receivedWater == 100)
        #expect(fishesAfter.first?.isCompleted == false)
        #expect(vm.activeFish != nil)

        vm.reset()
        UserDefaults.standard.removeObject(forKey: "dew.timer.selectedSpecies")
    }

    @MainActor
    @Test func departCompletesFishAndCreatesCollectionRecordWhenEnoughWater() async throws {
        UserDefaults.standard.removeObject(forKey: "dew.timer.selectedSpecies")
        let container = try makeInMemoryContainer()
        let schedule = UserSchedule(name: "平日", targetDepartureTime: .now.addingTimeInterval(600), isActive: true)
        let vm = TimerViewModel(schedule: schedule)
        vm.selectSpecies(.medaka, context: container.mainContext)

        let fishesBefore = try container.mainContext.fetch(FetchDescriptor<ActiveFish>())
        let fish = try #require(fishesBefore.first)
        fish.requiredTotalWater = 80
        fish.receivedWater = 20

        vm.depart(context: container.mainContext)

        let records = try container.mainContext.fetch(FetchDescriptor<FishCareRecord>())
        let collected = try container.mainContext.fetch(FetchDescriptor<CollectedFish>())
        let fishesAfter = try container.mainContext.fetch(FetchDescriptor<ActiveFish>())

        #expect(records.count == 1)
        #expect(records.first?.waterAmount == 100)
        #expect(records.first?.totalWaterAfter == 80)
        #expect(records.first?.growthStage == .adult)
        #expect(records.first?.completedGrowth == true)
        #expect(collected.count == 1)
        #expect(collected.first?.speciesId == FishSpecies.medaka.rawValue)
        #expect(collected.first?.succeeded == true)
        #expect(fishesAfter.first?.receivedWater == 80)
        #expect(fishesAfter.first?.isCompleted == true)
        #expect(vm.activeFish == nil)

        vm.reset()
        UserDefaults.standard.removeObject(forKey: "dew.timer.selectedSpecies")
    }

    @MainActor
    @Test func aquariumTierUnlocksLargerSpecies() async throws {
        #expect(FishSpecies.medaka.isUnlocked(aquariumTier: 0))
        #expect(FishSpecies.dolphin.isUnlocked(aquariumTier: 4))
        #expect(!FishSpecies.dolphin.isUnlocked(aquariumTier: 3))
        #expect(FishSpecies.whaleShark.requiredAquariumName == "大水族館")
    }

    @MainActor
    private func makeInMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: UserSchedule.self, RoutineItem.self, CollectedFish.self, ActiveFish.self, FishCareRecord.self, Aquarium.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

}
