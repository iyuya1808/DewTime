-- Entity ids are scoped per user. A global id primary key caused upsert conflicts
-- when a new auth user reused locally cached UUIDs from a previous account.

alter table public.active_fishes drop constraint active_fishes_pkey;
alter table public.active_fishes add primary key (user_id, id);

alter table public.collected_fishes drop constraint collected_fishes_pkey;
alter table public.collected_fishes add primary key (user_id, id);

alter table public.fish_care_records drop constraint fish_care_records_pkey;
alter table public.fish_care_records add primary key (user_id, id);

alter table public.aquariums drop constraint aquariums_pkey;
alter table public.aquariums add primary key (user_id, id);

alter table public.user_profiles drop constraint user_profiles_pkey;
alter table public.user_profiles add primary key (user_id, id);
