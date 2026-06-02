# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

**DewTime** は iOS 17+ 向けの朝タイマーアプリ。「水やり／水槽育成」メタファーで朝の準備を可視化する。出発時刻までに使える「水」が満タンのタンクに入っており、スケジュール通りに準備するほど水が温存される。「いってきます」を押すと残った水が水槽に注がれ、魚が成長し（卵→稚魚→幼魚→成魚）、成魚になると図鑑に登録される。水槽は累積水量で大きくなり、大きいほど大型の魚を飼える。

> 詳細な企画・UX 仕様は `SPEC.md`、画面イメージは `wireframe.html` を参照。ただし `SPEC.md` は永続化を「SwiftData」と記載しているが**実装は Firebase Firestore に移行済み**。仕様書と実装が食い違う場合はコードを正とする。

## ビルド・実行

Xcode から直接ビルドする。CLIでのビルドは xcodebuild を使用。

```bash
# ビルド（シミュレーター）
xcodebuild -project DewTime.xcodeproj -scheme DewTime -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build

# テスト実行
xcodebuild test -project DewTime.xcodeproj -scheme DewTime -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# 単一テストファイル
xcodebuild test -project DewTime.xcodeproj -scheme DewTime -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:DewTimeTests/DewTimeTests
```

LSP（コード補完・診断）は `buildServer.json` により xcode-build-server が提供している（スキーム: `DewTime`）。`buildServer.json` はローカル絶対パスを含むため `.gitignore` 済み。

### Firebase の前提

依存は Swift Package Manager で導入（`firebase-ios-sdk`: `FirebaseAuth` / `FirebaseCore` / `FirebaseFirestore`）。

- 実行には DewTime ターゲットに **`GoogleService-Info.plist`** が必要（リポジトリには含まれない）。
- `AppDelegate` は plist が存在するときだけ `FirebaseApp.configure()` を呼ぶ。**plist が無くてもビルド・起動は可能**で、その場合 `AppDataStore` は Firestore 読み込みに失敗し、ローカルでサンプルスケジュールを seed する（グレースフルデグレード）。
- 認証は**匿名認証**。`users/{uid}` 配下のサブコレクションにデータを保存する。

## アーキテクチャ

### 状態管理・永続化の中核：`AppDataStore`

このアプリは **SwiftData を使っていない**（過去は使用していたが Firestore に移行済み）。永続化の中心は `Support/AppDataStore.swift` の `@Observable @MainActor final class AppDataStore`。

- `DewTimeApp` が `@State private var dataStore = AppDataStore()` を生成し、`.environment(dataStore)` で全画面へ注入。起動時 `.task` で `dataStore.load()`。
- **全データはメモリ上の配列**（`schedules`, `activeFishes`, `collectedFishes`, `careRecords`, `aquariums`）として保持される。モデルは素の `@Observable` クラス（`@Model` ではない、リレーションは手動で配列管理）。
- 変更を加える操作（`addSchedule`, `recordDeparture`, `selectSpecies` 等）は最後に `saveAll()` を呼び、**コレクション全体を Firestore へ「全消し→再書き込み」**する（`replaceCollection` がバッチで delete 後 setData）。差分更新ではない点に注意。
- Firestore ↔ モデルの変換は手書きの `encode(...)` / `decode...(...)` と型ゆるい value helper（`string/bool/int/double/date/optionalDate`、`Timestamp` 対応）で行う。`@Model` の自動永続化に頼れないため、**モデルにフィールドを追加したら encode/decode の両方を更新**する必要がある。
- seed: `seedSampleSchedules()`（「平日通常モード」+ ルーティン5件）。Firestore が空、または読み込み失敗時に投入。

### 画面構成（タブ）

`ContentView` は `AppTab` enum（`timer` / `collection` / `aquarium` / `profile`）で `TabView` を構成。

```
ContentView（TabView）
├── TimerView        — メインタイマー、水タンクアニメーション（WaterTankView）
│   ├── StartSheet              — スタート前の出発時刻確認・変更
│   ├── DepartureConfirmView    — 「いってきます」確認シート
│   └── DepartureResultView     — 出発後の結果表示（成長・図鑑登録）
├── CollectionView   — 図鑑（CollectedFish 一覧）、FishDetailSheet
├── LiveAquariumView — 「水槽」タブ。育成中の魚が泳ぐライブシーン
│                       （関連: AquariumView / MonthlyAquariumView）
└── ProfileView      — スケジュール・ルーティン編集、DataManagementView
```

