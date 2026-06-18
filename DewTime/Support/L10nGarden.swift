import Foundation

extension L10n {
  // MARK: - Aquarium (live scene & sheets)

  enum Aquarium {
    static var departureRecords: String { tr("aquarium.departure_records", default: "出発記録") }
    static var level: String { tr("aquarium.level", default: "レベル") }
    static var fish: String { tr("aquarium.fish", default: "魚") }
    static var feed: String { tr("aquarium.feed", default: "餌") }
    static var dewDrop: String { tr("aquarium.dew_drop", default: "しずく") }
    static var tapToFeed: String { tr("aquarium.tap_to_feed", default: "タップして餌をあげる") }
    static var earnFeedHint: String { tr("aquarium.earn_feed_hint", default: "オンタイム出発か実績解除で獲得できます") }
    static var capacityFull: String { tr("aquarium.capacity_full", default: "水槽がいっぱいです") }
    static var capacityFullMax: String { tr("aquarium.capacity_full_max", default: "これ以上泳がせることはできません") }
    static var capacityFullGrow: String { tr("aquarium.capacity_full_grow", default: "オンタイム出発で水槽を大きくしよう") }
    static var noFeed: String { tr("aquarium.no_feed", default: "餌がありません") }

    static func levelA11y(_ level: Int) -> String {
      tr("aquarium.level_a11y", default: "水槽レベル%lld。タップで説明を表示", level)
    }

    static func fishSwimmingA11y(_ count: Int) -> String {
      tr("aquarium.fish_swimming_a11y", default: "%lld匹が泳いでいます。タップで一覧を表示", count)
    }

    static func feedStockA11y(_ count: Int) -> String {
      tr("aquarium.feed_stock_a11y", default: "餌%lld個。タップで説明を表示", count)
    }

    static var emptyHasFeedA11y: String {
      tr("aquarium.empty_has_feed_a11y", default: "タップして餌をあげると魚が増えます")
    }

    static var emptyNoFeedA11y: String {
      tr("aquarium.empty_no_feed_a11y", default: "餌がありません。オンタイム出発か実績解除で獲得できます")
    }

    static func capacityFullDewRemaining(_ count: Int) -> String {
      tr("aquarium.capacity_full_dew", default: "あと%lldしずくで収容上限が増えます", count)
    }

    static func capacityFullA11y(_ hint: String) -> String {
      tr("aquarium.capacity_full_a11y", default: "水槽がいっぱいです。%@", hint)
    }

    enum FishList {
      static var title: String { tr("aquarium.fish_list.title", default: "泳いでいる魚") }
      static var emptyTitle: String { tr("aquarium.fish_list.empty_title", default: "まだ魚がいません") }
      static var emptyDetail: String { tr("aquarium.fish_list.empty_detail", default: "餌をあげると新しい魚が泳ぎ始めます") }
      static var nameAlertTitle: String { tr("aquarium.fish_list.name_alert_title", default: "魚の名前") }
      static var nameAlertMessage: String { tr("aquarium.fish_list.name_alert_message", default: "空欄で保存すると種類名に戻ります。") }

      static func renameA11y(_ name: String) -> String {
        tr("aquarium.fish_list.rename_a11y", default: "%@の名前を編集", name)
      }
    }

    enum Guide {
      static func levelTitle(_ level: Int) -> String {
        tr("aquarium.guide.level_title", default: "水槽レベル %lld", level)
      }

      static func swimmingCount(_ current: Int, _ capacity: Int) -> String {
        tr("aquarium.guide.swimming", default: "泳がせられる魚 %lld/%lld匹", current, capacity)
      }

      static var feedAbout: String { tr("aquarium.guide.feed_about", default: "餌について") }

      static func feedOwned(_ count: Int) -> String {
        tr("aquarium.guide.feed_owned", default: "所持 %lld個", count)
      }

      static var growthStage: String { tr("aquarium.guide.growth_stage", default: "成長ステージ") }
      static var levelBenefits: String { tr("aquarium.guide.level_benefits", default: "レベルを上げると") }
      static var feedBenefits: String { tr("aquarium.guide.feed_benefits", default: "餌をあげると") }
      static var levelHow: String { tr("aquarium.guide.level_how", default: "レベルの上げ方") }
      static var feedHow: String { tr("aquarium.guide.feed_how", default: "餌の入手方法") }

