-- Different World — Wave 153
-- Schedule scaffolding: activity catalog gets two visual fields.
--
-- `color` is a hex string the schedule grid uses to tint the block
-- so directors can scan a week and see at a glance where "active"
-- vs "quiet" vs "creative" lives. Free-form text instead of an enum
-- because directors want their own palette per program.
--
-- `category` is a coarse bucket ('active' / 'quiet' / 'creative' /
-- 'snack' / 'transition' / 'special' — informal, not enforced) used
-- for filtering the catalog and for the family-side summary.
--
-- Both are nullable: existing activities don't need a backfill.

alter table public.activities
  add column if not exists color text,
  add column if not exists category text;
