# iOSアプリ開発仕様書：DewTime（デュータイム）
## 〜SwiftUIとiOS最新機能で実現する、水と魚の朝タイマー〜

---

## 1. プロジェクト概要 & プラットフォーム戦略

### 1.1 背景

朝の慌ただしい時間帯において、スマホを凝視したり操作したりする行為自体がストレス（摩擦）になります。本アプリは、iOSのシステム領域である「Lock Screen（ロック画面）」や「Dynamic Island（ダイナミックアイランド）」を活用し、ユーザーがスマホを操作していない状態（バックグラウンド/ロック時）でも、残り時間を直感的に伝えることを目的とします。

さらに本アプリは**ダイバシティ（多様性）への配慮**を設計の中核に置き、文字を読むことが困難なユーザー（未就学児、読字困難、発達障害のある方など）でも直感的に操作できることを目指します。文字を極限まで減らすこと自体が目的ではなく、**水位・色・アイコン・動き・雰囲気・ハプティクスなどの視覚的・感覚的情報を主軸に、文字を読めなくてもアプリの状態と操作が伝わる UI** を採用しています。

**コアコンセプト — 「水槽を育てる報酬」:**
タンクには朝の出発までに使える「水」が満タンで入っています。時間内に準備を進めるほど水は温存され、「いってきます！」ボタンを押した瞬間、タンクに残った水がすべて水槽へと注ぎ込まれます。注いだ水は水槽に蓄積し、水槽がだんだん大きくなっていきます。水槽の中では魚を育てており、注いだ水のぶんだけ魚が成長し（卵 ➔ 稚魚 ➔ 幼魚 ➔ 成魚）、成魚になると図鑑に登録されます。さらに水槽が大きく育つほど、より大きな魚を飼えるようになります。遅れるほど水が無駄に流れ出て、魚が受け取れる水が減るという仕組みです。タイマーはカウントダウンではなく「魚と水槽のための貯水量」として機能し、ユーザーに前向きな動機を与えます。

### 1.2 技術スタック

| カテゴリ | 技術 |
|---|---|
| 対応OS | iOS 17.0 以上 |
| UIフレームワーク | SwiftUI |
| バックグラウンド・システム領域 | ActivityKit (Live Activities / Dynamic Island), WidgetKit |
| データ永続化 | `AppDataStore` によるオンメモリ管理 ➔ ローカルJSON/UserDefaults |
| クラウドデータ同期・認証 | Supabase Auth, Supabase Database (PostgreSQL) |
| 通知 & インタラクション | UserNotifications, Core Haptics（ハプティクスフィードバック） |
| グラフィック・アニメーション | SwiftUI Canvas, Path, TimelineView（液体の波形表現およびライブアクアリウム用） |
| アプリ内課金（収益化） | StoreKit（StoreManagerによる開発者へのチップ購入機能） |
| 品質改善・フィードバック | StoreKit (ReviewRequestManagerによるアプリ内レビュー要求) |

---

## 2. iOSネイティブ統合設計（UX Mapping）

iOSのシステム機能をフル活用し、スマホを開かずに状況を把握・体感できる設計を行います。

### 2.1 Dynamic Island（ダイナミック・アイランド）の表示設計

ActivityKitを使用し、状態に応じて3つの表示パターンを出し分けます。

| 表示タイプ | ターゲット・表示内容 | 視覚表現イメージ |
|---|---|---|
| Compact Left（左小窓） | 残り時間・水滴アイコン | 💧マーク または残り時間表示 |
| Compact Right（右小窓） | 魚の簡易ステータス | 🐟（順調）/ ⚠️（遅延）/ ✨（成魚） |
| Minimal（別アプリ同時使用時） | 残り水量メーター | 💧 72% などの残水表示（多いほど魚が喜ぶ） |
| Expanded（長押し展開時） | 水位と魚が直結したミニタイマー | タンク（水色）➔ 水滴ポタポタ ➔ 水槽の一体型ビュー。出発時に水が水槽へ流れ込むアニメーションも表示。 |

### 2.2 Live Activities（ライブアクティビティ／ロック画面）

ロック画面上で、アプリを起動せずとも「今の準備状態」が瞬時に理解できるウィジェット。