      static var benefitMoreFish: String { tr("aquarium.guide.benefit.more_fish", default: "泳がせられる魚が増える") }
      static var benefitMoreSpecies: String { tr("aquarium.guide.benefit.more_species", default: "出会える魚種が増える") }

      static func levelCapacityMax(_ capacity: Int) -> String {
        tr("aquarium.guide.level_capacity_max", default: "現在の上限は%lld匹。これ以上は増えません。", capacity)
      }

      static func levelCapacityNext(next: Int, current: Int) -> String {
        tr("aquarium.guide.level_capacity_next", default: "次のレベルでは%lld匹まで泳がせられます（現在%lld匹）。", next, current)
      }

      static func levelSpeciesMore(from: Int, to: Int) -> String {
        tr("aquarium.guide.level_species_more", default: "餌やりで出る魚種が%lld種から%lld種に増え、レアな魚にも出会えます。", from, to)
      }

      static func levelSpeciesCurrent(_ count: Int) -> String {
        tr("aquarium.guide.level_species_current", default: "餌やりで%lld種類の魚が出るようになっています。", count)
      }

      static var feedTap: String { tr("aquarium.guide.feed_tap", default: "画面をタップして餌を落とせる") }
      static var feedTapDetail: String { tr("aquarium.guide.feed_tap_detail", default: "水槽の好きな場所をタップすると、餌が落ちて魚が集まります。") }
      static var feedNewFish: String { tr("aquarium.guide.feed_new_fish", default: "新しい魚が仲間入りする") }
      static var feedNewFishDetail: String { tr("aquarium.guide.feed_new_fish_detail", default: "魚が餌を食べたタイミングで、ランダムな魚種が1匹加わります。") }
      static var feedDex: String { tr("aquarium.guide.feed_dex", default: "図鑑に魚種が記録される") }
      static var feedDexDetail: String { tr("aquarium.guide.feed_dex_detail", default: "はじめて出会った魚種は図鑑に登録され、コレクションが広がります。") }
      static var levelHowDepart: String { tr("aquarium.guide.level_how_depart", default: "オンタイム出発を重ねる") }
      static var levelHowDepartDetail: String { tr("aquarium.guide.level_how_depart_detail", default: "出発時刻ぴったりに出発するとしずくが貯まり、水槽が成長します。") }
      static var feedHowOnTime: String { tr("aquarium.guide.feed_how_on_time", default: "オンタイム出発で +1") }
      static var feedHowOnTimeDetail: String { tr("aquarium.guide.feed_how_on_time_detail", default: "タイマーで出発時刻ぴったりに出発すると、餌を1個獲得できます。") }
      static var feedHowAchievement: String { tr("aquarium.guide.feed_how_achievement", default: "実績解除で獲得") }
      static var feedHowAchievementDetail: String { tr("aquarium.guide.feed_how_achievement_detail", default: "プロフィールの実績を達成すると、餌がもらえることがあります。") }
    }

    enum Growth {
      static var stagesA11y: String { tr("aquarium.growth.stages_a11y", default: "水槽の成長段階") }

      static func progressPercent(_ percent: Int) -> String {
        tr("aquarium.growth.progress_pct", default: "次の段階まで%lldパーセント", percent)
      }

      static func remainingDew(_ count: Int) -> String {
        tr("aquarium.growth.remaining_dew", default: "あと%lldしずく", count)
      }

      static func remainingA11y(_ count: Int) -> String {
        tr("aquarium.growth.remaining_a11y", default: "あと%lld回のオンタイム出発で水槽が大きくなります", count)
      }

      static func progressSummaryA11y(current: Int, next: Int) -> String {
        tr("aquarium.growth.progress_a11y", default: "オンタイム出発%lld回。次の段階は%lld回", current, next)
      }

      static func tierCurrentA11y(tier: Int, name: String, capacity: Int) -> String {
        tr("aquarium.growth.tier_current_a11y", default: "現在の段階%lld、%@。魚を%lld匹まで泳がせられます", tier, name, capacity)
      }

      static func tierUnlockedA11y(tier: Int, name: String, capacity: Int) -> String {
        tr("aquarium.growth.tier_unlocked_a11y", default: "達成済みの段階%lld、%@。魚を%lld匹まで泳がせられます", tier, name, capacity)
      }

      static func tierLockedA11y(tier: Int, name: String, threshold: Int, capacity: Int) -> String {
        tr("aquarium.growth.tier_locked_a11y", default: "未解放の段階%lld、%@。オンタイム出発%lld回で解放。魚を%lld匹まで泳がせられます", tier, name, threshold, capacity)
      }
    }

