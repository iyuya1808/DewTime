import Foundation

/// 型安全なローカライズ API。新規 UI 文字列は必ずここにキーを追加し、`Localizable.xcstrings` に ja/en を登録する。
enum L10n {
  private static var lm: LocalizationManager { .shared }

  static func tr(_ key: String, default defaultValue: String) -> String {
    lm.localized(key, default: defaultValue)
  }

  static func tr(_ key: String, default defaultValue: String, _ arguments: CVarArg...) -> String {
    lm.localized(key, default: defaultValue, arguments)
  }

  // MARK: - Tabs

  enum Tab {
    static var timer: String { tr("tab.timer", default: "タイマー") }
    static var collection: String { tr("tab.collection", default: "図鑑") }
    static var aquarium: String { tr("tab.aquarium", default: "水槽") }
    static var profile: String { tr("tab.profile", default: "プロフィール") }
  }

  // MARK: - Common

  enum Common {
    static var ok: String { tr("common.ok", default: "OK") }
    static var cancel: String { tr("common.cancel", default: "キャンセル") }
    static var save: String { tr("common.save", default: "保存") }
    static var close: String { tr("common.close", default: "閉じる") }
    static var back: String { tr("common.back", default: "戻る") }
    static var done: String { tr("common.done", default: "完了") }
    static var reset: String { tr("common.reset", default: "リセット") }
    static var name: String { tr("common.name", default: "名前") }
    static var saveError: String { tr("common.save_error", default: "保存エラー") }
    static var preparing: String { tr("common.preparing", default: "準備中") }
  }

  // MARK: - Timer

  enum Timer {
    static var swipeToSet: String { tr("timer.swipe_to_set", default: "スワイプで時間を設定") }
    static var minutesUnit: String { tr("timer.minutes_unit", default: "分") }
    static var depart: String { tr("timer.depart", default: "いってきます") }
    static var cancel: String { tr("timer.cancel", default: "キャンセル") }
    static var start: String { tr("timer.start", default: "スタート") }
    static var saveFailed: String { tr("timer.save_failed", default: "記録の保存に失敗しました") }
    static var cancelConfirmTitle: String { tr("timer.cancel_confirm_title", default: "タイマーをやめますか？") }
    static var cancelConfirmSubtitle: String { tr("timer.cancel_confirm_subtitle", default: "戻ると水が残ります") }
    static var cancelGoBack: String { tr("timer.cancel_go_back", default: "戻る") }
    static var cancelStop: String { tr("timer.cancel_stop", default: "やめる") }
    static var departureConfirmTitle: String { tr("timer.departure_confirm_title", default: "出発しますか？") }
    static var aquariumGrows: String { tr("timer.aquarium_grows", default: "水槽が成長します") }
    static var onTime: String { tr("timer.on_time", default: "オンタイム") }
    static var late: String { tr("timer.late", default: "遅刻") }
    static var dewDropPlus: String { tr("timer.dew_drop_plus", default: "しずく +1") }
    static var noDewDrop: String { tr("timer.no_dew_drop", default: "しずくなし") }
    static var feedPlus: String { tr("timer.feed_plus", default: "餌 +1") }
    static var resultOnTime: String { tr("timer.result_on_time", default: "いってきます！") }
    static var resultLate: String { tr("timer.result_late", default: "遅刻してしまいました") }
    static var onTimeDeparture: String { tr("timer.on_time_departure", default: "オンタイム出発") }
    static var tryOnTimeNext: String { tr("timer.try_on_time_next", default: "次回は時間内に出発しましょう") }
    static var feedForAquarium: String { tr("timer.feed_for_aquarium", default: "水槽タブで使えます") }
    static var resume: String { tr("timer.resume", default: "再開") }
    static var statusDeparted: String { tr("timer.status_departed", default: "出発完了") }
    static var statusCancelled: String { tr("timer.status_cancelled", default: "キャンセル") }
    static var lateNoReward: String { tr("timer.late_no_reward", default: "遅刻中です。しずくは獲得できません") }
    static var cancelA11yBack: String { tr("timer.cancel_a11y_back", default: "タイマーに戻る") }
    static var cancelA11yStop: String { tr("timer.cancel_a11y_stop", default: "タイマーをやめる") }
    static var confirmDepartureA11y: String { tr("timer.confirm_departure_a11y", default: "出発を確定") }
    static var resumeA11y: String { tr("timer.resume_a11y", default: "タイマーを再開") }
    static var rewardDewA11y: String { tr("timer.reward_dew_a11y", default: "しずくを獲得しました") }
    static var rewardDewFeedA11y: String { tr("timer.reward_dew_feed_a11y", default: "しずくと餌を獲得しました") }
    static var startA11yHint: String { tr("timer.start_a11y_hint", default: "タップしてスタート") }