- **左半分（タンクエリア）:** タンクには満水の水が蓄えられており、時間内に準備を進めていれば水位は高く保たれます。遅れが生じると水位が下がり（水が無駄になる）、残り水量が視覚的に伝わります。滑らかに波打つ液体のアニメーションを描画。
- **右半分（水槽エリア）:** 現在の育成予測状態（卵 ➔ 稚魚 ➔ 幼魚 ➔ 成魚）をシンプルなグラフィックで表示。現時点の残水量で出発した場合に育つ魚のプレビューとして機能。
- **出発時の演出:** 「いってきます！」ボタンを押すと、タンク底部から水が流れ出し、水槽へ注ぎ込むアニメーションをライブアクティビティ上で実行（`pour` アニメーション）。

### 2.3 Core Hapticsによる五感通知

スマホをポケットやバッグに入れている状態でも、状態変化を体感できるようにします。

- **遅延警告時:** 予定時間がオーバーした瞬間、警告を示す少し不快（微細で細かい）なザラザラとしたバイブレーションを発生させ、心地よい危機感を促します。
- **操作確認:** スタート・出発完了などの主要操作で触覚フィードバックを返します。

### 2.4 ホーム画面ウィジェットとディープリンク起動

`DewTimeQuickStartWidget` をホーム画面に配置することで、アプリを起動して時間をセットする手間を省き、クイックにタイマーを開始できます。

- **クイック起動:** 「15分」「30分」「45分」「60分」などのプリセットを配置したウィジェットから、ワンタップでタイマーを即座に開始。
- **ディープリンク:** `dewtime://start-timer?minutes=N` のURLスキームを発行し、アプリ内の `QuickTimerDeepLinkRouter` が受信して `TimerView` でタイマーを自動スタートします。

---

## 3. UI/UX & SwiftUI実装設計

### 3.1 タンクの液体アニメーション（Wave Shape）

`TimelineView` と `Canvas` を組み合わせることで、端末のCPU負荷を抑えつつ、リアルタイムに滑らかに揺れる液体の波（サイン波）を秒単位で描画します。

**アニメーションロジック:**
- タンクはタイマー開始時に満水（100%）でスタートします。
- 時間内に準備を進めている間は水位が高く保たれます。遅延が発生するとその分だけ水位が下がり（水が無駄に溢れ出る）、現在の残水量を0%〜100%で表します。
- 時間の経過と同期した「位相（ズレ）」を波の計算式に与え続けることで、常に水面がゆらゆらと波打っているような視覚効果を表現します。
- **出発アニメーション (`PourTransitionView`):** 「いってきます！」タップ時、タンク底部のバルブが開くように水が流れ出し、タンクが空になるとともに水槽へ水が注ぎ込まれるシーケンスアニメーションを再生します。

**インタラクティブ水位設定（ドラッグジェスチャー）:**
- `WaterTankView` は `isDraggable: true` パラメータを設定することでタッチ操作対応になります。
- タイマー画面（`TimerView`）では、未スタート時にタンクを上下にスワイプするだけで出発までの時間（5〜30分）をダイレクトに設定できます。水位が高いほど長い時間を意味します。
- 水位の高さ・色・アイコンが時間量と状態を伝えるため、文字が読めないユーザーでも直感的に使用可能です。
- 水位の値はパーセント表示を廃止し、タイマー実行中は「残り時間（MM:SS 形式の数字）」のみを表示します。数字は言語に依存せず万国共通で理解可能です。

### 3.2 水槽の成長システム

出発のたびに水槽へ注いだ水は累積され、累積量に応じて水槽のサイズ段階（ミニ水槽 ➔ 小型 ➔ 中型 ➔ 大型 ➔ 特大 ➔ アクアリウム ➔ 大水族館）が上がっていきます。水槽が大きくなるほど、より大きな魚（イルカ、サメ、クジラ、ジンベエザメなど）を飼えるようになり、コレクションの幅が広がります。

### 3.3 泳ぐ水槽（ライブアクアリウム）

専用の「水槽」タブでは、コレクション済み（図鑑で解放した）の魚たちが実際に泳ぐ様子を眺められます。鑑賞性とインタラクション性を両立した、`TimelineView(.animation)` + `Canvas` による60fpsのライブシーンです。

