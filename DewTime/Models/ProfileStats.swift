import Foundation
import SwiftUI

/// プロフィール・実績向けの集計ヘルパー。
enum ProfileStats {
    /// オンタイム出発の記録（新ログ + 旧データの earnedDrop）。
    static func onTimeDepartureRecords(in records: [FishCareRecord]) -> [FishCareRecord] {
        records.filter(\.earnedDrop)
    }

    /// 連続してオンタイム出発があった最長日数。
    static func longestOnTimeStreak(in records: [FishCareRecord], calendar: Calendar = .current) -> Int {
        let days = Set(onTimeDepartureRecords(in: records).map { calendar.startOfDay(for: $0.recordedAt) }).sorted()
        guard !days.isEmpty else { return 0 }
        var best = 1, current = 1
        for index in days.indices.dropFirst() {
            let previous = days[days.index(before: index)]
            let distance = calendar.dateComponents([.day], from: previous, to: days[index]).day ?? 0
            if distance == 1 { current += 1 } else { current = 1 }
            best = max(best, current)
        }
        return best
    }

    /// 図鑑に登録された魚種数。
    static func discoveredSpeciesCount(in store: AppDataStore) -> Int {
        Set(store.collectedFishes.map(\.speciesId)).count
    }

    /// オンタイム出発の記録件数（ログ未整備の旧データは累計しずくで補完）。
    static func onTimeDepartureCount(in store: AppDataStore) -> Int {
        let fromLogs = onTimeDepartureRecords(in: store.careRecords).count
        let totalShizuku = store.aquariums.first?.totalDepartures ?? 0
        return max(fromLogs, totalShizuku)
    }

    /// 獲得した魚の総数（同種含む）。
    static func totalFishCollected(in store: AppDataStore) -> Int {
        store.collectedFishes.count
    }

    /// 利用開始からの経過日数。
    static func daysSinceStart(in store: AppDataStore) -> Int {
        store.profile().daysSinceStart
    }
}

/// 実績の大分類。同カテゴリ内で段階的に解除される。
enum AchievementCategory: String, CaseIterable, Identifiable {
    case departure
    case streak
    case encyclopedia
    case fishHerd
    case aquarium
    case journey

    var id: String { rawValue }

    var title: String {
        L10n.Achievements.categoryTitle(self)
    }

    var tint: Color {
        switch self {
        case .departure:    return .cyan
        case .streak:       return .orange
        case .encyclopedia: return .purple
        case .fishHerd:     return .green
        case .aquarium:     return .teal
        case .journey:      return .pink
        }
    }

    var achievements: [Achievement] {
        Achievement.allCases
            .filter { $0.category == self }
            .sorted { $0.sortOrder < $1.sortOrder }
    }
}

/// 通算の達成バッジ。獲得判定は `AppDataStore` 全体（全期間）から導出する。
enum Achievement: String, CaseIterable, Identifiable {
    // しずく
    case firstWatering, departures10, departures25, departures50, departures100
    case departures200, departures500, departures1000
    // 連続出発
    case streak3, streak7, streak14, streak30, streak60, streak100
    // 図鑑
    case firstAdult, dex3, dex5, dex8, dex10, dex12, dexAll
    // 仲間（総獲得数）
    case fish5, fish10, fish25, fish50, fish100
    // 水槽
    case aquariumLv2, aquariumMid, aquariumLarge, aquariumLv5, aquariumLv6, aquariumMax
    // 記念日
    case days7, days30, days100, days200, days365

    var id: String { rawValue }

    var category: AchievementCategory {
        switch self {
        case .firstWatering, .departures10, .departures25, .departures50, .departures100,
             .departures200, .departures500, .departures1000:
            return .departure
        case .streak3, .streak7, .streak14, .streak30, .streak60, .streak100:
            return .streak
        case .firstAdult, .dex3, .dex5, .dex8, .dex10, .dex12, .dexAll:
            return .encyclopedia
        case .fish5, .fish10, .fish25, .fish50, .fish100:
            return .fishHerd
        case .aquariumLv2, .aquariumMid, .aquariumLarge, .aquariumLv5, .aquariumLv6, .aquariumMax:
            return .aquarium
        case .days7, .days30, .days100, .days200, .days365:
            return .journey
        }
    }

    var sortOrder: Int {
        switch self {
        case .firstWatering:   return 0
        case .departures10:    return 1
        case .departures25:    return 2
        case .departures50:    return 3
        case .departures100:   return 4
        case .departures200:   return 5
        case .departures500:   return 6
        case .departures1000:  return 7
        case .streak3:         return 0
        case .streak7:         return 1
        case .streak14:        return 2
        case .streak30:        return 3
        case .streak60:        return 4
        case .streak100:       return 5
        case .firstAdult:      return 0
        case .dex3:            return 1
        case .dex5:            return 2
        case .dex8:            return 3
        case .dex10:           return 4
        case .dex12:           return 5
        case .dexAll:          return 6
        case .fish5:           return 0
        case .fish10:          return 1
        case .fish25:          return 2
        case .fish50:          return 3
        case .fish100:         return 4
        case .aquariumLv2:     return 0
        case .aquariumMid:     return 1
        case .aquariumLarge:   return 2
        case .aquariumLv5:     return 3
        case .aquariumLv6:     return 4
        case .aquariumMax:     return 5
        case .days7:           return 0
        case .days30:          return 1
        case .days100:         return 2
        case .days200:         return 3
        case .days365:         return 4
        }
    }

