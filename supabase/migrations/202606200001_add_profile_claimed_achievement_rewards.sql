-- user_profiles: 実績報酬（餌）の受け取り済み ID 一覧
alter table public.user_profiles
  add column if not exists claimed_achievement_reward_ids text[] not null default '{}';