**描画と演出（`LiveAquariumView` / `AquariumEngine`）:**
- **遊泳:** 解放済みの魚種が泳ぎ回る（1種につき最大3匹、合計18匹まで）。種類ごとに `requiredWaterRatio` を基準にサイズと速度が変化し、小型魚は小さく速く、大型魚は大きくゆっくり泳ぐ。壁で反射し、進行方向に応じて左右反転、上下にゆらぎながらヒレをはためかせる。
- **環境ギミック:** 底から立ち上る泡、左右に揺れる海藻、砂底、水面から差し込む光のカーテンを描画。
- **タップ操作:** 水面タップでエサを投入すると、近くの魚が集まって食べる（食べた瞬間に泡が立つ）。魚を直接タップすると喜んでプルプル震え、ハートが立ち上る。
- **空状態:** まだ魚を1匹も育てていない場合は、薄いサンプルのメダカが泳ぎ、操作ヒントを表示する。
- シミュレーション本体（`AquariumEngine`）は `TimelineView` の再描画に同期して毎フレーム物理ステップを進め、バックグラウンド復帰時の巨大な経過時間はクランプして破綻を防ぐ。
- 画面上部には水槽サイズ名（`Aquarium.sizeName`）と遊泳中の匹数を表示。カレンダーボタンから直近7日の水やり記録（後述の記録グリッド）をシートで開ける。

### 3.4 認証およびクラウドデータ同期フロー

ユーザーデータの保護と複数端末での利用のため、Supabaseをベースにしたクラウド同期機能を実装しています。

- **シームレスな匿名ログイン:** 初回起動時にバックグラウンドで `AuthService` が匿名アカウントを自動作成。アカウント登録の手間なしに即座にタイマーを開始できます。
- **アカウント統合・登録:** 設定画面からメールアドレス/パスワードまたはApple IDでアカウントを「アップグレード（本登録）」可能。機種変更時や複数端末間でデータを安全に引き継げます。
- **自動データ同期 (`CloudDataService`):**
  - アプリ起動時およびバックグラウンドからの復帰時：自動的に最新のスナップショットをSupabaseから取得し、ローカルに適用。
  - データ変更時（タイマー終了、設定変更など）：変更を検知してローカルとクラウドの双方に全置換保存（`saveAll()`）。
  - オフライン対応：オフライン状態ではローカルのみに保存され、次にオンラインで起動・操作された際に自動的にSupabaseと同期します。

### 3.5 ダイバシティ配慮 UI 設計原則

DewTime は「文字を読めなくても、見た目と感触で使えるアプリ」を設計目標の一つとして掲げ、以下のユーザー層への配慮を実装しています。

- 未就学児・低学年の子ども（文字習得前）
- 読字困難（ディスレクシア）のある方
- 発達障害（自閉スペクトラム症・ADHDなど）のある方
- 外国語環境のユーザー（日本語非話者）

**設計の考え方:** 文字量を極限まで削ることは目的ではない。主要な操作と状態把握は、テキストラベルに頼らず視覚・触覚で伝わるように設計する。必要な情報（数字・設定説明など）は残し、補助的な視覚的な手がかりと併用する。

#### 視覚優先の表現（主要画面）

| 情報・操作 | 視覚的・感覚的な伝え方 |
|---|---|
| 出発まで / 遅刻中 | `figure.walk` / `exclamationmark.triangle.fill` アイコン、水の色 |
| スタート | `SluiceGateStartButton`（水門アイコン）|
| 出発 | `figure.walk.departure` アイコン |
| キャンセル | `xmark.circle` アイコン |
| 残り時間・水量 | 水位の高さ・波のアニメーション＋残り時間数字（MM:SS） |
| 図鑑フィルター | `checkmark.seal.fill`（解放済）/ `lock.fill`（未解放）/ `1.circle`〜`3.circle`（難易度） |
| タブ切り替え | アイコン（水槽・魚・人物など） |
| 水槽の匹数 | 魚アイコン＋数字バッジ |
| 初回の使い方 | 視覚的チュートリアル（`TutorialOverlayView`） |

#### 併用・保持する要素

- **カウントダウン数字（MM:SS 形式）** — 数字は言語・文化を問わず直感的に理解可能
- **時刻数字（7:30 など）** — 直感的理解が可能
- **プリセット数字（15 / 30 / 45 / 60）** — 時間量を示す数字
- **設定画面のテキスト（SettingsView）** — 通知・アカウントなど複雑な設定は説明文を維持
- **VoiceOver 対応** — 全インタラクティブ要素に `.accessibilityLabel()` を設定し、スクリーンリーダー利用者にはテキストで正確に読み上げ

#### ジェスチャー・感覚優先インタラクション

