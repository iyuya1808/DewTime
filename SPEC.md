# DewTime 仕様書

iOS 17+ 向け朝タイマーアプリ。出発までの時間を「水タンク」で可視化し、オンタイム出発で **しずく（Dew Drop）** と **餌** を獲得。餌で魚を引き、水槽を育てる。

> **実装が正。** `wireframe.html` には削除済みの出発スケジュール画面が残っている。永続化は SwiftData ではなく `AppDataStore` + Supabase。

---

## 1. コアコンセプト

朝の準備中、タンクの水は時間とともに減る（遅刻するとさらに溢れる）。**「いってきます！」** でセッション終了。

| 結果 | 報酬 |
|---|---|
| オンタイム出発 | しずく +1、餌 +1 |
| 遅刻出発 | 報酬なし |

- **しずく** — 累積で水槽レベルが上がる（7 段階）。高レベルほどガチャで大型魚が出やすくなる。
- **餌** — 水槽タブで水面タップして消費 → 魚ガチャ → 図鑑・水槽に追加。
- タイマー中の水位は**時間の可視化**であり、報酬量には影響しない（オンタイムかどうかのみが報酬条件）。

---

## 2. ゲームプレイ

### 2.1 タイマー

- 未スタート時: タンクを上下スワイプで **5〜30 分** を設定（水位 = 時間量）。
- スタート後: 残り時間を MM:SS と水位アニメで表示。遅刻中は `+MM:SS` 表示。
- 出発前に確認シート（`DepartureConfirmView`）。誤タップ時は結果画面から再開可能。
- 出発完了時: 報酬バースト演出 → 結果シート（`DepartureResultView`）。

### 2.2 水槽成長

`Aquarium.totalDepartures`（累積オンタイム出発数）でレベル判定。

| レベル | 必要しずく（累計） | 泳がせられる魚の上限 |
|:---:|:---:|:---:|
| 1 | 0 | 5 |
| 2 | 10 | 10 |
| 3 | 30 | 20 |
| 4 | 60 | 35 |
| 5 | 100 | 50 |
| 6 | 150 | 70 |
| 7 | 200 | 100 |

### 2.3 餌やり・魚ガチャ

1. 餌ストック（`bonusFeedStock`）を消費して水面タップ
2. エサを食べたタイミングで `FishGachaService` が種を抽選（現在レベルで解禁済みの種のみ）
3. 新しい `CollectedFish` が誕生 → `FishGachaResultSheet` で表示
4. 最新の魚が水槽に泳ぐ（上限まで）。種の初入手は図鑑で解放

餌の入手: オンタイム出発、実績解除（`Achievement` → `syncAchievementFeedRewards`）

### 2.4 図鑑・実績

- **図鑑** (`CollectionView`): 15 種の魚。解放/未解放・難易度でフィルタ。種ごとに必要水槽レベルあり。
- **実績** (`ProfileView`): しずく・図鑑・連続出発など。解除時に餌報酬あり。
- **出発記録** (`MonthlyAquariumView`): カレンダーでオンタイム/遅刻を確認。

### 2.5 魚種（15 種）

メダカ・グッピー・エビ・フグ・カニ・カメ・イカ・タコ・ロブスター・クラゲ・アザラシ・イルカ・サメ・クジラ・ジンベエザメ。

小型種は低レベル水槽から、大型種は高レベル水槽で解禁。

---

## 3. 画面構成

```
ContentView（TabView）
├── タイマー — TimerView / WaterTankView / DepartureResultView
├── 図鑑   — CollectionView / FishDetailSheet
├── 水槽   — LiveAquariumView（Canvas 60fps）/ 餌ガチャ / 成長・魚一覧シート
└── プロフィール — ProfileView（実績）/ SettingsView（設定・アカウント・通知・言語）
```

初回起動: `TutorialOverlayView`（タブ連動）。設定から再実行可。

---

## 4. iOS ネイティブ統合

| 機能 | 用途 |
|---|---|
| **Live Activity / Dynamic Island** | ロック画面・DI で残り水位・魚プレビュー。出発時 `pour` アニメ |
| **WidgetKit** | クイック起動（15/30/45/60 分）→ `dewtime://start-timer?minutes=N` |
| **Core Haptics** | 遅刻警告・操作確認 |
| **UserNotifications** | 出発時刻・リマインダー |
| **StoreKit** | 開発者チップ（Snack / Coffee / Pizza） |
| **AuthenticationServices** | Apple / メールで匿名アカウントをアップグレード |

言語は **日本語 / English**。`LocalizationManager` + App Group 共有で Widget / Live Activity も追従。

---

## 5. アーキテクチャ

### 永続化

`AppDataStore`（`@Observable @MainActor`）が単一真実源。メモリ配列 → ローカル JSON + Supabase 全置換同期。

| 配列 | 内容 |
|---|---|
| `activeFishes` | 育成中魚（主に Live Activity プレビュー用。`departures` で進捗） |
| `collectedFishes` | 獲得した魚（図鑑・水槽表示） |
| `careRecords` | 出発ログ（`speciesId = "departure"`） |
| `aquariums` | しずく累計・餌ストック |
| `profiles` | ニックネーム・アバター・実績報酬受取 ID |

タイマー状態は `TimerViewModel` + `UserDefaults`。出発時刻はセッション内管理（事前スケジュール登録なし）。

### 認証・同期

- 初回: 匿名ログイン（`AuthService`）
- 設定からメール / Apple で本登録 → 機種変更時のデータ引き継ぎ
- `CloudDataService`: 起動・復帰時に取得、変更時 `saveAll()` で全置換
- RLS: 全テーブル `user_id = auth.uid()`。PK は `(user_id, id)` 複合キー

### 主要ファイル

| パス | 役割 |
|---|---|
| `Support/AppDataStore.swift` | データ CRUD・同期 |
| `ViewModels/TimerViewModel.swift` | タイマー・出発・Live Activity |
| `Support/FishGachaService.swift` | 餌ガチャ抽選 |
| `DewTimeLiveActivityShared/` | アプリ + Extension 共有型・L10n |
| `supabase/migrations/` | DB スキーマ（しずく移行: `202606170001`） |

---

## 6. UI 設計原則

文字を極限まで減らすのではなく、**水位・色・アイコン・動き・ハプティクス**で状態と操作を伝える。MM:SS などの数字は万国共通で保持。

対象: 未就学児、読字困難、発達障害のある方、外国語話者。全操作に VoiceOver ラベル。

ローカライズ手順: `docs/LOCALIZATION.md` / `docs/LOCALIZATION_GLOSSARY.md`（しずく → Dew Drop 等）

---

## 7. 削除済み機能

- 出発スケジュール・ルーティンタスク（`user_schedules` / `routine_items` テーブル削除済み）
- 水量ベースの魚成長（しずくシステムへ移行、`202606170001_migrate_to_shizuku_system.sql`）
- `StartSheet` / `RoutineEditorView`