    static func minutes(_ count: Int) -> String { "\(count)\(minutesUnit)" }
    static func minutesLate(_ text: String) -> String { tr("timer.minutes_late", default: "%@遅れ", text) }
    static func statusRemaining(_ text: String) -> String { tr("timer.status_remaining", default: "残り %@", text) }
    static func statusOverdue(_ text: String) -> String { tr("timer.status_overdue", default: "遅刻 %@", text) }
    static func onTimeRewardHint(includesFeed: Bool) -> String {
      let suffix = includesFeed ? tr("timer.and_feed", default: "と餌") : ""
      return tr("timer.on_time_reward_hint", default: "時間内の出発で、しずく%@を獲得できます", suffix)
    }
  }

  // MARK: - Settings

  enum Settings {
    static var title: String { tr("settings.title", default: "設定") }
    static var language: String { tr("settings.language", default: "言語") }
    static var languageFooter: String { tr("settings.language.footer", default: "アプリの表示言語を変更します。") }
    static var account: String { tr("settings.account", default: "アカウント") }
    static var accountLocalOnly: String { tr("settings.account.local_only", default: "ローカルのみ") }
    static var accountCloudEnabled: String { tr("settings.account.cloud_enabled", default: "クラウド保存: 有効") }
    static var accountAnonymousBanner: String { tr("settings.account.anonymous_banner", default: "データはこの端末にのみ保存されています。アカウント登録でクラウド保存とプロフィール編集が使えます。") }
    static var accountRegister: String { tr("settings.account.register", default: "アカウント登録する") }
    static var notificationsAndHaptics: String { tr("settings.notifications_and_haptics", default: "通知と触覚") }
    static var notificationsCaption: String { tr("settings.notifications.caption", default: "出発時刻のお知らせと操作時の振動") }
    static var notificationsSettings: String { tr("settings.notifications.settings", default: "通知と触覚の設定") }
    static var notificationsDeniedIOS: String { tr("settings.notifications.denied_ios", default: "iOSで通知が拒否されています") }
    static var notificationOn: String { tr("settings.notification.on", default: "通知 ON") }
    static var notificationOff: String { tr("settings.notification.off", default: "通知 OFF") }
    static var hapticsOn: String { tr("settings.haptics.on", default: "触覚 ON") }
    static var hapticsOff: String { tr("settings.haptics.off", default: "触覚 OFF") }
    static var departureOnly: String { tr("settings.departure_only", default: "出発時刻のみ") }
    static var display: String { tr("settings.display", default: "表示") }
    static var displayCaption: String { tr("settings.display.caption", default: "アプリ全体と水槽の見た目") }
    static var appearanceMode: String { tr("settings.appearance_mode", default: "外観モード") }
    static var themeFooterSystem: String { tr("settings.theme.footer.system", default: "ライトモードとダークモードは端末の外観設定に合わせて切り替わります。") }
    static var themeFooterLight: String { tr("settings.theme.footer.light", default: "常にライトモードで表示します。") }
    static var themeFooterDark: String { tr("settings.theme.footer.dark", default: "常にダークモードで表示します。") }
    static var aquariumTheme: String { tr("settings.aquarium_theme", default: "水槽テーマ") }
    static var aquariumThemeFooter: String { tr("settings.aquarium_theme.footer", default: "タイマーの水タンクと水槽画面の色合いが変わります。") }
    static var help: String { tr("settings.help", default: "ヘルプ") }
    static var tutorialReplay: String { tr("settings.tutorial.replay", default: "チュートリアルをもう一度見る") }
    static var tutorialReplaySubtitle: String { tr("settings.tutorial.replay_subtitle", default: "タイマー・しずくと餌・水槽・図鑑・実績の使い方を確認できます") }
    static var other: String { tr("settings.other", default: "その他") }
    static var dataManagement: String { tr("settings.data_management", default: "データ管理") }
    static var dataManagementSubtitle: String { tr("settings.data_management.subtitle", default: "保存状態の確認やデータの初期化") }
    static var supportDeveloper: String { tr("settings.support_developer", default: "開発者を応援") }
    static var supportDeveloperSubtitle: String { tr("settings.support_developer.subtitle", default: "アプリの開発をサポートする") }

