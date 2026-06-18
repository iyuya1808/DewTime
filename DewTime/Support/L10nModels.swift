import Foundation

extension L10n {
  // MARK: - Fish

  enum Fish {
    static var generic: String { tr("fish.generic", default: "魚") }

    static func name(_ species: FishSpecies) -> String {
      switch species {
      case .medaka: return tr("fish.medaka", default: "メダカ")
      case .guppy: return tr("fish.guppy", default: "グッピー")
      case .shrimp: return tr("fish.shrimp", default: "ミナミヌマエビ")
      case .pufferfish: return tr("fish.pufferfish", default: "フグ")
      case .crab: return tr("fish.crab", default: "カニ")
      case .turtle: return tr("fish.turtle", default: "ミドリガメ")
      case .squid: return tr("fish.squid", default: "イカ")
      case .octopus: return tr("fish.octopus", default: "タコ")
      case .lobster: return tr("fish.lobster", default: "ロブスター")
      case .jellyfish: return tr("fish.jellyfish", default: "クラゲ")
      case .seal: return tr("fish.seal", default: "アザラシ")
      case .dolphin: return tr("fish.dolphin", default: "イルカ")
      case .shark: return tr("fish.shark", default: "サメ")
      case .whale: return tr("fish.whale", default: "クジラ")
      case .whaleShark: return tr("fish.whale_shark", default: "ジンベエザメ")
      }
    }

    static func requiredDewDrops(_ count: Int) -> String {
      tr("format.dew_drops", default: "%lldしずく", count)
    }
  }

  // MARK: - Growth

  enum Growth {
    static func stageName(_ stage: GrowthStage) -> String {
      switch stage {
      case .egg: return tr("growth.egg", default: "卵")
      case .fry: return tr("growth.fry", default: "稚魚")
      case .juvenile: return tr("growth.juvenile", default: "幼魚")
      case .adult: return tr("growth.adult", default: "成魚")
      }
    }

    static func stageMessage(_ stage: GrowthStage) -> String {
      switch stage {
      case .egg: return tr("growth.msg.egg", default: "卵を水槽に入れました")
      case .fry: return tr("growth.msg.fry", default: "稚魚が生まれました")
      case .juvenile: return tr("growth.msg.juvenile", default: "幼魚に育ちました")
      case .adult: return tr("growth.msg.adult", default: "成魚に育ちました")
      }
    }
  }

  // MARK: - Profile

  enum Profile {
    static var defaultNickname: String { tr("profile.default_nickname", default: "あなた") }
    static var edit: String { tr("profile.edit", default: "編集") }
    static var editAccessibility: String { tr("profile.edit_accessibility", default: "プロフィールを編集") }
    static var achievements: String { tr("profile.achievements", default: "実績") }
    static var achievementUnlocked: String { tr("profile.achievement_unlocked", default: "獲得済み") }
    static var achievementTapHint: String { tr("profile.achievement_tap_hint", default: "タップして詳細を表示") }

    static func dayCount(_ days: Int) -> String {
      tr("profile.day_count", default: "%lld日目", days)
    }

    static func departureDayAccessibility(_ days: Int) -> String {
      tr("profile.departure_day_a11y", default: "出発%lld日目", days)
    }

    static func achievementsAccessibility(unlocked: Int, total: Int) -> String {
      tr("profile.achievements_a11y", default: "実績 %lld個獲得、全%lld個", unlocked, total)
    }

    static func achievementAccessibility(title: String, unlocked: Bool) -> String {
      let status = unlocked
        ? tr("profile.achievement_status_unlocked", default: "獲得済み")
        : tr("profile.achievement_status_locked", default: "未獲得")
      return tr("profile.achievement_a11y", default: "%@、%@", title, status)
    }

    static func rewardFeed(_ count: Int) -> String {
      tr("profile.reward_feed", default: "報酬: 餌%lld個", count)
    }

    static func unlockRewardFeed(_ count: Int) -> String {
      tr("profile.unlock_reward_feed", default: "解除で餌%lld個", count)
    }
  }

  // MARK: - Theme

  enum Theme {
    static func name(_ theme: AppTheme) -> String {
      switch theme {
      case .system: return tr("theme.system", default: "システム")
      case .light: return tr("theme.light", default: "ライト")
      case .dark: return tr("theme.dark", default: "ダーク")
      }
    }
  }

  // MARK: - Achievement

  enum Achievements {
    static func categoryTitle(_ category: AchievementCategory) -> String {
      switch category {
      case .departure: return tr("achievement.cat.departure", default: "しずく")
      case .streak: return tr("achievement.cat.streak", default: "連続出発")
      case .encyclopedia: return tr("achievement.cat.encyclopedia", default: "図鑑")
      case .fishHerd: return tr("achievement.cat.fish_herd", default: "仲間")
      case .aquarium: return tr("achievement.cat.aquarium", default: "水槽")
      case .journey: return tr("achievement.cat.journey", default: "記念日")
      }
    }

