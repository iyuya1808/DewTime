-- Create user_purchases table for developer supports and future items
create table if not exists public.user_purchases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  product_id text not null,
  original_transaction_id text not null unique,
  purchased_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

-- Index for performance
create index if not exists user_purchases_user_id_idx on public.user_purchases(user_id);

-- Enable RLS
alter table public.user_purchases enable row level security;

-- Policies
drop policy if exists "Users can view own purchases" on public.user_purchases;
create policy "Users can view own purchases" on public.user_purchases
  for select using (auth.uid() = user_id);

drop policy if exists "Users can insert own purchases" on public.user_purchases;
create policy "Users can insert own purchases" on public.user_purchases
  for insert with check (auth.uid() = user_id);

-- Grant privileges to authenticated users
grant select, insert on table public.user_purchases to authenticated;