    static func languageName(_ language: AppLanguage) -> String {
      switch language {
      case .system: return tr("settings.language.system", default: "システム")
      case .ja: return tr("settings.language.ja", default: "日本語")
      case .en: return tr("settings.language.en", default: "English")
      }
    }

    static func reminderBefore(_ minutes: Int) -> String {
      tr("settings.reminder_before", default: "%lld分前にリマインド", minutes)
    }

    static func version(_ text: String) -> String {
      tr("settings.version", default: "バージョン %@", text)
    }
  }

  // MARK: - Notification Settings

  enum NotificationSettings {
    static var title: String { tr("notification_settings.title", default: "通知と触覚") }
    static var sectionTitle: String { tr("notification_settings.section", default: "通知") }
    static var sectionCaption: String { tr("notification_settings.section.caption", default: "タイマー開始時に出発通知を予約します") }
    static var enable: String { tr("notification_settings.enable", default: "通知を使う") }
    static var enableSubtitle: String { tr("notification_settings.enable.subtitle", default: "オフにすると出発通知を送りません") }
    static var reminder: String { tr("notification_settings.reminder", default: "出発前にリマインド") }
    static var reminderSubtitle: String { tr("notification_settings.reminder.subtitle", default: "出発時刻の前にもう一度お知らせします") }
    static var reminderTiming: String { tr("notification_settings.reminder.timing", default: "リマインドのタイミング") }
    static var checkPermission: String { tr("notification_settings.check_permission", default: "通知許可を確認") }
    static var hapticsSection: String { tr("notification_settings.haptics.section", default: "触覚（ハプティクス）") }
    static var hapticsCaption: String { tr("notification_settings.haptics.caption", default: "タスク切り替えや操作時の振動フィードバック") }
    static var hapticsEnable: String { tr("notification_settings.haptics.enable", default: "ハプティクスを使う") }
    static var bannerAuthorized: String { tr("notification_settings.banner.authorized", default: "通知が許可されています") }
    static var bannerDenied: String { tr("notification_settings.banner.denied", default: "通知が許可されていません") }
    static var bannerNotDetermined: String { tr("notification_settings.banner.not_determined", default: "通知の許可が必要です") }
    static var bannerUnknown: String { tr("notification_settings.banner.unknown", default: "通知状態を確認できません") }
    static var bannerAuthorizedSubtitle: String { tr("notification_settings.banner.authorized.subtitle", default: "出発時刻の通知を予約できます。") }
    static var bannerDeniedSubtitle: String { tr("notification_settings.banner.denied.subtitle", default: "iOSの設定アプリから通知を許可してください。") }
    static var bannerNotDeterminedSubtitle: String { tr("notification_settings.banner.not_determined.subtitle", default: "下のボタンから通知の許可をリクエストできます。") }
    static var bannerUnknownSubtitle: String { tr("notification_settings.banner.unknown.subtitle", default: "もう一度お試しください。") }

    static func minutesBefore(_ minutes: Int) -> String {
      tr("notification_settings.minutes_before", default: "%lld分前", minutes)
    }
  }

  // MARK: - Push Notifications

  enum PushNotification {
    static var departureTitle: String { tr("push.departure.title", default: "出発時刻です！") }
    static var departureBody: String { tr("push.departure.body", default: "出発時刻になりました") }

    static func reminderTitle(_ minutes: Int) -> String {
      tr("push.reminder.title", default: "あと%lld分！", minutes)
    }

    static func reminderBody(_ minutes: Int) -> String {
      tr("push.reminder.body", default: "出発まであと%lld分です", minutes)
    }
  }

  // MARK: - Data Management

