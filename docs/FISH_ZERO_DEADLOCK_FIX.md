# 「魚0匹デッドロック」不具合の修正まとめ

## 症状

水槽内に魚が1匹もいない状態だと、餌を与えても魚が永久に増えなかった。

## 原因

- 泳ぐ魚は `LiveAquariumView.specs`（[LiveAquariumView.swift:238](../DewTime/Views/Garden/LiveAquariumView.swift)）が `store.aquariumFish()`（= `collectedFishes`）から生成する。新規ユーザーは `collectedFishes` が空なので泳ぐ魚が0匹。
- 新しい魚は `AppDataStore.spawnFishFromFeed()`（[AppDataStore.swift:253](../DewTime/Support/AppDataStore.swift)）でのみ生成され、これを呼ぶのは `AquariumEngine.onFoodEaten`（水槽内の魚が餌を食べた瞬間）のみ。
- `AquariumEngine.stepFish()`（[LiveAquariumView.swift:105](../DewTime/Views/Garden/LiveAquariumView.swift)）は `fish.indices` をループするだけなので、泳ぐ魚が0匹だと餌は誰にも食べられず沈んで消える（`stepFood` で `y > 0.9` のものを削除）。
- 結果、`onFoodEaten` が一度も呼ばれず `spawnFishFromFeed()` も実行されない → **魚0匹 → 餌を食べられない → 魚が増えない** の無限デッドロック。

## 修正1: クライアント側（根本修正）

[LiveAquariumView.swift](../DewTime/Views/Garden/LiveAquariumView.swift) のタップ給餌処理で、水槽が空（`aquariumFish.isEmpty`）の場合は餌を水槽に落とすのではなく `handleFoodEaten()` を直接呼び、最初の1匹を即時付与するようにした。2匹目以降は従来通り、水槽内で魚に餌を食べさせる必要がある。

```swift
guard store.consumeBonusFeedIfAvailable() else { return }
Task { await store.saveAll() }

if aquariumFish.isEmpty {
    // 食べる魚が1匹もいないと餌が永遠に食べられないため、最初の1匹は即時付与する。
    Task { await handleFoodEaten() }
} else {
    _ = engine.dropFood(at: point)
}
```

この修正はアプリの新バージョンにのみ反映される。**旧バージョンを使い続けるユーザーには届かない**ため、サーバー側でも対応した。

## 修正2: サーバー側（Supabase、既存ユーザー・旧バージョンの救済）

`saveAll()` はクラウドに対して `deleteAll` → ローカルの内容を全アップサートする**全置換**方式（[CloudDataService.swift:242](../DewTime/Support/CloudDataService.swift)）。そのため一度きりのデータ修正では、旧バージョンの端末が次に何か操作して `saveAll()` を呼んだ瞬間にまた魚が消えてしまう。よって「一度きりの救済」と「継続的に自動回復するトリガー」の2段構成にした。

### `supabase/migrations/202606230001_backfill_starter_fish.sql`
既存データの即時救済。**出発済み（`total_departures > 0`、つまり餌を稼ぐ資格を得ている）にもかかわらず `collected_fishes` が0件のユーザー**にのみ、初期魚（medaka）を1匹挿入する。一度も出発していない新規ユーザーは対象外（0匹のままが正しい仕様のため）。

### `supabase/migrations/202606230002_auto_grant_starter_fish_trigger.sql`
継続的な安全網。`aquariums` テーブルへの書き込み（`saveAll()` のたびにほぼ毎回発生）をフックし、その時点で `total_departures > 0` かつ魚0匹なら自動的に1匹付与するトリガー `trg_ensure_starter_fish` を設置。旧バージョンが今後インストールされ続けても、サーバー側だけで救済され続ける。新バージョンが行き渡った後も無害（魚が既に1匹以上いれば何もしない）なので恒久的に残す。

```sql
create or replace function public.ensure_starter_fish()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.total_departures > 0 and not exists (
    select 1 from public.collected_fishes where user_id = new.user_id
  ) then
    insert into public.collected_fishes (...) values (..., 'medaka', 'medaka', ...);
  end if;
  return new;
end;
$$;

create trigger trg_ensure_starter_fish
after insert or update on public.aquariums
for each row
execute function public.ensure_starter_fish();
```

## なぜ新バージョンと旧バージョンが混在しても不整合が起きないか

- `saveAll()` 内で `collected_fishes` は `aquariums` より先にアップサートされる。トリガーが `aquariums` 書き込み時点で見る `collected_fishes` の状態は、同一リクエスト内で既に確定済みのもの。
- クライアントが先に魚を作っていれば、トリガーの「0匹」条件を満たさず何もしない。
- トリガーが先に魚を作っていれば、クライアントは次回 `syncFromCloud` でそれをそのまま受け取り、通常通り表示する。
- どちらの順序でも最終的に魚が重複して湧くことはなく、`total_departures > 0` を必須条件にしているため未使用の新規ユーザーに誤って魚が配られることもない。

## デプロイ時に判明した既存データの状態

デプロイ前のリモートDB調査で、`aquariums` 12件のうち7件が魚0匹、その内4件は実際に出発済み（6回・6回・35回・98回）にもかかわらず魚0匹という本物の被害ユーザーだった（残り3件は単に未使用の新規ユーザーで、0匹のままが正しい状態）。バックフィル実行後、対象0件になったことを確認済み。

また、デプロイ作業中にローカルのマイグレーション履行履歴とリモートの実態にズレがあることが判明した（過去4本がダッシュボードから直接適用されており、CLIの履行履歴に記録されていなかった）。`supabase migration repair` で履行履歴を実態に合わせてから、新規2本のみを `supabase db push` で反映した。

## 適用状況

2026-06-21 にSupabase上へ適用済み（`supabase db push` 成功、トリガー設置確認済み、対象ユーザー救済確認済み）。クライアント側修正はこのリポジトリにコミット予定（未リリース）。
