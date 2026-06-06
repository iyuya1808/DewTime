create table if not exists public.app_review_requests (
  id           uuid        primary key default gen_random_uuid(),
  user_id      uuid        not null references auth.users(id) on delete cascade,
  trigger      text        not null,
  app_version  text        not null,
  build_number text        not null,
  os_version   text        not null,
  requested_at timestamptz not null default now()
);

create index if not exists app_review_requests_user_id_idx on public.app_review_requests(user_id);

alter table public.app_review_requests enable row level security;

drop policy if exists "Users can insert own review requests" on public.app_review_requests;
create policy "Users can insert own review requests" on public.app_review_requests
  for insert with check (auth.uid() = user_id);

drop policy if exists "Users can view own review requests" on public.app_review_requests;
create policy "Users can view own review requests" on public.app_review_requests
  for select using (auth.uid() = user_id);

grant select, insert on table public.app_review_requests to authenticated;