  enum DataManagement {
    static var title: String { tr("data_management.title", default: "データ管理") }
    static var saveStatus: String { tr("data_management.save_status", default: "保存状態") }
    static var saveStatusCaption: String { tr("data_management.save_status.caption", default: "水槽・図鑑・出発記録は端末内に保存されます") }
    static var loading: String { tr("data_management.loading", default: "データを読み込み中...") }
    static var saving: String { tr("data_management.saving", default: "データを保存中...") }
    static var savedLocally: String { tr("data_management.saved_locally", default: "ローカルに保存されています") }
    static var partialReset: String { tr("data_management.partial_reset", default: "部分的に初期化") }
    static var partialResetCaption: String { tr("data_management.partial_reset.caption", default: "必要なデータだけを選んで削除できます") }
    static var resetAquarium: String { tr("data_management.reset_aquarium", default: "水槽データを初期化") }
    static var resetAquariumSubtitle: String { tr("data_management.reset_aquarium.subtitle", default: "魚・図鑑・出発記録・水槽を削除します") }
    static var dangerousOps: String { tr("data_management.dangerous_ops", default: "危険な操作") }
    static var dangerousOpsCaption: String { tr("data_management.dangerous_ops.caption", default: "削除したデータは元に戻せません") }
    static var resetAll: String { tr("data_management.reset_all", default: "すべてのデータを初期化") }
    static var resetAllSubtitle: String { tr("data_management.reset_all.subtitle", default: "アプリのすべてのデータが削除されます") }
    static var resetAquariumConfirm: String { tr("data_management.reset_aquarium.confirm", default: "水槽データを初期化") }
    static var resetAquariumMessage: String { tr("data_management.reset_aquarium.message", default: "図鑑・出発記録・水槽がすべて削除されます。旧データが残っている場合はここで初期化してください。") }
    static var resetAllConfirm: String { tr("data_management.reset_all.confirm", default: "すべてのデータを初期化") }
    static var resetAllMessage: String { tr("data_management.reset_all.message", default: "魚・記録など、アプリのすべてのデータが削除されます。") }
    static var resetButton: String { tr("data_management.reset_button", default: "初期化する") }
    static var resetAllButton: String { tr("data_management.reset_all_button", default: "すべて初期化する") }
  }

  // MARK: - Account Registration

  enum Account {
    static var cloudSetupTitle: String { tr("account.cloud_setup_title", default: "クラウド保存の設定") }
    static var cloudHeaderTitle: String { tr("account.cloud_header_title", default: "大切なデータをクラウドへ") }
    static var cloudHeaderMessage: String { tr("account.cloud_header_message", default: "アカウントを連携すると、毎朝の水やりデータや水槽・図鑑の記録を安全に保存し、機種変更時にも引き継ぐことができます。") }
    static var appleLink: String { tr("account.apple_link", default: "Apple IDで連携") }
    static var recommended: String { tr("account.recommended", default: "推奨") }
    static var appleLinkDetail: String { tr("account.apple_link_detail", default: "パスワード不要。最も安全で、1タップで瞬時にクラウド同期を開始できます。") }
    static var appleSignInFailed: String { tr("account.apple_sign_in_failed", default: "Appleサインインに失敗しました。設定やネットワーク状況を確認してください。") }
    static var orSeparator: String { tr("account.or_separator", default: "または") }
    static var useEmail: String { tr("account.use_email", default: "メールアドレスを使用する") }
    static var email: String { tr("account.email", default: "メールアドレス") }
    static var password: String { tr("account.password", default: "パスワード (6文字以上)") }
    static var passwordConfirm: String { tr("account.password_confirm", default: "パスワードの確認") }
    static var signUpTab: String { tr("account.sign_up_tab", default: "新規作成") }
    static var signInTab: String { tr("account.sign_in_tab", default: "ログイン") }
    static var signUpButton: String { tr("account.sign_up_button", default: "登録してクラウド保存を開始") }
    static var signInButton: String { tr("account.sign_in_button", default: "ログインしてクラウド保存を開始") }
    static var linkComplete: String { tr("account.link_complete", default: "連携完了") }
    static var linkCompleteApple: String { tr("account.link_complete_apple", default: "Apple IDとの連携が完了しました！これで大事な育成データを安全にバックアップ・同期できます。") }
    static var accountCreated: String { tr("account.created", default: "アカウント作成完了") }
    static var accountCreatedMessage: String { tr("account.created_message", default: "メールアドレスでのアカウント登録が完了しました！これで大事な育成データを安全に同期できます。") }
    static var loginComplete: String { tr("account.login_complete", default: "ログイン完了") }
    static var loginCompleteMessage: String { tr("account.login_complete_message", default: "ログインに成功し、クラウドのデータ同期が有効になりました。") }
    static var title: String { tr("account.title", default: "アカウント") }
    static var profileLocked: String { tr("account.profile_locked", default: "プロフィール編集が制限されています") }
    static var profileLockedDetail: String { tr("account.profile_locked_detail", default: "ニックネームとアバターを変更するには、クラウド保存の有効化（アカウント登録）が必要です。") }
    static var registerToEdit: String { tr("account.register_to_edit", default: "アカウント登録して編集する") }
    static var nickname: String { tr("account.nickname", default: "ニックネーム") }
    static var nicknamePlaceholder: String { tr("account.nickname_placeholder", default: "例: みずやり名人") }
    static var avatar: String { tr("account.avatar", default: "アバター") }
    static var avatarCaption: String { tr("account.avatar_caption", default: "水槽やプロフィールで表示されるアイコン") }
    static var accountLinked: String { tr("account.linked", default: "アカウント連携済み") }
    static var signOut: String { tr("account.sign_out", default: "サインアウト") }
    static var signOutTitle: String { tr("account.sign_out_title", default: "サインアウト") }
    static var signOutMessage: String { tr("account.sign_out_message", default: "サインアウトするとクラウドとのデータ同期が停止します。よろしいですか？（サインアウト後は新しい匿名アカウントが作成され、引き続きアプリをご利用いただけます）") }
  }

