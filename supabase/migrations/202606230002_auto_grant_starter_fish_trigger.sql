-- 旧バージョンのクライアント(初期魚0匹デッドロックの不具合あり)が今後もインストールされ続ける
-- 可能性があるため、サーバー側で継続的に自動回復させるトリガーを設置する。
--
-- saveAll() は active_fishes -> collected_fishes -> fish_care_records -> aquariums -> user_profiles
-- の順でフルリプレース(delete-all + upsert)するため、aquariums の書き込み完了時点では
-- 同一リクエスト内の collected_fishes の状態は既に確定している。
-- そのタイミングで該当ユーザーの collected_fishes が0件なら、初期魚(medaka)を1匹自動付与する。
create or replace function public.ensure_starter_fish()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- total_departures = 0 はまだ一度も出発していない新規ユーザーであり、本来0匹のままで正しい。
  -- 出発済み(=餌を稼ぐ資格を得た)のに魚が0匹のケースだけを不具合として救済する。
  if new.total_departures > 0 and not exists (
    select 1 from public.collected_fishes where user_id = new.user_id
  ) then
    insert into public.collected_fishes (
      id, user_id, name, species_id, recorded_at, succeeded, water_ratio, created_at, updated_at
    ) values (
      gen_random_uuid(), new.user_id, 'medaka', 'medaka', now(), true, 1.0, now(), now()
    );
  end if;
  return new;
end;
$$;

drop trigger if exists trg_ensure_starter_fish on public.aquariums;
create trigger trg_ensure_starter_fish
after insert or update on public.aquariums
for each row
execute function public.ensure_starter_fish();
