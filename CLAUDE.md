# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

**DewTime** は iOS 17+ 向けの朝タイマーアプリ。「水やり」メタファーで朝の準備を可視化する。スケジュール通りに出発するほど植物に多くの水が注がれ、コレクションとして記録される。

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

LSP（コード補完・診断）は `buildServer.json` により xcode-build-server が提供している（スキーム: `DewTime`）。

## アーキテクチャ

### 技術スタック

| レイヤー | 使用技術 |
|---|---|
| UI | SwiftUI |
| 状態管理 | `@Observable` + `@Query`（SwiftData） |
| 永続化 | SwiftData（`UserSchedule`, `RoutineItem`, `PlantFlower`, `ActivePlant`, `PlantWateringRecord`） |
| タイマー | `Timer` + `TimelineView`（波アニメーション用） |
| 通知 | UserNotifications（`NotificationScheduler`） |
| 一時状態保持 | `UserDefaults`（タイマー起動状態のアプリ再起動対応） |

### 画面構成

```
ContentView（TabView）
├── TimerView        — メインタイマー、水タンクアニメーション
│   ├── StartSheet              — スタート前の出発時刻確認・変更
│   ├── DepartureConfirmView    — 「いってきます」確認シート
│   ├── DepartureResultView     — 出発後の結果表示シート
│   └── PlantPickerSheet        — 育てる植物の選択（インライン定義）
├── GardenView       — 直近7日の水やり記録グリッド + MonthlyGardenView
├── CollectionView   — 開花した花のコレクション一覧
└── SettingsView     — スケジュール・ルーティン編集、DataManagementView
```

### データモデル（SwiftData）

- **`UserSchedule`** — スケジュール（出発時刻 + RoutineItem 1対多）。`isActive` フラグで現在選択中を管理。`orderedItems` で `orderIndex` 順に取得。
- **`RoutineItem`** — ルーティン項目（名前・秒数・カラーHex・順序）。`schedule` が親。
- **`ActivePlant`** — 育成中の植物1件。`receivedWater` / `requiredTotalWater` で進捗計算。`isCompleted` で完了判定。
- **`PlantFlower`** — 開花した花のコレクション記録（履歴）。
- **`PlantWateringRecord`** — 毎朝の水やりログ。ガーデン画面の基礎データ。

### ViewModel（TimerViewModel）

`@Observable @MainActor` クラス。`UserSchedule` を受け取り、すべてのタイマー状態を保持する。

重要な算出プロパティ:
- `waterLevel` — 0.0〜1.0。タンク残量。`(出発時刻 - 現在時刻) / 総時間`。
- `currentRoutineItem` / `nextRoutineItem` — `elapsedSeconds` からルーティン進行を判定。
- `projectedTotalWater` — 「今の水量で出発した場合に植物が受け取る総水量」の予測値。

状態永続化: アプリ再起動時にタイマー継続のため `UserDefaults` に `scheduleId`, `startedAt`, `departed` 等を保存（`PKey` enum で管理）。

バックグラウンド: `scenePhase` 変化で `pause()` / `resume()` を呼び、バックグラウンド中はTimer停止。

### デザインシステム

- **`AppColors`** — `Color` extensionでブランドカラーを定義（`dewBlue`, `dewNavy`, 水位グラデーション等）。
- **`AppFont`** — `Font` の静的プロパティで全画面共通のフォント定義（`countdown`, `departureTime`, `actionButton` 等）。
- **`WaterLevelTheme`** — 水位（0.0〜1.0）に応じたカラー・グラデーションを返す構造体。0.6以上は青系、0.3〜0.6は黄系、0.3未満はピンク系。
- **`Color+Hex`** — `Color(hex: "#RRGGBB")` イニシャライザ。

### 植物システム

- **`FlowerSpecies`** — 15種類の植物。`requiredTotalWaterRange` でゲーム難易度が変わる（ランダム決定）。
- **`GrowthStage`** — `seed → sprout → leaves → bloom`。進捗率で `stage(for:)` により自動判定（0.25/0.55/1.0がしきい値）。
- `SampleData.seedIfNeeded` — 初回起動時にデフォルトスケジュールとルーティン5件を挿入。

### 水タンクアニメーション

`WaterTankView` は `TimelineView(.animation(minimumInterval: 1/60))` + `Canvas` でサイン波を60fps描画。`isOverdue` が `true` のとき水色から赤系に色が変わる。