  // MARK: - Support Developer

  enum Support {
    static var navTitle: String { tr("support.nav_title", default: "開発者応援") }
    static var header: String { tr("support.header", default: "開発者を応援する") }
    static var description: String { tr("support.description", default: "DewTimeは個人で開発・運営を行っています。もしこのアプリを気に入っていただけましたら、開発をサポートしていただけると大変励みになります。いただいた応援金は、アプリのサーバー維持費や、今後の新機能開発の活動費（コーヒー代やピザ代など）として大切に活用させていただきます。") }
    static var loading: String { tr("support.loading", default: "読み込み中...") }
    static var loadFailed: String { tr("support.load_failed", default: "応援プランを読み込めませんでした。") }
    static var reload: String { tr("support.reload", default: "再読み込み") }
    static var processing: String { tr("support.processing", default: "決済処理中...") }
    static var thankYou: String { tr("support.thank_you", default: "ありがとうございます！") }
    static var errorTitle: String { tr("support.error_title", default: "エラー") }
    static var confirm: String { tr("support.confirm", default: "確認") }
    static var disclaimerTitle: String { tr("support.disclaimer_title", default: "注意事項") }
    static var disclaimer: String { tr("support.disclaimer", default: "・本機能は開発者への「寄付・チップ」としての応援機能であり、アプリ内の追加機能がアンロックされるものではありません。\n・お支払いにはApp Storeに登録された決済方法が適用されます。\n・一度購入された応援のキャンセルや返金はいたしかねますのでご了承ください。") }

    static func purchaseThanks(_ name: String) -> String {
      tr("support.purchase_thanks", default: "「%@」での応援、ありがとうございます！温かいお気持ちに感謝いたします。", name)
    }
  }

  // MARK: - Store

  enum Store {
    static var loadProductsFailed: String { tr("store.load_products_failed", default: "商品の情報を取得できませんでした。") }
    static var purchasePending: String { tr("store.purchase_pending", default: "購入処理が保留中です。承認されるまでお待ちください。") }
    static var purchaseFailed: String { tr("store.purchase_failed", default: "購入処理中にエラーが発生しました。") }
  }

  // MARK: - Auth

  enum Auth {
    static func anonymousSignInFailed(_ detail: String) -> String {
      tr("auth.anonymous_sign_in_failed", default: "匿名ログインに失敗しました: %@", detail)
    }

    static func signUpFailed(_ detail: String) -> String {
      tr("auth.sign_up_failed", default: "アカウント登録に失敗しました: %@", detail)
    }

    static func signInFailed(_ detail: String) -> String {
      tr("auth.sign_in_failed", default: "ログインに失敗しました: %@", detail)
    }

