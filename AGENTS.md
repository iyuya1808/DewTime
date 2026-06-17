# AGENTS.md

リポジトリ全般のガイダンスは `CLAUDE.md` を参照（プロジェクト概要・アーキテクチャ・ビルド/テストコマンド）。

## Cursor Cloud specific instructions

- **本リポジトリはネイティブ iOS アプリ（`SDKROOT = iphoneos` / iOS 17.0+）で、ビルド・実行・テストには macOS + Xcode が必須。** Cursor Cloud Agent の VM は Linux (x86_64) のため、ここではビルド/シミュレータ実行ができない。`xcodebuild` / `xcrun` / `simctl` / iOS Simulator は macOS でしか動かない。
- 50 個中 34 個の Swift ファイルが SwiftUI / UIKit / ActivityKit / StoreKit / WidgetKit / CoreMotion / CoreHaptics / UserNotifications / AuthenticationServices など Apple 専用フレームワークに依存しており、Linux 上の Swift ツールチェインでもコンパイルできない。`Package.swift` は無く、依存（`supabase-swift`）は Xcode が SPM 経由で解決する。
- 実際のビルド/テスト/実行コマンドは `CLAUDE.md` の「ビルド・実行」節を参照（`xcodebuild ... -scheme DewTime -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`）。これらは macOS 上でのみ実行可能。
- Linux クラウド VM では、コード閲覧・編集・静的レビュー・Supabase マイグレーション SQL（`supabase/migrations/`）の確認までが現実的な作業範囲。ビルド検証が必要な変更は macOS 環境で行うこと。
- バックエンドは Supabase（`DewTime/Support/SupabaseManager.swift` に publishable key 埋め込み）。全テーブルに `user_id = auth.uid()` の RLS あり。
