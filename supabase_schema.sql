-- DharmaAI Supabase Schema
-- Run this in: supabase.com → Project → SQL Editor

-- ── User Profiles ────────────────────────────────────────────
create table if not exists profiles (
  id                uuid primary key references auth.users(id) on delete cascade,
  full_name         text,
  email             text,
  avatar_url        text,
  subscription_tier text default 'free', -- 'free' | 'sadhaka' | 'annual'
  subscription_end  timestamptz,
  created_at        timestamptz default now(),
  updated_at        timestamptz default now()
);

-- ── Bookmarks ────────────────────────────────────────────────
create table if not exists bookmarks (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid references profiles(id) on delete cascade,
  verse_id   text not null,           -- e.g. "BG_2_47"
  created_at timestamptz default now(),
  unique(user_id, verse_id)
);

-- ── Sadhana Records ──────────────────────────────────────────
create table if not exists sadhana_records (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid references profiles(id) on delete cascade,
  date                date not null,
  meditation_minutes  int default 0,
  verses_read         int default 0,
  chanting_rounds     int default 0,
  streak_count        int default 0,
  unique(user_id, date)
);

-- ── Subscriptions ─────────────────────────────────────────────
create table if not exists subscriptions (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid references profiles(id) on delete cascade,
  tier            text not null,          -- 'sadhaka' | 'annual'
  status          text default 'active',  -- 'active' | 'cancelled' | 'expired'
  amount_inr      int,                    -- 201 or 1100
  razorpay_id     text,                   -- payment ID from Razorpay
  started_at      timestamptz default now(),
  expires_at      timestamptz
);

-- ── Sangha Community Posts ───────────────────────────────────
create table if not exists sangha_posts (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid references profiles(id) on delete set null,
  author_name   text not null,
  author_avatar text not null,        -- single initial letter
  content       text not null,
  likes_count   int default 0,
  is_gift       boolean default false,
  gift_label    text,
  created_at    timestamptz default now()
);

-- ── Scripture Verses (public content) ────────────────────────
-- Column names are camelCase (quoted) to match the Flutter Verse model
-- and the queries in scripture_service.dart exactly.
create table if not exists verses (
  id                       text primary key,        -- e.g. 'BG_2_47'
  "bookName"               text not null default 'Bhagavad Gita',
  chapter                  int  not null,
  "verseNumber"            int  not null,
  "sanskritText"           text,
  "englishTransliteration" text,
  translation              text,
  commentary               text,
  "wordMeanings"           jsonb
);
alter table verses enable row level security;
-- Scriptures are public: anyone (even signed-out) may read.
create policy "verses are public" on verses for select using (true);

-- ── Row Level Security ────────────────────────────────────────
alter table profiles         enable row level security;
alter table bookmarks        enable row level security;
alter table sadhana_records  enable row level security;
alter table subscriptions    enable row level security;
alter table sangha_posts     enable row level security;

-- Users can only see/edit their own data.
-- Note: `for all using (...)` also acts as the INSERT WITH CHECK in Postgres,
-- so users may only insert/update rows that belong to them.
create policy "own profile"    on profiles        for all using (auth.uid() = id);
create policy "own bookmarks"  on bookmarks       for all using (auth.uid() = user_id);
create policy "own sadhana"    on sadhana_records for all using (auth.uid() = user_id);
create policy "own subs"       on subscriptions   for all using (auth.uid() = user_id);
-- Sangha posts: anyone authenticated can read; only author can insert
create policy "read sangha"    on sangha_posts    for select using (auth.role() = 'authenticated');
create policy "post sangha"    on sangha_posts    for insert with check (auth.uid() = user_id);

-- ── Auto-create a profile row on signup ───────────────────────
-- Runs as SECURITY DEFINER so it bypasses RLS and reliably inserts a
-- profile for every new auth user (works for email AND OAuth signups).
-- This is the source of truth for profile creation — the app no longer
-- depends on a client-side insert succeeding.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, email, avatar_url, subscription_tier)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', ''),
    new.email,
    -- Google OAuth supplies a profile photo URL as avatar_url / picture
    coalesce(new.raw_user_meta_data->>'avatar_url', new.raw_user_meta_data->>'picture'),
    'free'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Backfill: create/refresh profile rows for users who signed up before the
-- trigger existed, pulling name + avatar from their auth metadata.
insert into public.profiles (id, full_name, email, avatar_url, subscription_tier)
select id,
       coalesce(raw_user_meta_data->>'full_name', raw_user_meta_data->>'name', ''),
       email,
       coalesce(raw_user_meta_data->>'avatar_url', raw_user_meta_data->>'picture'),
       'free'
from auth.users
on conflict (id) do nothing;

-- Backfill avatar_url for existing profile rows that are missing it.
update public.profiles p
set avatar_url = coalesce(u.raw_user_meta_data->>'avatar_url', u.raw_user_meta_data->>'picture')
from auth.users u
where p.id = u.id and p.avatar_url is null;