    var title: String {
        L10n.Achievements.title(self)
    }

    var detail: String {
        L10n.Achievements.detail(self)
    }

    var emoji: String {
        switch self {
        case .firstWatering, .departures10, .departures25: return "💧"
        case .departures50, .departures100:                 return "💦"
        case .departures200, .departures500, .departures1000: return "🌊"
        case .streak3:        return "🔥"
        case .streak7:        return "⭐️"
        case .streak14:       return "✨"
        case .streak30:       return "👑"
        case .streak60:       return "🏅"
        case .streak100:      return "🎖️"
        case .firstAdult:     return "🐟"
        case .dex3, .dex5:    return "📖"
        case .dex8, .dex10:   return "📚"
        case .dex12:          return "🔖"
        case .dexAll:         return "🏆"
        case .fish5, .fish10: return "🐠"
        case .fish25, .fish50: return "🐡"
        case .fish100:        return "🦈"
        case .aquariumLv2:    return "🫧"
        case .aquariumMid:    return "🐠"
        case .aquariumLarge:  return "🐋"
        case .aquariumLv5:    return "🪸"
        case .aquariumLv6:    return "🐬"
        case .aquariumMax:    return "🐳"
        case .days7:          return "🌱"
        case .days30:         return "📅"
        case .days100:        return "🌸"
        case .days200:        return "🌺"
        case .days365:        return "🎂"
        }
    }

    var tint: Color { category.tint }

    /// 初回解除時に水槽へ付与される餌の数。
    var feedReward: Int {
        switch self {
        case .firstWatering, .firstAdult: return 1
        case .departures10, .streak3, .dex3, .fish5, .aquariumLv2, .days7:
            return 2
        case .departures25, .streak7, .dex5, .fish10, .aquariumMid, .days30:
            return 3
        case .departures50, .streak14, .dex8, .fish25, .aquariumLarge, .days100:
            return 4
        case .departures100, .streak30, .dex10, .fish50, .aquariumLv5, .days200:
            return 5
        case .departures200, .streak60, .dex12, .aquariumLv6:
            return 6
        case .departures500, .streak100, .fish100, .aquariumMax, .days365:
            return 8
        case .departures1000, .dexAll:
            return 10
        }
    }

    private var target: Int {
        switch self {
        case .firstWatering:  return 1
        case .departures10:   return 10
        case .departures25:   return 25
        case .departures50:   return 50
        case .departures100:  return 100
        case .departures200:  return 200
        case .departures500:  return 500
        case .departures1000: return 1000
        case .streak3:        return 3
        case .streak7:        return 7
        case .streak14:       return 14
        case .streak30:       return 30
        case .streak60:       return 60
        case .streak100:      return 100
        case .firstAdult:     return 1
        case .dex3:           return 3
        case .dex5:           return 5
        case .dex8:           return 8
        case .dex10:          return 10
        case .dex12:          return 12
        case .dexAll:         return FishSpecies.allCases.count
        case .fish5:          return 5
        case .fish10:         return 10
        case .fish25:         return 25
        case .fish50:         return 50
        case .fish100:        return 100
        case .aquariumLv2:    return 1
        case .aquariumMid:    return 2
        case .aquariumLarge:  return 3
        case .aquariumLv5:    return 4
        case .aquariumLv6:    return 5
        case .aquariumMax:    return 6
        case .days7:          return 7
        case .days30:         return 30
        case .days100:        return 100
        case .days200:        return 200
        case .days365:        return 365
        }
    }

    private func currentValue(in store: AppDataStore) -> Int {
        switch category {
        case .departure:
            return ProfileStats.onTimeDepartureCount(in: store)
        case .streak:
            return ProfileStats.longestOnTimeStreak(in: store.careRecords)
        case .encyclopedia:
            if self == .firstAdult {
                return ProfileStats.totalFishCollected(in: store)
            }
            return ProfileStats.discoveredSpeciesCount(in: store)
        case .fishHerd:
            return ProfileStats.totalFishCollected(in: store)
        case .aquarium:
            return store.aquariums.first?.sizeTier ?? 0
        case .journey:
            return ProfileStats.daysSinceStart(in: store)
        }
    }

    /// 目標値に対する現在値（達成度表示用）。`(current, target)`。
    func progress(in store: AppDataStore) -> (current: Int, target: Int) {
        let current = currentValue(in: store)
        return (min(current, target), target)
    }

    func isUnlocked(in store: AppDataStore) -> Bool {
        currentValue(in: store) >= target
    }

    var progressText: String {
        L10n.Achievements.progressText(self)
    }
}
