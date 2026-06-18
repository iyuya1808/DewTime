# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

**DewTime** は iOS 17+ 向けの朝タイマーアプリ。出発時刻までの時間を「水タンク」で可視化し、オンタイム出発でしずく・餌を獲得して水槽を育てる。詳細な UX 仕様は `SPEC.md`・`wireframe.html` を参照。`wireframe.html` には旧「出発スケジュール」「ルーティン編集」「StartSheet」の画面が残っているが**実装からは削除済み**。仕様書と実装が食い違う場合はコードを正とする。

## ビルド・実行

```bash
# ビルド（シミュレーター起動不要）
xcodebuild -project DewTime.xcodeproj -scheme DewTime -destination 'generic/platform=iOS Simulator' build

# テスト（実行時は具体デバイス名が必要。例: iPhone 17 Pro）
xcodebuild test -project DewTime.xcodeproj -scheme DewTime -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# 単一テスト
xcodebuild test -project DewTime.xcodeproj -scheme DewTime -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:DewTimeTests/DewTimeTests
```

LSP は `buildServer.json`（xcode-build-server）が提供。ローカル絶対パスを含むため `.gitignore` 済み。

## アーキテクチャ

### 永続化：`AppDataStore`（SwiftData ではない）

`Support/AppDataStore.swift` の `@Observable @MainActor final class AppDataStore` が唯一の真実。

- `DewTimeApp` が `@State` で生成し `.environment(dataStore)` で全画面注入、起動時に `dataStore.load()`。
- 全データはメモリ上の配列（`activeFishes`, `collectedFishes`, `careRecords`, `aquariums`, `profiles`）。`@Model` は一切使わない。
- 変更操作は必ず最後に `saveAll()` を呼ぶ。Supabase への保存は差分でなく**全置換**。
- クラウド ↔ モデル変換は `CloudSnapshot` 系 DTO と `makeCloudSnapshot/applyCloudSnapshot` で行う。**モデルにフィールドを追加したら DTO・SQL・変換・ローカル encode/decode の4箇所を更新する。**
- Supabase マイグレーション: `supabase/migrations/202606040001_create_cloud_data_tables.sql` を Supabase 側で実行済みが前提。`user_schedules` / `routine_items` は `202606210001_drop_schedule_tables.sql` で削除済み。全テーブルに `user_id = auth.uid()` の RLS あり。

### 画面構成

```
ContentView（TabView: timer / collection / aquarium / profile）
├── TimerView — WaterTankView（スワイプで時間設定）、DepartureResultView
├── CollectionView（Views/Garden/）— 図鑑、FishDetailSheet
├── LiveAquariumView（Views/Garden/）— 育成中の魚が泳ぐライブシーン
└── ProfileView（Views/Settings/）— プロフィール・設定（SettingsView）
```

> `Views/Garden/` というディレクトリ名は旧「ガーデン」由来で、魚・水槽系ビューが入っている。

### TimerViewModel

`AppDataStore` を保持せず、`depart(store:)` などメソッド引数で受け取り委譲する。出発時刻はセッション内の `targetDepartureTime` で管理（設定画面での事前登録はなし）。タイマー状態は `UserDefaults`（`PKey` enum）に保存してアプリ再起動時に `restoreState()` で復元。`WaterTankView` は `TimelineView` + `Canvas` で60fps描画。

### Live Activity / Widget

- 共有型は `DewTimeLiveActivityShared/`（`DewTimerActivityAttributes`）。アプリと Extension の両ターゲットでコンパイルされる。
- 操作は `Support/DewTimerLiveActivityController.swift` の `start/update/end/finishWithPour` 経由。
- `DewTimeQuickStartWidget` がウィジェットで `dewtime://start-timer?minutes=N` を発行 → `QuickTimerDeepLinkRouter` が受信して `TimerView` が自動スタート。

### その他の `Support/` ファイル

| ファイル | 役割 |
|---|---|
| `AppPreferences` | `@AppStorage` ベースの設定（テーマ・通知など） |
| `NotificationScheduler` | スタート時に出発通知・リマインダーをスケジュール |
| `StoreManager` | StoreKit チップ購入（snack/coffee/pizza）。`DewTime.storekit` でローカルテスト可 |
| `ReviewRequestManager` | 30日クールダウン付きレビュー要求。DEBUG はスキップ |
| `AuthService` | 匿名ログイン優先、メール/Apple でアップグレード可 |

### ローカライズ（ja / en）

- 文字列は `DewTimeLiveActivityShared/L10n.swift`（+ `Support/L10nModels.swift` / `L10nGarden.swift`）経由。**ユーザー向け日本語のハードコード禁止。**
- 翻訳リソース: `DewTimeLiveActivityShared/Localizable.xcstrings`（ja + en 必須）
- 言語設定: `LocalizationManager` + 設定画面の言語ピッカー（App Group 共有 → Widget / Live Activity も追従）
- 手順・用語集: `docs/LOCALIZATION.md` / `docs/LOCALIZATION_GLOSSARY.md`
- 新規 UI 追加時は `DewTimeTests/LocalizationGuardTests` が通ること

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
