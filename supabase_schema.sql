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
  personal_note     text,                 -- user's private cross-device note
  preferred_language text,                 -- 'en' | 'ta' | 'hi' | 'bn' (cross-device)
  created_at        timestamptz default now(),
  updated_at        timestamptz default now()
);
-- If profiles already exists, add the new columns:
--   alter table profiles add column if not exists personal_note text;
--   alter table profiles add column if not exists preferred_language text;

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

-- ── AI Q&A Cache (shared Scripture Scholar answers) ──────────
-- A question answered once is reused for everyone, cutting repeat OpenAI
-- calls. Privacy: question_key is a SHA-256 hash of (language + normalized
-- question); the raw question text is never stored.
create table if not exists qa_cache (
  question_key text primary key,   -- SHA-256 hash, e.g. '9f2b...'
  response     text not null,
  citations    jsonb default '[]'::jsonb,
  hits         int default 0,
  created_at   timestamptz default now()
);
-- If you created the earlier version, clear plaintext rows + drop columns:
--   truncate table qa_cache;
--   alter table qa_cache drop column if exists question;
--   alter table qa_cache drop column if exists language;
alter table qa_cache enable row level security;
create policy "qa read"   on qa_cache for select using (auth.role() = 'authenticated');
create policy "qa insert" on qa_cache for insert with check (auth.role() = 'authenticated');
create policy "qa update" on qa_cache for update using (auth.role() = 'authenticated');

-- ── Gift Codes (a paid subscription gifted to a friend) ──────
-- Created server-side after a verified gift payment; redeemed by a friend
-- to receive the subscription. Only the service role writes these.
create table if not exists gift_codes (
  code         text primary key,        -- e.g. 'DHARMA-AB12-CD34'
  plan         text not null,           -- monthly | quarterly | annual
  tier         text not null,           -- sadhaka | annual
  amount_inr   int,
  razorpay_id  text,
  purchased_by uuid references profiles(id) on delete set null,
  redeemed_by  uuid references profiles(id) on delete set null,
  status       text default 'active',   -- active | redeemed
  created_at   timestamptz default now(),
  redeemed_at  timestamptz
);
alter table gift_codes enable row level security;
-- A buyer can see the codes they purchased (to re-share); writes are
-- service-role only (the payment / redeem Worker).
create policy "see own gift codes" on gift_codes for select using (auth.uid() = purchased_by);

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
-- Subscriptions: users may READ their own, but ONLY the server (service role,
-- via the verified-payment Worker) may write them. A real payment is the only
-- way to get premium — clients cannot self-grant.
create policy "read own subs"  on subscriptions   for select using (auth.uid() = user_id);

-- Protect subscription fields on profiles: users may update their own row
-- (name, avatar) but NOT subscription_tier / subscription_end. Any client
-- attempt is reverted; only the service role (auth.uid() is null — used by
-- the payment Worker) may change them.
create or replace function public.protect_subscription_fields()
returns trigger language plpgsql as $$
begin
  if auth.uid() is not null then
    new.subscription_tier := old.subscription_tier;
    new.subscription_end  := old.subscription_end;
  end if;
  return new;
end;
$$;
drop trigger if exists profiles_protect_sub on public.profiles;
create trigger profiles_protect_sub
  before update on public.profiles
  for each row execute function public.protect_subscription_fields();
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

-- ── Post Likes (Sangha reactions) ────────────────────────────
-- One row per (post, user) so a like is shared across all devices/users and a
-- user can't like twice. A trigger keeps sangha_posts.likes_count accurate, so
-- the post's author sees reactions from everyone. Run this whole block once.
create table if not exists public.post_likes (
  id         uuid primary key default gen_random_uuid(),
  post_id    uuid not null references public.sangha_posts(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (post_id, user_id)
);
alter table public.post_likes enable row level security;

-- A user may read, add, and remove only their OWN like rows. (The public like
-- COUNT lives on sangha_posts.likes_count, which everyone can already read.)
drop policy if exists "own post likes" on public.post_likes;
create policy "own post likes" on public.post_likes
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Keep sangha_posts.likes_count in sync as likes are added/removed. Runs as
-- SECURITY DEFINER so a like on someone else's post can still update that
-- post's count (the liker doesn't own the post row).
create or replace function public.sync_post_likes_count()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (tg_op = 'INSERT') then
    update public.sangha_posts
      set likes_count = coalesce(likes_count, 0) + 1
      where id = new.post_id;
    return new;
  elsif (tg_op = 'DELETE') then
    update public.sangha_posts
      set likes_count = greatest(coalesce(likes_count, 0) - 1, 0)
      where id = old.post_id;
    return old;
  end if;
  return null;