- **スワイプで時間設定**: タイマー画面（`TimerView`）で未スタート時にタンクを上下にドラッグして出発時間を設定。時間量と水位が直接対応するため、数字が読めなくても「水が多い = 時間が多い」という身体感覚で理解できる。
- **色・雰囲気による状態表現**: タイマー状態を水の色や画面全体のトーンで表現（十分な余裕: 青系 → 注意: 黄系 → 急いで: 橙系）。水槽・図鑑画面も魚の泳ぎ方や背景の雰囲気で「育っている」「集まっている」などを伝える。
- **ハプティクス**: 操作確認・遅延警告・出発完了をバイブレーションで通知し、画面を見なくても進行状況を把握可能。

### 3.6 チュートリアルとオンボーディング

初回起動時にアプリの概要と使い方の流れを直感的に教えるチュートリアル機能を搭載しています。

- **チュートリアルオーバーレイ (`TutorialOverlayView`):** アプリの基本となる「タイマー設定」「水の節約」「魚の育成」「水槽の成長」をステップバイステップの対話式カードで説明。
- **タブ連動ナビゲーション:** 説明の各ステップに合わせて「タイマー」タブや「水槽」タブへ動的に切り替え、画面位置を意識したユーザー体験を構築。
- **再実行機能:** 設定画面からいつでもチュートリアルを再実行可能です。

### 3.7 アプリ内レビュー促進 (`ReviewRequestManager`)

アプリの評価向上を図るため、適切なタイミングでレビューポップアップを促します。

- **トリガータイミング:** 「いってきます！」を押し、朝のタイマーを正常に出発完了した直後のポジティブな瞬間にポップアップを判定。
- **クールダウン期間:** 頻繁な要求によるストレスを防ぐため、1度表示された後は最低30日間のクールダウン期間を設けます。また、開発中のデバッグビルドではポップアップを出さない仕様（DEBUG環境はスキップ）になっています。

### 3.8 収益化・開発者サポート (チップ・投げ銭)

`StoreKit` フレームワークを利用した、開発者への感謝を伝えるチップ機能を設定画面内に提供しています。

- **投げ銭アイテム:** 「おやつ（Snack）」「コーヒー（Coffee）」「ピザ（Pizza）」の3つのメニュー。
- **StoreKit 構成 (`DewTime.storekit`):** 課金テスト環境を用意し、ローカルやテストフライトで安全な疑似決済テストを実行可能。
- **支援者ステータス:** チップを購入したユーザーは、`AppDataStore.isDeveloperSupported` が `true` となり、アプリ内でささやかな感謝メッセージや専用ステータスが付与されます。

---

## 4. データ構造 & 永続化設計（Supabase + AppDataStore）

本アプリは、パフォーマンスの確保と確実な同期のため、メモリ上でデータを配列として保持しつつ、ローカルファイルへのJSONシリアライズ永続化とSupabaseへの同期を二重に行うアーキテクチャを採用しています（SwiftDataは使用しません）。

### 4.1 永続化アーキテクチャ (`AppDataStore`)

`Support/AppDataStore.swift` の `@Observable @MainActor final class AppDataStore` がアプリの単一真実源（Single Source of Truth）となります。

- **メモリ内管理:** アプリ起動時に `load()` を実行し、全データをメモリ内のSwift配列（`activeFishes`, `collectedFishes`, `careRecords`, `aquariums`, `profiles`）に展開します。出発時刻は `TimerViewModel` の `targetDepartureTime` でセッション管理し、永続化は `UserDefaults` に保存します。
- **ローカル永続化 (`saveToLocal` / `loadFromLocal`):** アプリ内のドキュメントディレクトリにJSON形式でデータを保存。オフライン時や起動時の高速読込に使用。
- **クラウド永続化 (`CloudSnapshot`):** 
  - メモリ上の各オブジェクト群を `makeCloudSnapshot(userId:)` を通じて単一の DTO (Data Transfer Object) である `CloudSnapshot` に変換。
  - Supabaseに対して**全置換**で保存を行います。
  - データ追加や削除を検知した場合は、変更操作の最後で `saveAll()` を呼ぶことで同期を実行します。

### 4.2 テーブル定義 (Supabase PostgreSQL DDL)

Supabase上のテーブル定義とRLS（Row Level Security）の基本構造です。全データはユーザーIDに紐付けられ、第三者への開示は制限されます。

> **注:** `user_schedules` / `routine_items` は初期バージョンで存在しましたが、出発スケジュール機能削除に伴い `supabase/migrations/202606210001_drop_schedule_tables.sql` でテーブルごと削除済みです。以下は現行の主要テーブルです。

