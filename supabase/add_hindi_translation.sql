-- Migration: add hindi_translation column to verses table
-- Run in: Supabase Dashboard → SQL Editor
-- Safe to run multiple times (IF NOT EXISTS / IF EXISTS guards).

ALTER TABLE public.verses
  ADD COLUMN IF NOT EXISTS "hindiTranslation" TEXT;
