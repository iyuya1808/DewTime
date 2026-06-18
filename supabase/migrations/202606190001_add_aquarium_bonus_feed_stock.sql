-- aquariums: オンタイム出発で貯まるボーナス餌ストック
alter table public.aquariums
  add column if not exists bonus_feed_stock int not null default 0;