```sql
-- 育成中のアクティブな魚
create table if not exists public.active_fishes (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  species_id text not null,
  name text not null,
  started_at timestamptz not null,
  last_watered_at timestamptz,
  required_total_water double precision not null,
  received_water double precision not null,
  is_completed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 図鑑（収集済みの魚）
create table if not exists public.collected_fishes (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  species_id text not null,
  recorded_at timestamptz not null,
  succeeded boolean not null,
  water_ratio double precision not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 水やり（給水）記録
create table if not exists public.fish_care_records (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  species_id text not null,
  recorded_at timestamptz not null,
  water_amount double precision not null,
  total_water_after double precision not null,
  required_total_water double precision not null,
  growth_stage_raw_value text not null,
  completed_growth boolean not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 水槽の総累積水量データ
create table if not exists public.aquariums (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  total_water_collected double precision not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ユーザープロフィール
create table if not exists public.user_profiles (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  nickname text not null,
  avatar_emoji text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Row Level Security (RLS) ポリシーの設定
alter table public.active_fishes enable row level security;
alter table public.collected_fishes enable row level security;
alter table public.fish_care_records enable row level security;
alter table public.aquariums enable row level security;
alter table public.user_profiles enable row level security;
```

### 4.3 Swiftデータモデル定義

SwiftUIの `@Observable` マクロを利用したデータモデルです。

#### 1. 育成中の魚 (`ActiveFish`)
- `id: UUID` (主キー)
- `speciesId: String` (魚の種類ID、`FishSpecies`の生値)
- `name: String` (魚につけた名前)
- `startedAt: Date` (育成開始日時)
- `lastWateredAt: Date?` (最後に水をあげた日時)
- `requiredTotalWater: Double` (成長に必要な総水量)
- `receivedWater: Double` (現在までに注がれた水量)
- `isCompleted: Bool` (成魚まで育ち切ったか)
- *算出プロパティ* `progress: Double` (成長進捗率 0.0〜1.0)
- *算出プロパティ* `growthStage: GrowthStage` (progressに基づき、`egg`/`fry`/`juvenile`/`adult`を返却)

#### 2. 魚コレクション（図鑑）(`CollectedFish`)
- `id: UUID` (主キー)
- `name: String` (個体の名前)
- `speciesId: String` (魚の種類ID)
- `recorded_at: Date` (成魚になり図鑑に記録された日時)
- `succeeded: Bool` (出発成功フラグ)
- `waterRatio: Double` (出発時の残水率)

#### 3. 水やり記録 (`FishCareRecord`)
- `id: UUID` (主キー)
- `speciesId: String` (魚の種類ID)
- `recordedAt: Date` (給水日時)
- `waterAmount: Double` (給水量)
- `totalWaterAfter: Double` (給水後の総水量)
- `requiredTotalWater: Double` (成長に必要な総水量)
- `growthStageRawValue: String` (成長段階)
- `completedGrowth: Bool` (この給水で成魚に達したか)

#### 4. 水槽 (`Aquarium`)
- `id: UUID` (主キー)
- `totalWaterCollected: Double` (これまでに集めた総水量)
- *算出プロパティ* `sizeTier: Int` (総水量から導出される水槽サイズ 1〜7)
- *算出プロパティ* `sizeName: String` (サイズ階層名、例：「大型水族館」)

#### 5. 魚の種類 (`FishSpecies` enum)
- メダカ🐟、グッピー🐠、ミナミヌマエビ🦐、ネオンテトラ✨、プレコ🧹、エンゼルフィッシュ👼、カクレクマノミ🤡、ナンヨウハギ🌊、ウツボ🐍、タコ🐙、クラゲ🔮、イルカ🐬、サメ🦈、クジラ🐋、ジンベエザメ🐳の全15種。
- 必要水量レンジ（例: メダカは300L〜500L、ジンベエザメは8000L〜12000L）を保持。

---

## 5. 画面遷移・SwiftUIビュー階層

画面遷移には、SwiftUI標準 of TabView を使用し、タブベースの「4画面構成」を採用します。タブの並びは左から「タイマー → 図鑑 → 水槽 → プロフィール」です。

### 5.1 画面階層マップ

