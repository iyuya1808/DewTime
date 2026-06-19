# DewTime

iOS 17+ 向けの朝タイマーアプリ。出発時刻までの時間を「水タンク」で可視化し、オンタイムで出発するとしずく（Dew Drop）と餌を獲得して水槽を育てる。

## コンセプト

朝の準備中、タンクの水は時間とともに減っていく（遅刻するとさらに溢れる）。「いってきます！」でセッション終了。

| 結果 | 報酬 |
|---|---|
| オンタイム出発 | しずく +1、餌 +1 |
| 遅刻出発 | 報酬なし |

- **しずく** — 累積で水槽レベルが上がる（7段階）。高レベルほどガチャで大型魚が出やすい。
- **餌** — 水槽タブで水面タップして消費 → 魚ガチャ → 図鑑・水槽に追加。
- タイマー中の水位はあくまで時間の可視化で、報酬量には影響しない（オンタイムかどうかのみが報酬条件）。

アプリの機能紹介は [SPEC.md](SPEC.md) を参照。

## 画面構成

```
ContentView（TabView）
├── タイマー — TimerView / WaterTankView / DepartureResultView
├── 図鑑    — CollectionView / FishDetailSheet
├── 水槽    — LiveAquariumView（Canvas 60fps）/ 餌ガチャ / 成長・魚一覧シート
└── プロフィール — ProfileView（実績）/ SettingsView（設定・アカウント・通知・言語）
```

## ビルド・実行

ネイティブ iOS アプリ（iOS 17+）のため、macOS + Xcode が必須。

```bash
# ビルド（シミュレーター起動不要）
xcodebuild -project DewTime.xcodeproj -scheme DewTime -destination 'generic/platform=iOS Simulator' build

# テスト（実行時は具体デバイス名が必要。例: iPhone 17 Pro）
xcodebuild test -project DewTime.xcodeproj -scheme DewTime -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# 単一テスト
xcodebuild test -project DewTime.xcodeproj -scheme DewTime -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:DewTimeTests/DewTimeTests
```

## iOS ネイティブ統合

| 機能 | 用途 |
|---|---|
| Live Activity / Dynamic Island | ロック画面・DI で残り水位・魚プレビュー。出発時 `pour` アニメ |
| WidgetKit | クイック起動（15/30/45/60分）→ `dewtime://start-timer?minutes=N` |
| Core Haptics | 遅刻警告・操作確認 |
| UserNotifications | 出発時刻・リマインダー |
| StoreKit | 開発者チップ（Snack / Coffee / Pizza） |
| AuthenticationServices | Apple / メールで匿名アカウントをアップグレード |

## バックエンド

永続化は SwiftData ではなく `AppDataStore`（メモリ上の配列）+ Supabase。クラウド保存は差分でなく全置換。マイグレーションは `supabase/migrations/` を参照。全テーブルに `user_id = auth.uid()` の RLS あり。

## ローカライズ

日本語 / English に対応。文字列は `DewTimeLiveActivityShared/L10n.swift` 経由で管理し、ユーザー向け日本語のハードコードは禁止。詳細は [docs/LOCALIZATION.md](docs/LOCALIZATION.md) / [docs/LOCALIZATION_GLOSSARY.md](docs/LOCALIZATION_GLOSSARY.md) を参照。

## ドキュメント

- [CLAUDE.md](CLAUDE.md) — アーキテクチャ詳細（Claude Code 向け）
- [SPEC.md](SPEC.md) — ユーザー向け機能紹介
- [AGENTS.md](AGENTS.md) — Cursor Cloud 等のクラウド実行環境向け制約事項
