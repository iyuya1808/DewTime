-- 既存ユーザー向けの一時的なデータ救済パッチ。
-- 不具合: LiveAquariumView の魚ガチャは「水槽内の魚が餌を食べた瞬間」にしか発火しないため、
-- collected_fishes が0件のユーザーは魚が永久に増えなかった（クライアント側は別途修正済み）。
-- 旧バージョンのまま運用を続けているユーザーにも救済が届くよう、サーバー側で初期魚を1匹付与する。
--
-- 対象: 出発済み（total_departures > 0、つまり餌を稼ぐ資格を得た）にもかかわらず
-- collected_fishes が0件のユーザーのみ。一度も出発していない新規ユーザーは対象外（0匹のままが正しい）。
insert into public.collected_fishes (id, user_id, name, species_id, recorded_at, succeeded, water_ratio, created_at, updated_at)
select
  gen_random_uuid(),
  a.user_id,
  'medaka',
  'medaka',
  now(),
  true,
  1.0,
  now(),
  now()
from public.aquariums a
where a.total_departures > 0
  and not exists (
    select 1 from public.collected_fishes c where c.user_id = a.user_id
  );

update public.aquariums a
set updated_at = now()
where exists (
  select 1 from public.collected_fishes c
  where c.user_id = a.user_id and c.species_id = 'medaka' and c.created_at >= now() - interval '5 minutes'
);