    static func appleSignInFailed(_ detail: String) -> String {
      tr("auth.apple_sign_in_failed", default: "Appleサインインに失敗しました: %@", detail)
    }

    static func signOutFailed(_ detail: String) -> String {
      tr("auth.sign_out_failed", default: "サインアウトに失敗しました: %@", detail)
    }
  }

  // MARK: - Cloud

  enum Cloud {
    static var unauthenticated: String { tr("cloud.unauthenticated", default: "ログイン状態を確認できませんでした") }
  }

  // MARK: - Tutorial

  enum Tutorial {
    static var skip: String { tr("tutorial.skip", default: "スキップ") }
    static var skipHint: String { tr("tutorial.skip_hint", default: "チュートリアルを閉じます") }
    static var start: String { tr("tutorial.start", default: "はじめる") }
    static var next: String { tr("tutorial.next", default: "次へ") }

    static func pageOf(current: Int, total: Int) -> String {
      tr("tutorial.page_of", default: "%lldページ中%lldページ", total, current)
    }

    static func stepTitle(_ step: TutorialStepKind) -> String {
      switch step {
      case .timerWater: return tr("tutorial.step.timer_water.title", default: "水で時間がわかる")
      case .timerDepart: return tr("tutorial.step.timer_depart.title", default: "出発で水槽へ届ける")
      case .rewards: return tr("tutorial.step.rewards.title", default: "しずくと餌")
      case .aquariumGacha: return tr("tutorial.step.aquarium_gacha.title", default: "餌で仲間を増やす")
      case .collection: return tr("tutorial.step.collection.title", default: "図鑑を埋めよう")
      case .profileRecords: return tr("tutorial.step.profile_records.title", default: "記録と実績")
      }
    }

    static func stepMessage(_ step: TutorialStepKind) -> String {
      switch step {
      case .timerWater: return tr("tutorial.step.timer_water.message", default: "タンクをスワイプして出発までの時間を設定します。水が多いほど余裕があり、準備が順調なほど水が残ります。")
      case .timerDepart: return tr("tutorial.step.timer_depart.message", default: "「スタート」で準備を始めます。時間内に「いってきます」を押すと、残った水を水槽へ届けられます。")
      case .rewards: return tr("tutorial.step.rewards.message", default: "オンタイム出発で「しずく +1」と「餌 +1」を獲得できます。しずくは水槽の成長に、餌は水槽タブで魚を呼び寄せるのに使います。遅刻すると報酬はありません。")
      case .aquariumGacha: return tr("tutorial.step.aquarium_gacha.message", default: "水槽をタップして餌を落としましょう。魚が食べたタイミングで新しい仲間が誕生し、図鑑に登録されます。")
      case .collection: return tr("tutorial.step.collection.message", default: "獲得した魚種は図鑑に記録されます。まだ出会っていない魚はシルエットで表示されます。水槽レベルが上がると、より珍しい魚が出現します。")
      case .profileRecords: return tr("tutorial.step.profile_records.message", default: "出発記録をカレンダーで確認できます。実績を達成すると餌がもらえます。通知の変更は右上の歯車から行えます。")
      }
    }
  }

  // MARK: - Calendar

  enum Calendar {
    static var prevMonth: String { tr("calendar.prev_month", default: "前の月") }
    static var nextMonth: String { tr("calendar.next_month", default: "次の月") }
    static var backToThisMonth: String { tr("calendar.back_to_this_month", default: "タップで今月に戻ります") }
    static var weekdays: String { tr("calendar.weekdays", default: "曜日") }
    static var noRecord: String { tr("calendar.no_record", default: "未記録") }
    static var dewDrop: String { tr("calendar.dew_drop", default: "しずく+1") }
    static var late: String { tr("calendar.late", default: "遅延") }
    static var feedBonus: String { tr("calendar.feed_bonus", default: "、餌") }

    static func dayAccessibility(_ dateText: String, status: String) -> String {
      tr("calendar.day_accessibility", default: "%@、%@", dateText, status)
    }

    static func recordCount(_ dateText: String, count: Int, status: String) -> String {
      tr("calendar.record_count", default: "%@、記録%lld件、%@", dateText, count, status)
    }
  }

  // MARK: - Launch