    static func title(_ achievement: Achievement) -> String {
      tr("achievement.\(achievement.rawValue).title", default: achievement.fallbackTitle)
    }

    static func detail(_ achievement: Achievement) -> String {
      tr("achievement.\(achievement.rawValue).detail", default: achievement.fallbackDetail)
    }

    static func progressText(_ achievement: Achievement) -> String {
      let text = achievement.fallbackProgressText
      guard !text.isEmpty else { return "" }
      return tr("achievement.\(achievement.rawValue).progress", default: text)
    }
  }
}

private extension Achievement {
  var fallbackTitle: String {
    switch self {
    case .firstWatering: return "初めてのしずく"
    case .departures10: return "しずく 10回"
    case .departures25: return "しずく 25回"
    case .departures50: return "しずく 50回"
    case .departures100: return "しずく 100回"
    case .departures200: return "しずく 200回"
    case .departures500: return "しずく 500回"
    case .departures1000: return "しずく 1000回"
    case .streak3: return "3日連続"
    case .streak7: return "1週間連続"
    case .streak14: return "2週間連続"
    case .streak30: return "1か月連続"
    case .streak60: return "2か月連続"
    case .streak100: return "100日連続"
    case .firstAdult: return "はじめの仲間"
    case .dex3: return "図鑑3種"
    case .dex5: return "コレクター"
    case .dex8: return "図鑑8種"
    case .dex10: return "図鑑の達人"
    case .dex12: return "図鑑12種"
    case .dexAll: return "コンプリート"
    case .fish5: return "5匹の仲間"
    case .fish10: return "10匹の仲間"
    case .fish25: return "25匹の仲間"
    case .fish50: return "50匹の仲間"
    case .fish100: return "100匹の仲間"
    case .aquariumLv2: return "小型水槽"
    case .aquariumMid: return "中型水槽"
    case .aquariumLarge: return "大型水槽"
    case .aquariumLv5: return "特大水槽"
    case .aquariumLv6: return "アクアリウム"
    case .aquariumMax: return "大水族館"
    case .days7: return "1週間の旅"
    case .days30: return "1か月の旅"
    case .days100: return "100日の旅"
    case .days200: return "200日の旅"
    case .days365: return "1年の旅"
    }
  }

  var fallbackDetail: String {
    switch self {
    case .firstWatering: return "はじめてオンタイム出発した"
    case .departures10: return "累計10しずく獲得した"
    case .departures25: return "累計25しずく獲得した"
    case .departures50: return "累計50しずく獲得した"
    case .departures100: return "累計100しずく獲得した"
    case .departures200: return "累計200しずく獲得した"
    case .departures500: return "累計500しずく獲得した"
    case .departures1000: return "累計1000しずく獲得した"
    case .streak3: return "3日続けてオンタイム出発した"
    case .streak7: return "7日続けてオンタイム出発した"
    case .streak14: return "14日続けてオンタイム出発した"
    case .streak30: return "30日続けてオンタイム出発した"
    case .streak60: return "60日続けてオンタイム出発した"
    case .streak100: return "100日続けてオンタイム出発した"
    case .firstAdult: return "餌やりで魚を1匹獲得した"
    case .dex3: return "図鑑に3種類登録した"
    case .dex5: return "図鑑に5種類登録した"
    case .dex8: return "図鑑に8種類登録した"
    case .dex10: return "図鑑に10種類登録した"
    case .dex12: return "図鑑に12種類登録した"
    case .dexAll: return "図鑑を全15種コンプリートした"
    case .fish5: return "魚を累計5匹獲得した"
    case .fish10: return "魚を累計10匹獲得した"
    case .fish25: return "魚を累計25匹獲得した"
    case .fish50: return "魚を累計50匹獲得した"
    case .fish100: return "魚を累計100匹獲得した"
    case .aquariumLv2: return "水槽が小型（Lv.2）まで育った"
    case .aquariumMid: return "水槽が中型（Lv.3）まで育った"
    case .aquariumLarge: return "水槽が大型（Lv.4）まで育った"
    case .aquariumLv5: return "水槽が特大（Lv.5）まで育った"
    case .aquariumLv6: return "水槽がアクアリウム（Lv.6）まで育った"
    case .aquariumMax: return "水槽が大水族館（Lv.7）まで育った"
    case .days7: return "アプリを7日間使った"
    case .days30: return "アプリを30日間使った"
    case .days100: return "アプリを100日間使った"
    case .days200: return "アプリを200日間使った"
    case .days365: return "アプリを365日間使った"
    }
  }

  var fallbackProgressText: String {
    switch self {
    case .aquariumLv2: return "Lv.2到達"
    case .aquariumMid: return "Lv.3到達"
    case .aquariumLarge: return "Lv.4到達"
    case .aquariumLv5: return "Lv.5到達"
    case .aquariumLv6: return "Lv.6到達"
    case .aquariumMax: return "Lv.7到達"
    default: return ""
    }
  }
}
