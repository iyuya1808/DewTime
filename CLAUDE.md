# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

**DewTime** は iOS 17+ 向けの朝タイマーアプリ。出発時刻までの時間を「水タンク」で可視化し、出発時に残った水が水槽へ注がれて魚が成長する。詳細な UX 仕様は `SPEC.md`・`wireframe.html` を参照。ただし `SPEC.md` は SwiftData と記載しているが**実装は Supabase Auth + Database に移行済み**。仕様書と実装が食い違う場合はコードを正とする。

## ビルド・実行

```bash
# ビルド
xcodebuild -project DewTime.xcodeproj -scheme DewTime -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build

# テスト
xcodebuild test -project DewTime.xcodeproj -scheme DewTime -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# 単一テスト
xcodebuild test -project DewTime.xcodeproj -scheme DewTime -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:DewTimeTests/DewTimeTests
```

LSP は `buildServer.json`（xcode-build-server）が提供。ローカル絶対パスを含むため `.gitignore` 済み。

## アーキテクチャ

### 永続化：`AppDataStore`（SwiftData ではない）

`Support/AppDataStore.swift` の `@Observable @MainActor final class AppDataStore` が唯一の真実。

- `DewTimeApp` が `@State` で生成し `.environment(dataStore)` で全画面注入、起動時に `dataStore.load()`。
- 全データはメモリ上の配列（`schedules`, `activeFishes`, `collectedFishes`, `careRecords`, `aquariums`, `profiles`）。`@Model` は一切使わない。
- 変更操作は必ず最後に `saveAll()` を呼ぶ。Supabase への保存は差分でなく**全置換**。
- クラウド ↔ モデル変換は `CloudSnapshot` 系 DTO と `makeCloudSnapshot/applyCloudSnapshot` で行う。**モデルにフィールドを追加したら DTO・SQL・変換・ローカル encode/decode の4箇所を更新する。**
- Supabase マイグレーション: `supabase/migrations/202606040001_create_cloud_data_tables.sql` を Supabase 側で実行済みが前提。全テーブルに `user_id = auth.uid()` の RLS あり。

### 画面構成

```
ContentView（TabView: timer / collection / aquarium / profile）
├── TimerView — WaterTankView、StartSheet、DepartureConfirmView、DepartureResultView
├── CollectionView（Views/Garden/）— 図鑑、FishDetailSheet
├── LiveAquariumView（Views/Garden/）— 育成中の魚が泳ぐライブシーン
└── ProfileView（Views/Settings/）— スケジュール・ルーティン編集
```

> `Views/Garden/` というディレクトリ名は旧「ガーデン」由来で、魚・水槽系ビューが入っている。

### TimerViewModel

`AppDataStore` を保持せず、`depart(store:)` などメソッド引数で受け取り委譲する。タイマー状態は `UserDefaults`（`PKey` enum）に保存してアプリ再起動時に `restoreState()` で復元。`WaterTankView` は `TimelineView` + `Canvas` で60fps描画。

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