  enum Launch {
    static var loadingAccessibility: String { tr("launch.loading_accessibility", default: "起動準備中。水がたまっています") }

    static func loadingValue(_ percent: Int) -> String {
      tr("launch.loading_value", default: "%lldパーセント", percent)
    }
  }

  // MARK: - Widget

  enum Widget {
    static var quickTimer: String { tr("widget.quick_timer", default: "クイックタイマー") }
    static var departureTimer: String { tr("widget.departure_timer", default: "出発タイマー") }
    static var displayName: String { tr("widget.display_name", default: "DewTime クイックタイマー") }
    static var description: String { tr("widget.description", default: "ホーム画面から出発タイマーをすばやく開始します。") }
    static var previewSpeciesName: String { tr("fish.medaka", default: "メダカ") }
  }

  // MARK: - Collection

  enum Collection {
    static var title: String { tr("collection.title", default: "図鑑") }
    static var noResults: String { tr("collection.no_results", default: "該当する魚がいません") }
    static var undiscovered: String { tr("collection.undiscovered", default: "未発見") }
    static var requiredAquarium: String { tr("collection.required_aquarium", default: "必要水槽") }
    static var difficulty: String { tr("collection.difficulty", default: "難しさ") }
    static var appearsOnFeed: String { tr("collection.appears_on_feed", default: "餌やりで出現") }

    static func filterUnlock(_ filter: UnlockFilterBand) -> String {
      switch filter {
      case .all: return tr("collection.filter.all", default: "すべて")
      case .unlocked: return tr("collection.filter.unlocked", default: "解放済み")
      case .locked: return tr("collection.filter.locked", default: "未解放")
      }
    }

    static func aquariumLevelMin(_ level: Int) -> String {
      tr("collection.aquarium_level_min", default: "水槽Lv.%lld〜", level)
    }

    static func fishCount(_ count: Int) -> String {
      tr("collection.fish_count", default: "%lld匹", count)
    }

    static func fishAcquired(_ count: Int) -> String {
      tr("collection.fish_acquired", default: "%lld匹獲得", count)
    }

    static var filterResetA11y: String { tr("collection.filter.reset_a11y", default: "フィルターをリセット") }
  }

  // MARK: - Aquarium (shared with Live Activity / Widget)

  enum AquariumSize {
    static func name(tier: Int) -> String {
      switch tier {
      case 0: return tr("aquarium.size.mini", default: "ミニ水槽")
      case 1: return tr("aquarium.size.small", default: "小型水槽")
      case 2: return tr("aquarium.size.medium", default: "中型水槽")
      case 3: return tr("aquarium.size.large", default: "大型水槽")
      case 4: return tr("aquarium.size.extra_large", default: "特大水槽")
      case 5: return tr("aquarium.size.aquarium", default: "アクアリウム")
      default: return tr("aquarium.size.mega", default: "大水族館")
      }
    }
  }

  // MARK: - Live Activity

  enum Live {
    static var toAquarium: String { tr("live.to_aquarium", default: "水槽へ") }
    static var pourComplete: String { tr("live.pour_complete", default: "注水完了") }
    static var overdue: String { tr("live.overdue", default: "超過") }
    static var remaining: String { tr("live.remaining", default: "残り") }
    static var departure: String { tr("live.departure", default: "出発") }
    static var pourToAquarium: String { tr("live.pour_to_aquarium", default: "水槽へ注水 ✨") }
    static func nextTask(_ name: String) -> String { tr("live.next_task", default: "次: %@", name) }
  }
}

/// 図鑑の解放フィルタ（ローカライズ非依存の内部キー）。
enum UnlockFilterBand: String, CaseIterable, Identifiable {
  case all
  case unlocked
  case locked

  var id: String { rawValue }

  static var selectableCases: [UnlockFilterBand] { [.unlocked, .locked] }

  var icon: String {
    switch self {
    case .all: return "square.grid.2x2.fill"
    case .unlocked: return "checkmark.seal"
    case .locked: return "lock"
    }
  }

  var displayName: String { L10n.Collection.filterUnlock(self) }
}

/// チュートリアル各ステップの識別子（ローカライズ非依存）。
enum TutorialStepKind: CaseIterable {
  case timerWater
  case timerDepart
  case rewards
  case aquariumGacha
  case collection
  case profileRecords
}