    enum Upgrade {
      static var growthSection: String { tr("aquarium.upgrade.growth", default: "水槽の成長") }
      static var occupancySection: String { tr("aquarium.upgrade.occupancy", default: "魚の収容") }
      static var capacityLabel: String { tr("aquarium.upgrade.capacity_label", default: "上限") }
      static var storageCollection: String { tr("aquarium.upgrade.storage", default: "図鑑に保管") }

      static func occupancyPercentA11y(_ percent: Int) -> String {
        tr("aquarium.upgrade.occupancy_pct_a11y", default: "水槽の%lldパーセントが埋まっています", percent)
      }

      static func swimmingA11y(swimming: Int, capacity: Int) -> String {
        tr("aquarium.upgrade.swimming_a11y", default: "%lld匹が泳いでいます。収容上限は%lld匹", swimming, capacity)
      }

      static func overflowA11y(_ count: Int) -> String {
        tr("aquarium.upgrade.overflow_a11y", default: "収容上限を超えて%lld匹が図鑑に保管されています", count)
      }
    }

    enum Care {
      static var onTime: String { tr("aquarium.care.on_time", default: "オンタイム出発") }
      static var late: String { tr("aquarium.care.late", default: "遅延あり") }
      static var dewEarnedA11y: String { tr("aquarium.care.dew_earned_a11y", default: "今回 しずく1") }
      static var dewNoneA11y: String { tr("aquarium.care.dew_none_a11y", default: "今回 しずく0") }
      static var feedEarnedA11y: String { tr("aquarium.care.feed_earned_a11y", default: "餌を1個獲得") }
      static var dewSummaryEarned: String { tr("aquarium.care.dew_summary_earned", default: "しずく1獲得") }
      static var dewSummaryNone: String { tr("aquarium.care.dew_summary_none", default: "しずくなし") }
      static var feedSummary: String { tr("aquarium.care.feed_summary", default: "餌1個") }

      static func detailA11y(date: String, dropText: String, bonusText: String) -> String {
        if bonusText.isEmpty {
          return tr("aquarium.care.detail_a11y", default: "%@、%@", date, dropText)
        }
        return tr("aquarium.care.detail_a11y_bonus", default: "%@、%@、%@", date, dropText, bonusText)
      }
    }
  }

  // MARK: - Fish detail

  enum FishDetail {
    static var morningMargin: String { tr("fish.detail.morning_margin", default: "朝のゆとり") }
    static var departure: String { tr("fish.detail.departure", default: "出発") }
    static var editNameA11y: String { tr("fish.detail.edit_name_a11y", default: "魚の名前を編集") }
    static var nameAlertTitle: String { tr("fish.detail.name_alert_title", default: "魚の名前") }
    static var nameAlertMessage: String { tr("fish.detail.name_alert_message", default: "空欄で保存すると種類名に戻ります。") }
    static var onTime: String { tr("fish.detail.on_time", default: "時間内") }
    static var overTime: String { tr("fish.detail.over_time", default: "時間超過") }

    static func recordA11y(name: String, water: String, departure: String) -> String {
      tr("fish.detail.record_a11y", default: "%@の記録。朝のゆとりは%@、出発は%@でした。", name, water, departure)
    }

    static func waterEvaluation(for ratio: Double) -> String {
      switch ratio {
      case 0.8...: return tr("fish.detail.water.plenty", default: "余裕たっぷり")
      case 0.6...: return tr("fish.detail.water.good", default: "いいペース")
      case 0.4...: return tr("fish.detail.water.ok", default: "まずまず")
      case 0.2...: return tr("fish.detail.water.tight", default: "ギリギリ")
      default: return tr("fish.detail.water.over", default: "タイムオーバー")
      }
    }
  }

  // MARK: - Gacha

  enum Gacha {
    static var newFriend: String { tr("gacha.new_friend", default: "新しい仲間が誕生！") }
    static var dexFirst: String { tr("gacha.dex_first", default: "図鑑に初登場") }
    static var viewInAquarium: String { tr("gacha.view_in_aquarium", default: "水槽で見る") }

    static func bornA11y(_ speciesName: String) -> String {
      tr("gacha.born_a11y", default: "新しい%@が誕生しました", speciesName)
    }
  }
}
