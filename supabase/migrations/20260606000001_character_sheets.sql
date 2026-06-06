-- Character sheets — the persistent in-world SELF, the foundation of the
-- Different World feature (docs/WORLD.md, docs/WORLD_DESIGN.md). One row per
-- enrolled child (1:1 with subjects), surviving every weekly world reset.
--
-- Deliberately SEPARATE from subjects.photo_url: that field is the child's
-- administrative ID photo (used to identify kids at attendance/pickup and in
-- exports). The world-self's avatar is a DRAWING the child makes — a
-- pseudonymous, fictional identity (the privacy win, WORLD.md §J). Clobbering
-- the ID photo with a crayon self-portrait would break pickup identification,
-- so the drawn avatar lives here, on its own field.
--
-- This migration is slice 1: the self (drawn avatar + chosen name + birthday +
-- culture). Crews, the weekly world schedule, and dreams (which ride on the
-- existing groups/missions/entries) land in later slices.

create table if not exists public.character_sheets (
  id            uuid primary key default gen_random_uuid(),
  space_id      uuid not null references public.spaces(id) on delete cascade,
  subject_id    uuid not null references public.subjects(id) on delete cascade,

  -- The world-self's chosen name (kid-authored). NULL until the day-one ritual.
  chosen_name   text,

  -- The self-drawing: a bucket-relative path in the `person-photos` bucket,
  -- exactly like subjects.photo_url / members.avatar_url. Signed on read. May
  -- briefly hold a `pending:<id>` token when the drawing was saved offline.
  avatar_url    text,

  -- "Birthday" = enrollment / first daily. Age is DERIVED from completed
  -- dailies (no stored streak — the no-punishment vow), not from this.
  born_on       date,

  -- The kid's take on the world's culture.
  culture       text,

  -- Per-sheet flags, future use.
  capabilities  jsonb not null default '{}'::jsonb,

  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),

  -- 1:1 with the child.
  unique (subject_id)
);

alter table public.character_sheets replica identity full;

create index if not exists character_sheets_space_idx
  on public.character_sheets(space_id);

alter table public.character_sheets enable row level security;

-- Relaxed write policy, consistent with the ES256 auth.uid()-null workaround
-- (see CLAUDE.md). The space-scoped sync rule + GRANT are the real gate.
create policy "character_sheets_authenticated_all" on public.character_sheets
  for all to authenticated
  using (true) with check (true);

alter publication powersync add table public.character_sheets;