```
アプリ全体（App / ContentView）
├── チュートリアル（TutorialOverlayView） ※初回起動時または再表示要求時
└── タブ画面（TabView）
    ├── 1. タイマー画面（TimerView）
    │       ├── 1.1 クイック起動（Widget deep link / QuickTimerDeepLinkRouter）
    │       ├── 1.2 未スタート時の時間設定（WaterTankView スワイプ）
    │       │       タンクを上下スワイプして出発までの時間（5〜30分）を設定。
    │       │       残り分数を大きな数字で表示。水位・色・アイコンで状態を伝える。
    │       ├── 1.3 タイマー稼働中（WaterTankView - 貯水タンクアニメーション）
    │       │       状態表示は水位・色・アイコン（遅刻中: ⚠ / 通常: 人物アイコン）。
    │       │       スタート: SluiceGateStartButton。
    │       │       出発: figure.walk.departure アイコン。
    │       └── 1.4 出発完了・結果画面（DepartureResultView）
    │               数字（遅延）＋アイコン・演出で結果を伝える。レビュー要求トリガー。
    │
    ├── 2. 図鑑画面（CollectionView）
    │       ├── 2.1 魚種一覧・解放状況・フィルタ（Collected/Uncollected）
    │       └── 2.2 個体・種別詳細シート（FishDetailSheet）
    │
    ├── 3. 水槽画面（LiveAquariumView）
    │       ├── 3.1 泳ぐ水槽（Canvas + AquariumEngine 物理演算）
    │       ├── 3.2 インタラクション（エサやり・タップリアクション）
    │       └── 3.3 給水履歴・カレンダー表示（AquariumView / MonthlyAquariumView）
    │
    └── 4. プロフィール・設定画面（ProfileView）
            ├── 4.1 直近7日の水やり記録グリッドと週間サマリー（ProfileStats）
            └── 4.2 設定一覧（SettingsView）
                    ├── 4.2.1 通知オンオフ詳細設定（NotificationSettingsView）
                    ├── 4.2.2 クラウド同期アカウント登録・ログイン（AccountRegistrationView）
                    ├── 4.2.3 プロフィール編集（ProfileEditView）
                    ├── 4.2.4 開発者サポート投げ銭（SupportDeveloperView） ※StoreKit
                    └── 4.2.5 ローカル/クラウドデータ管理・初期化（DataManagementView）
```

---

## 6. リリース実績 & ロードマップ

### 6.1 リリース履歴

#### **Ver 1.0.1 (クラウド同期 & UX改善)**
- **新機能**:
  - Supabase連携による「クラウドデータ同期機能」を追加。アカウント作成でデータを安全にバックアップ・複数端末同期可能に。
  - 匿名サインインからメール/Appleアカウントへのアップグレードによる「アカウント登録・管理機能」を追加。
  - アプリの操作方法が直感的に学べる「チュートリアルオーバーレイ」を追加。
  - 設定画面下部へのアプリバージョン情報の表示。
- **改善**:
  - `Live Activities` (ロック画面ウィジェット・Dynamic Island) の動作・同期精度の向上。
  - ボタン操作やタブ選択時におけるハプティクスフィードバックを追加し、快適な手応えを演出。
  - 水槽画面、設定画面などのデザインの精緻化と調整。
  - 通知設定画面を独立・リニューアルし、アラートのオン・オフを詳細に設定可能に。

#### **Ver 1.0.2 (品質向上)**
- **改善**:
  - `ReviewRequestManager` を実装し、タイマーが正常に出発完了した直後の最適なタイミングで、簡単にレビューを入力できる機能を追加。
  - 軽微なバグ修正およびアプリの動作安定化。

#### **開発中（出発スケジュール削除）**
- **削除**:
  - 「出発スケジュール」「ルーティンタスク」機能を完全削除。タイマーは `TimerView` 上のスワイプで都度時間を設定する方式に一本化。
  - Supabase の `user_schedules` / `routine_items` テーブルを `202606210001_drop_schedule_tables.sql` で削除。
  - `StartSheet` / `RoutineEditorView` / `UserSchedule` / `RoutineItem` をコードベースから除去。

### 6.2 今後のロードマップ（機能拡張予定）

- **ウィジェット機能の強化**:
  - タンクの水位や育成中の魚のグラフィックをホーム画面に常時表示できる中サイズ/大サイズウィジェットの追加。
- **育成魚・水槽カスタマイズ要素の追加**:
  - 図鑑に登録された魚のほかに、水槽の背景（砂底、水草の色、サンゴなど）を注いだ水量やチップ購入等でアンロック・カスタマイズできる機能。
- **カレンダー・ログの高度な分析機能**:
  - 朝の準備時間を週・月単位でビジュアル化し、出発習慣の傾向をレポート画面で確認できる機能。
