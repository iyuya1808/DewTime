import Foundation
import SwiftUI

/// プロフィール・実績向けの集計ヘルパー。
enum ProfileStats {
    /// 連続して記録のある最長日数。
    static func longestStreak(in records: [FishCareRecord], calendar: Calendar = .current) -> Int {
        let days = Set(records.map { calendar.startOfDay(for: $0.recordedAt) }).sorted()
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
}

/// 通算の達成バッジ。獲得判定は `AppDataStore` 全体（全期間）から導出する。
enum Achievement: String, CaseIterable, Identifiable {
    case firstWatering, firstAdult
    case streak3, streak7, streak30
    case dex5, dex10, dexAll
    case water1000, water5000
    case aquariumMid, aquariumLarge

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstWatering:  return "はじめの一滴"
        case .firstAdult:     return "初めての成魚"
        case .streak3:        return "3日連続"
        case .streak7:        return "1週間皆勤"
        case .streak30:       return "30日マスター"
        case .dex5:           return "コレクター"
        case .dex10:          return "図鑑の達人"
        case .dexAll:         return "コンプリート"
        case .water1000:      return "1000pt達成"
        case .water5000:      return "水の番人"
        case .aquariumMid:    return "中型水槽"
        case .aquariumLarge:  return "大型水槽"
        }
    }

    var detail: String {
        switch self {
        case .firstWatering:  return "はじめて水やりを記録した"
        case .firstAdult:     return "魚を成魚まで育てた"
        case .streak3:        return "3日続けて水やりした"
        case .streak7:        return "7日続けて水やりした"
        case .streak30:       return "30日続けて水やりした"
        case .dex5:           return "図鑑に5種類登録した"
        case .dex10:          return "図鑑に10種類登録した"
        case .dexAll:         return "図鑑を全15種コンプリートした"
        case .water1000:      return "累計1000ptの水を注いだ"
        case .water5000:      return "累計5000ptの水を注いだ"
        case .aquariumMid:    return "水槽が中型まで育った"
        case .aquariumLarge:  return "水槽が大型まで育った"
        }
    }

    var emoji: String {
        switch self {
        case .firstWatering:  return "🌱"
        case .firstAdult:     return "🎉"
        case .streak3:        return "🔥"
        case .streak7:        return "⭐️"
        case .streak30:       return "👑"
        case .dex5:           return "📖"
        case .dex10:          return "📚"
        case .dexAll:         return "🏆"
        case .water1000:      return "💧"
        case .water5000:      return "🌊"
        case .aquariumMid:    return "🐠"
        case .aquariumLarge:  return "🐋"
        }
    }

    var tint: Color {
        switch self {
        case .firstWatering, .firstAdult:        return .green
        case .streak3, .streak7, .streak30:      return .orange
        case .dex5, .dex10, .dexAll:             return .purple
        case .water1000, .water5000:             return .cyan
        case .aquariumMid, .aquariumLarge:       return .teal
        }
    }

    /// 目標値に対する現在値（達成度表示用）。`(current, target)`。
    func progress(in store: AppDataStore) -> (current: Int, target: Int) {
        let dexCount = Set(store.collectedFishes.map(\.speciesId)).count
        let streak = ProfileStats.longestStreak(in: store.careRecords)
        let cumulativeWater = store.aquariums.first?.totalDepartures ?? 0
        let tier = store.aquariums.first?.sizeTier ?? 0
        let adults = store.collectedFishes.count

        switch self {
        case .firstWatering: return (min(store.careRecords.count, 1), 1)
        case .firstAdult:    return (min(adults, 1), 1)
        case .streak3:       return (min(streak, 3), 3)
        case .streak7:       return (min(streak, 7), 7)
        case .streak30:      return (min(streak, 30), 30)
        case .dex5:          return (min(dexCount, 5), 5)
        case .dex10:         return (min(dexCount, 10), 10)
        case .dexAll:        return (min(dexCount, FishSpecies.allCases.count), FishSpecies.allCases.count)
        case .water1000:     return (min(cumulativeWater, 1000), 1000)
        case .water5000:     return (min(cumulativeWater, 5000), 5000)
        case .aquariumMid:   return (min(tier, 2), 2)
        case .aquariumLarge: return (min(tier, 3), 3)
        }
    }

    func isUnlocked(in store: AppDataStore) -> Bool {
        let p = progress(in: store)
        return p.current >= p.target
    }

    var progressText: String {
        // 達成度のラベル。aquarium 系は段階なので個別表記。
        switch self {
        case .aquariumMid:   return "中型到達"
        case .aquariumLarge: return "大型到達"
        default:             return ""
        }
    }
}
