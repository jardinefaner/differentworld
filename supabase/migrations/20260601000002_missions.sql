-- Missions — real jobs a kid (or counselor) actually does, with real
-- evidence (docs/MISSIONS.md, VISION.md #16). The grounded counterpart to
-- the imaginative Role Cards: each mission carries a manual (rules), a
-- practiceable checklist (actions), and the kind of evidence it leaves.
--
-- Per-program AND editable — each program tailors its own manual ("balls go
-- in THIS bin") — so this is a synced table, not a compiled catalog. A
-- starter set ships as templates the director adds with one tap.
--
-- This migration is slice 1: the catalog. Assignments + evidence (which
-- reuse entries/attachments) land in slice 2; the supply/location link
-- columns land with that wiring.

create table if not exists public.missions (
  id            uuid primary key default gen_random_uuid(),
  space_id      uuid not null references public.spaces(id) on delete cascade,

  name          text not null,
  icon          text,            -- a single emoji glyph
  tagline       text,
  why           text,            -- one line on why the job matters
  builds        text,            -- the trait it grows ("responsibility")

  -- The manual: how it's done + where things go (the SOP).
  rules         text,

  -- Ordered checklist of real steps, stored as a JSON array of strings
  -- (PowerSync ships jsonb as text; parsed client-side).
  actions       text,

  -- What proof to leave when done: 'photo' | 'count' | 'note' | 'check'.
  evidence_kind text not null default 'check',

  -- Age suitability (continuous, the 4–12 segment). NULL = any age.
  min_age       int,
  max_age       int,

  is_active     boolean not null default true,
  sort          int not null default 0,

  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

alter table public.missions replica identity full;

create index if not exists missions_space_idx
  on public.missions(space_id, sort, name);

alter table public.missions enable row level security;

-- Relaxed write policy, consistent with the ES256 auth.uid()-null
-- workaround (see CLAUDE.md). Space-scoped sync rule + GRANT are the gate.
create policy "missions_authenticated_all" on public.missions
  for all to authenticated
  using (true) with check (true);

alter publication powersync add table public.missions;