end;
$$;
drop trigger if exists trg_post_likes_count on public.post_likes;
create trigger trg_post_likes_count
  after insert or delete on public.post_likes
  for each row execute function public.sync_post_likes_count();

-- ── Post Comments (Sangha replies) ───────────────────────────
-- Threaded replies to a Sangha post, shared across all users. A trigger keeps
-- sangha_posts.comments_count accurate. Run this whole block once.
alter table public.sangha_posts add column if not exists comments_count int default 0;

create table if not exists public.post_comments (
  id            uuid primary key default gen_random_uuid(),
  post_id       uuid not null references public.sangha_posts(id) on delete cascade,
  user_id       uuid references public.profiles(id) on delete set null,
  author_name   text not null,
  author_avatar text not null,        -- single initial letter
  content       text not null,
  created_at    timestamptz not null default now()
);
alter table public.post_comments enable row level security;

-- Anyone authenticated can read replies; a user can post only as themselves.
drop policy if exists "read post comments" on public.post_comments;
create policy "read post comments" on public.post_comments
  for select using (auth.role() = 'authenticated');
drop policy if exists "insert post comments" on public.post_comments;
create policy "insert post comments" on public.post_comments
  for insert with check (auth.uid() = user_id);

-- Keep sangha_posts.comments_count in sync (SECURITY DEFINER so a reply on
-- someone else's post can update that post's count).
create or replace function public.sync_post_comments_count()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (tg_op = 'INSERT') then
    update public.sangha_posts
      set comments_count = coalesce(comments_count, 0) + 1
      where id = new.post_id;
    return new;
  elsif (tg_op = 'DELETE') then
    update public.sangha_posts
      set comments_count = greatest(coalesce(comments_count, 0) - 1, 0)
      where id = old.post_id;
    return old;
  end if;
  return null;
end;
$$;
drop trigger if exists trg_post_comments_count on public.post_comments;
create trigger trg_post_comments_count
  after insert or delete on public.post_comments
  for each row execute function public.sync_post_comments_count();

-- ── Comment Likes (likes on Sangha replies) ──────────────────
-- One row per (reply, user). A trigger keeps post_comments.likes_count accurate
-- so the replier — and everyone — sees reactions on a reply. Run this once.
alter table public.post_comments add column if not exists likes_count int default 0;

create table if not exists public.comment_likes (
  id         uuid primary key default gen_random_uuid(),
  comment_id uuid not null references public.post_comments(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (comment_id, user_id)
);
alter table public.comment_likes enable row level security;

-- A user may read, add, and remove only their OWN reply-like rows.
drop policy if exists "own comment likes" on public.comment_likes;
create policy "own comment likes" on public.comment_likes
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Keep post_comments.likes_count in sync (SECURITY DEFINER so a like on someone
-- else's reply can still update that reply's count).
create or replace function public.sync_comment_likes_count()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (tg_op = 'INSERT') then
    update public.post_comments
      set likes_count = coalesce(likes_count, 0) + 1
      where id = new.comment_id;
    return new;
  elsif (tg_op = 'DELETE') then
    update public.post_comments
      set likes_count = greatest(coalesce(likes_count, 0) - 1, 0)
      where id = old.comment_id;
    return old;
  end if;
  return null;
end;
$$;
drop trigger if exists trg_comment_likes_count on public.comment_likes;
create trigger trg_comment_likes_count
  after insert or delete on public.comment_likes
  for each row execute function public.sync_comment_likes_count();

-- ── One subscription per payment (race-safe grants) ──────────
-- The webhook and the browser verify can grant the same payment near-
-- simultaneously, creating duplicate subscription rows. Dedupe existing rows,
-- then enforce one row per razorpay_id so the Worker's insert is idempotent.
delete from public.subscriptions a
using public.subscriptions b
where a.razorpay_id = b.razorpay_id
  and a.razorpay_id is not null
  and a.ctid > b.ctid;

create unique index if not exists subscriptions_razorpay_id_uniq
  on public.subscriptions (razorpay_id)
  where razorpay_id is not null;
