-- Different World — Wave 158
-- One-off events that overlay or replace the regular schedule for
-- a specific date. Distinct from activities (which are reusable
-- catalog items dropped into recurring slots). Events are the
-- "Halloween party," "guest speaker," "fundraiser night," "snow day
-- closure" — one-time, may span multiple cohorts.
--
-- Why a separate table from schedule_blocks:
-- 1. Events often span the whole program (every cohort), not one;
--    schedule_blocks is keyed on a single group_id.
-- 2. Events have a banner-style narrative the director writes once
--    and shares with families. schedule_blocks are utilitarian.
-- 3. Events don't always cancel the day's normal blocks. The
--    `mode` column captures the three intents: banner-on-top
--    (`overlay`), replaces blocks during its window (`replaces`),
--    or full-day shutdown (`closes_day`).

create table if not exists public.events (
  id            uuid primary key default gen_random_uuid(),
  space_id      uuid not null references public.spaces(id) on delete cascade,

  -- Day this event is on. Stored as `date` (no zone); the
  -- start_at / end_at columns carry the precise window.
  date          date not null,

  -- Optional timing window — null when the whole day is in scope
  -- (e.g. "closed for staff PD"). When present, scheduled blocks
  -- inside the window are visually flagged but only auto-replaced
  -- when mode = 'replaces'.
  start_at      timestamptz,
  end_at        timestamptz,

  title         text not null,
  description   text,

  -- Visual hex (matches activities.color from Wave 153).
  color         text,

  -- Which cohorts this event applies to. Empty array = all cohorts
  -- in the space. JSONB so the array can grow without a migration.
  group_ids     jsonb not null default '[]'::jsonb,

  -- How the event interacts with regular schedule_blocks for the
  -- affected cohorts on this date:
  --   'overlay'      — banner sits above the day's blocks
  --   'replaces'     — blocks inside start_at..end_at are dimmed
  --                    (still in DB but visually superseded)
  --   'closes_day'   — entire day is closed; no blocks render
  mode          text not null default 'overlay'
                check (mode in ('overlay', 'replaces', 'closes_day')),

  -- Optional location override for the whole event (party in the
  -- big room, field-day on the field). Per-cohort schedule_blocks
  -- aren't rewritten; this is just for the banner.
  location_id   uuid references public.locations(id) on delete set null,

  created_by    uuid references public.members(id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index if not exists events_space_date_idx
  on public.events(space_id, date);

alter table public.events replica identity full;
alter publication powersync add table public.events;

alter table public.events enable row level security;

-- Wave 138-era pattern: relax-write policies on `authenticated`
-- because per-user RLS over auth.uid() is gated by the broken JWT
-- claims (see CLAUDE.md). The space-scope check is by GRANT + the
-- sync rule below.
create policy "events_all"
  on public.events for all
  to authenticated
  using (true)
  with check (true);

create trigger events_touch_updated_at
  before update on public.events
  for each row execute function public.touch_updated_at();