> 注: 魚・水槽系のビューはディレクトリ名としては `Views/Garden/` に残っている（旧「ガーデン」由来）。

### ViewModel（TimerViewModel）

`@Observable @MainActor` クラス。`UserSchedule` を受け取り、すべてのタイマー状態を保持する。`depart(store:)` / `selectSpecies(_:store:)` のように **`AppDataStore` を引数で受け取って永続化を委譲**する（ViewModel は store を保持しない）。

重要な算出プロパティ:
- `waterLevel` — 0.0〜1.0。タンク残量。`(出発時刻 - 現在時刻) / 総時間`。
- `currentRoutineItem` / `nextRoutineItem` — `elapsedSeconds` からルーティン進行を判定。
- `currentWaterAmount` — `waterLevel * 100`（=この朝注げる水量 pt）。
- `projectedTotalWater` / `projectedGrowthStage` — 「今の水量で出発した場合に魚が受け取る総水量・到達する成長段階」の予測値。`activeFish` の `receivedWater` に加算して算出。

状態永続化（タイマー継続）: `UserDefaults`（`PKey` enum）に `scheduleId`, `startedAt`, `departed`, `finalWaterLevel`, `selectedSpecies` 等を保存。アプリ再起動時に `restoreState()` で復元。

バックグラウンド: `scenePhase` 変化で `pause()` / `resume()` を呼び、バックグラウンド中は `Timer` を停止。`handleScheduleKnocks()` でフェーズ移行・遅延警告のハプティクスを発火。

### データモデル（`Models/`、すべて素の `@Observable` クラス）

- **`UserSchedule`** — スケジュール（出発時刻 + `RoutineItem` を `items` 配列で1対多）。`isActive` で現在選択中を管理。static ヘルパ `active(in:)` / `setActive(_:in:)` / `ensureSingleActive(in:)` で「常に1つだけ active」を保証。`orderedItems` で `orderIndex` 順取得。
- **`RoutineItem`** — ルーティン項目（名前・秒数・カラーHex・順序）。`schedule` が親参照。
- **`ActiveFish`** — 育成中の魚1件。`receivedWater / requiredTotalWater` で `progress`、`growthStage` を算出。`isCompleted` で完了判定。同時に育成中なのは基本1匹（新規作成時に既存を `isCompleted` 化）。
- **`CollectedFish`** — 図鑑に登録された成魚の記録（成魚到達時に追加）。
- **`FishCareRecord`** — 毎朝の出発（水やり）ログ。`growthStage` は `growthStageRawValue` で保持。
- **`Aquarium`** — アプリ内に1レコードのみ。`totalWaterCollected`（累積水量）から `sizeTier`（`tierThresholds` で判定）を算出。大型魚の解放条件に使う。

### ゲームロジック（`FishSpecies` / `GrowthStage`）

- **`FishSpecies`** — 15種（メダカ〜ジンベエザメ）。`requiredTotalWaterRange` で必要総水量をランダム決定（`makeRequiredTotalWater()`）。`requiredAquariumTier` で水槽サイズによる解放を制御（`isUnlocked(aquariumTier:)`）。`emoji` を主表示、`icon`（SF Symbol）はフォールバック。
- **`GrowthStage`** — `egg → fry → juvenile → adult`（卵→稚魚→幼魚→成魚）。`stage(for:)` が進捗率で自動判定（しきい値 0.25 / 0.55 / 1.0）。

### デザインシステム（`Support/`）

- **`AppColors`** — `Color` extension（`dewBlue`, `dewNavy`, 水位グラデーション等）。
- **`AppFont`** — `Font` 静的プロパティで全画面共通フォント（`countdown`, `departureTime`, `actionButton` 等）。
- **`WaterLevelTheme`** — 水位（0.0〜1.0）に応じたカラー・グラデーションを返す。0.6以上は青系、0.3〜0.6は黄系、0.3未満はピンク系。
- **`Color+Hex`** — `Color(hex: "#RRGGBB")` イニシャライザ。`RoutineItem.colorHex` 等に使用。

### 水タンクアニメーション

`WaterTankView` は `TimelineView(.animation(minimumInterval: 1/60))` + `Canvas` でサイン波を60fps描画。`isOverdue` が `true` のとき水色から赤系に変色。
</content>
</invoke>
