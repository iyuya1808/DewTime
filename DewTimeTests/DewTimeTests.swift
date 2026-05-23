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
    @Test func flowerSpeciesTotalWaterRangesMatchPlan() async throws {
        #expect(FlowerSpecies.cactus.requiredTotalWaterRange == 80...130)
        #expect(FlowerSpecies.daisy.requiredTotalWaterRange == 120...180)
        #expect(FlowerSpecies.rose.requiredTotalWaterRange == 160...240)
        #expect(FlowerSpecies.tulip.requiredTotalWaterRange == 220...320)
        #expect(FlowerSpecies.sunflower.requiredTotalWaterRange == 280...420)

        for species in FlowerSpecies.allCases {
            for _ in 0..<20 {
                let requiredWater = Int(species.makeRequiredTotalWater())
                #expect(species.requiredTotalWaterRange.contains(requiredWater))
            }
        }
    }

    @MainActor
    @Test func growthStageUsesExpectedThresholds() async throws {
        #expect(GrowthStage.stage(for: 0.0) == .seed)
        #expect(GrowthStage.stage(for: 0.24) == .seed)
        #expect(GrowthStage.stage(for: 0.25) == .sprout)
        #expect(GrowthStage.stage(for: 0.54) == .sprout)
        #expect(GrowthStage.stage(for: 0.55) == .leaves)
        #expect(GrowthStage.stage(for: 0.99) == .leaves)
        #expect(GrowthStage.stage(for: 1.0) == .bloom)
    }

    @MainActor
    @Test func timerViewModelCreatesAndPersistsSelectedSpecies() async throws {
        UserDefaults.standard.removeObject(forKey: "dew.timer.selectedSpecies")
        let container = try makeInMemoryContainer()
        let schedule = UserSchedule(name: "平日", targetDepartureTime: .now.addingTimeInterval(600), isActive: true)

        let vm = TimerViewModel(schedule: schedule)
        vm.selectSpecies(.rose, context: container.mainContext)

        let plants = try container.mainContext.fetch(FetchDescriptor<ActivePlant>())
        #expect(plants.count == 1)
        #expect(plants.first?.speciesId == FlowerSpecies.rose.rawValue)
        #expect(plants.first?.receivedWater == 0)
        #expect(FlowerSpecies.rose.requiredTotalWaterRange.contains(Int(plants.first?.requiredTotalWater ?? 0)))

        let restored = TimerViewModel(schedule: schedule)
        #expect(restored.selectedSpecies == .rose)

        UserDefaults.standard.removeObject(forKey: "dew.timer.selectedSpecies")
    }

    @MainActor
    @Test func departAddsWateringRecordWithoutCompletingWhenShort() async throws {
        UserDefaults.standard.removeObject(forKey: "dew.timer.selectedSpecies")
        let container = try makeInMemoryContainer()
        let schedule = UserSchedule(name: "平日", targetDepartureTime: .now.addingTimeInterval(600), isActive: true)
        let vm = TimerViewModel(schedule: schedule)
        vm.selectSpecies(.sunflower, context: container.mainContext)

        let plantsBefore = try container.mainContext.fetch(FetchDescriptor<ActivePlant>())
        let plant = try #require(plantsBefore.first)
        plant.requiredTotalWater = 300
        plant.receivedWater = 0

        vm.depart(context: container.mainContext)

        let records = try container.mainContext.fetch(FetchDescriptor<PlantWateringRecord>())
        let flowers = try container.mainContext.fetch(FetchDescriptor<PlantFlower>())
        let plantsAfter = try container.mainContext.fetch(FetchDescriptor<ActivePlant>())

        #expect(records.count == 1)
        #expect(records.first?.speciesId == FlowerSpecies.sunflower.rawValue)
        #expect(records.first?.waterAmount == 100)
        #expect(records.first?.totalWaterAfter == 100)
        #expect(records.first?.completedGrowth == false)
        #expect(flowers.isEmpty)
        #expect(plantsAfter.first?.receivedWater == 100)
        #expect(plantsAfter.first?.isCompleted == false)
        #expect(vm.activePlant != nil)

        vm.reset()
        UserDefaults.standard.removeObject(forKey: "dew.timer.selectedSpecies")
    }

    @MainActor
    @Test func departCompletesPlantAndCreatesFlowerWhenEnoughWater() async throws {
        UserDefaults.standard.removeObject(forKey: "dew.timer.selectedSpecies")
        let container = try makeInMemoryContainer()
        let schedule = UserSchedule(name: "平日", targetDepartureTime: .now.addingTimeInterval(600), isActive: true)
        let vm = TimerViewModel(schedule: schedule)
        vm.selectSpecies(.cactus, context: container.mainContext)

        let plantsBefore = try container.mainContext.fetch(FetchDescriptor<ActivePlant>())
        let plant = try #require(plantsBefore.first)
        plant.requiredTotalWater = 80
        plant.receivedWater = 20

        vm.depart(context: container.mainContext)

        let records = try container.mainContext.fetch(FetchDescriptor<PlantWateringRecord>())
        let flowers = try container.mainContext.fetch(FetchDescriptor<PlantFlower>())
        let plantsAfter = try container.mainContext.fetch(FetchDescriptor<ActivePlant>())

        #expect(records.count == 1)
        #expect(records.first?.waterAmount == 100)
        #expect(records.first?.totalWaterAfter == 80)
        #expect(records.first?.growthStage == .bloom)
        #expect(records.first?.completedGrowth == true)
        #expect(flowers.count == 1)
        #expect(flowers.first?.speciesId == FlowerSpecies.cactus.rawValue)
        #expect(flowers.first?.succeeded == true)
        #expect(plantsAfter.first?.receivedWater == 80)
        #expect(plantsAfter.first?.isCompleted == true)
        #expect(vm.activePlant == nil)

        vm.reset()
        UserDefaults.standard.removeObject(forKey: "dew.timer.selectedSpecies")
    }

    @MainActor
    private func makeInMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: UserSchedule.self, RoutineItem.self, PlantFlower.self, ActivePlant.self, PlantWateringRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

}
