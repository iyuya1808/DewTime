-- しずくシステム移行マイグレーション
-- 水量（double precision pt）ベースの成長管理から
-- 出発回数（integer しずく）ベースへの全置換。

-- =========================================================
-- active_fishes: received_water / required_total_water → departures
-- =========================================================

alter table public.active_fishes
  add column if not exists departures integer not null default 0;

-- 既存データ移行: received_water が required_total_water の何割かを departures に換算。
-- 新システムの最大しずく数は 7 なので、それを上限として比例変換する。
update public.active_fishes
  set departures = least(7, greatest(0,
    case when required_total_water > 0
      then floor(received_water / required_total_water * 7)
      else 0
    end
  ))
  where required_total_water is not null;

alter table public.active_fishes
  drop column if exists received_water,
  drop column if exists required_total_water;

-- =========================================================
-- fish_care_records: water_amount / total_water_after / required_total_water
--                    → departures_after, earned_drop
-- =========================================================

alter table public.fish_care_records
  add column if not exists departures_after integer not null default 0,
  add column if not exists earned_drop      boolean not null default true;

-- 既存データ移行: water_amount > 0 → earned_drop = true、それ以外 = false
update public.fish_care_records
  set earned_drop = (water_amount > 0)
  where water_amount is not null;

-- total_water_after / required_total_water から departures_after を推定
update public.fish_care_records
  set departures_after = least(7, greatest(0,
    case when required_total_water > 0
      then floor(total_water_after / required_total_water * 7)
      else 0
    end
  ))
  where required_total_water is not null;

alter table public.fish_care_records
  drop column if exists water_amount,
  drop column if exists total_water_after,
  drop column if exists required_total_water;

-- =========================================================
-- aquariums: total_water_collected → total_departures
-- =========================================================

alter table public.aquariums
  add column if not exists total_departures integer not null default 0;

-- 既存データ移行: total_water_collected を整数に丸めて保持
update public.aquariums
  set total_departures = greatest(0, floor(total_water_collected)::integer)
  where total_water_collected is not null;

alter table public.aquariums
  drop column if exists total_water_collected;
