create table if not exists public.user_schedules (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  target_departure_time timestamptz not null,
  is_active boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.routine_items (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  schedule_id uuid not null references public.user_schedules(id) on delete cascade,
  name text not null,
  duration_seconds integer not null,
  color_hex text not null,
  order_index integer not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

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

create table if not exists public.aquariums (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  total_water_collected double precision not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.user_profiles (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  nickname text not null,
  avatar_emoji text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists user_schedules_user_id_idx on public.user_schedules(user_id);
create index if not exists routine_items_user_id_idx on public.routine_items(user_id);
create index if not exists routine_items_schedule_id_idx on public.routine_items(schedule_id);
create index if not exists active_fishes_user_id_idx on public.active_fishes(user_id);
create index if not exists collected_fishes_user_id_idx on public.collected_fishes(user_id);
create index if not exists fish_care_records_user_id_idx on public.fish_care_records(user_id);
create index if not exists aquariums_user_id_idx on public.aquariums(user_id);
create index if not exists user_profiles_user_id_idx on public.user_profiles(user_id);

alter table public.user_schedules enable row level security;
alter table public.routine_items enable row level security;
alter table public.active_fishes enable row level security;
alter table public.collected_fishes enable row level security;
alter table public.fish_care_records enable row level security;
alter table public.aquariums enable row level security;
alter table public.user_profiles enable row level security;

drop policy if exists "Users can manage own schedules" on public.user_schedules;
create policy "Users can manage own schedules" on public.user_schedules
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Users can manage own routine items" on public.routine_items;
create policy "Users can manage own routine items" on public.routine_items
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Users can manage own active fishes" on public.active_fishes;
create policy "Users can manage own active fishes" on public.active_fishes
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Users can manage own collected fishes" on public.collected_fishes;
create policy "Users can manage own collected fishes" on public.collected_fishes
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Users can manage own care records" on public.fish_care_records;
create policy "Users can manage own care records" on public.fish_care_records
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Users can manage own aquariums" on public.aquariums;
create policy "Users can manage own aquariums" on public.aquariums
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Users can manage own profiles" on public.user_profiles;
create policy "Users can manage own profiles" on public.user_profiles
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

grant usage on schema public to authenticated;
grant select, insert, update, delete on table public.user_schedules to authenticated;
grant select, insert, update, delete on table public.routine_items to authenticated;
grant select, insert, update, delete on table public.active_fishes to authenticated;
grant select, insert, update, delete on table public.collected_fishes to authenticated;
grant select, insert, update, delete on table public.fish_care_records to authenticated;
grant select, insert, update, delete on table public.aquariums to authenticated;
grant select, insert, update, delete on table public.user_profiles to authenticated;
