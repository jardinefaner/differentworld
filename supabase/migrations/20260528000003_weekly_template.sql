-- Different World — Wave 154
-- Weekly schedule template: the program's default recurring pattern
-- per cohort × day-of-week. Director authors once per term;
-- "Generate blocks from <start> to <end>" materializes
-- schedule_blocks rows for the date range so the day view (and the
-- family lens) reads off the same schedule_blocks table as before.
--
-- Why two tables (template + slots):
-- * A template is a single row per (space) — there's exactly one
--   "default week" per program at a time. Director can save / clear
--   / re-author the whole thing without touching schedule_blocks.
-- * Slots are rows on (template, group, day_of_week) with their
--   activity + time window. Adding a new cohort or swapping an
--   activity is a per-row update; generating blocks reads slots
--   en masse and writes schedule_blocks per (date, group, slot).
--
-- The template never auto-applies — generation is an explicit
-- button. Otherwise editing the template would silently rewrite
-- weeks of already-customized schedule_blocks; the per-day
-- overrides (Wave 155) would be wiped on every edit.

create table if not exists public.weekly_templates (
  id            uuid primary key default gen_random_uuid(),
  space_id      uuid not null references public.spaces(id) on delete cascade,

  -- Human-friendly name shown on the template-list screen. Useful
  -- once a program has summer / school-year variants, even though
  -- v1 supports one active template per space at a time.
  name          text not null default 'Default week',

  created_by    uuid references public.members(id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),

  unique (space_id, name)
);

create table if not exists public.weekly_template_blocks (
  id            uuid primary key default gen_random_uuid(),
  template_id   uuid not null references public.weekly_templates(id) on delete cascade,
  space_id      uuid not null references public.spaces(id) on delete cascade,
  group_id      uuid not null references public.groups(id) on delete cascade,

  -- 0 = Monday … 6 = Sunday (ISO 8601). Matches Dart's
  -- DateTime.weekday minus 1 — the generator does `(weekday - 1)`.
  day_of_week   int  not null check (day_of_week between 0 and 6),

  -- Time-of-day for the slot. Stored as a 'HH:MM' string because
  -- PowerSync's local SQLite has no native TIME type. Half-open:
  -- a slot from 14:00 to 15:00 doesn't include 15:00.
  start_time    text not null,
  end_time      text not null,

  activity_id   uuid references public.activities(id) on delete set null,

  -- Default lead for this slot. Optional — generator copies it to
  -- the block's `lead_member_id` if set.
  lead_member_id        uuid references public.members(id) on delete set null,

  -- Default location override (matches schedule_blocks).
  location_override_id  uuid references public.locations(id) on delete set null,

  -- Free-text recurring notes ("bring water bottles," "no nut
  -- allergies in this slot"). Copied to schedule_blocks.notes.
  notes         text,

  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index if not exists weekly_template_blocks_template_idx
  on public.weekly_template_blocks(template_id);
create index if not exists weekly_template_blocks_group_dow_idx
  on public.weekly_template_blocks(group_id, day_of_week);

alter table public.weekly_templates        replica identity full;
alter table public.weekly_template_blocks  replica identity full;
alter publication powersync add table public.weekly_templates;
alter publication powersync add table public.weekly_template_blocks;

alter table public.weekly_templates        enable row level security;
alter table public.weekly_template_blocks  enable row level security;

create policy "weekly_templates_all"
  on public.weekly_templates for all
  to authenticated using (true) with check (true);

create policy "weekly_template_blocks_all"
  on public.weekly_template_blocks for all
  to authenticated using (true) with check (true);

create trigger weekly_templates_touch_updated_at
  before update on public.weekly_templates
  for each row execute function public.touch_updated_at();

create trigger weekly_template_blocks_touch_updated_at
  before update on public.weekly_template_blocks
  for each row execute function public.touch_updated_at();
