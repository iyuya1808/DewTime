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
            "local_profiles"
        ].forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }

}
