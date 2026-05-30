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

-- ── Row Level Security ────────────────────────────────────────
alter table profiles         enable row level security;
alter table bookmarks        enable row level security;
alter table sadhana_records  enable row level security;
alter table subscriptions    enable row level security;

-- Users can only see/edit their own data
create policy "own profile"    on profiles        for all using (auth.uid() = id);
create policy "own bookmarks"  on bookmarks       for all using (auth.uid() = user_id);
create policy "own sadhana"    on sadhana_records for all using (auth.uid() = user_id);
create policy "own subs"       on subscriptions   for all using (auth.uid() = user_id);
