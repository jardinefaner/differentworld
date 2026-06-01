-- Supplies — the program's real-world inventory (docs/SUPPLIES.md,
-- VISION.md #15). A catalog you maintain once, then reference by id from
-- the things that consume it (activities → a bill of materials; schedule
-- blocks → a derived pack list). This migration is slice 1: the catalog
-- only. The activity_supplies join lands with slice 2.
--
-- Space-scoped like everything else; low sensitivity (program property,
-- not child data) but still gated by space membership via RLS.

create table if not exists public.supplies (
  id           uuid primary key default gen_random_uuid(),
  space_id     uuid not null references public.spaces(id) on delete cascade,

  name         text not null,

  -- Free-text shelf ("Art", "Sports", "Snack"). Suggested as chips in the
  -- UI; not an enum so a program can name its own categories.
  category     text,

  -- How many on hand. NULL = uncounted (not everything is). Stored as a
  -- real so "1.5 reams" is expressible.
  quantity     real,

  -- The unit `quantity` is measured in ("boxes", "reams", "balls").
  unit         text,

  -- Where it physically lives ("Cabinet B", "Gym closet"). Free text — NOT
  -- a reference to public.locations (those are scheduling places; this is
  -- storage).
  location     text,

  -- When set, the UI flags "running low" once quantity drops below it.
  low_stock_threshold real,

  -- Bucket-relative Storage path (binary-media rule: bytes live in Storage,
  -- the row carries only the path). NULL until a photo is added.
  photo_url    text,

  notes        text,

  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

alter table public.supplies replica identity full;

create index if not exists supplies_space_idx
  on public.supplies(space_id, category, name);

alter table public.supplies enable row level security;

-- Relaxed write policy, consistent with the ES256 `auth.uid()`-null
-- workaround in place across the schema (see CLAUDE.md). The GRANT layer +
-- space-scoped sync rule are the real gate at our scale.
create policy "supplies_authenticated_all" on public.supplies
  for all to authenticated
  using (true) with check (true);

alter publication powersync add table public.supplies;
