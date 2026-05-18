-- ---------------------------------------------------------------------------
-- entries: the unified daily-log table.
--
-- One row per logged event — observation, meal, nap, diaper, incident,
-- etc. The `kind` column discriminates; `details` holds the
-- kind-specific structured payload (a JSON object whose shape is
-- defined by the kind).
--
-- Naming follows CLAUDE.md's universal-naming convention — this is
-- the generic engine table the UI surfaces as "Observations" /
-- "Meals" / etc. New kinds add no schema, just a new value of
-- `entries.kind`.
-- ---------------------------------------------------------------------------

create table if not exists public.entries (
  id            uuid primary key default gen_random_uuid(),
  space_id      uuid not null references public.spaces(id) on delete cascade,
  group_id      uuid references public.groups(id) on delete set null,
  subject_id    uuid references public.subjects(id) on delete cascade,

  -- Discriminator. v1 supports: 'observation', 'meal', 'nap',
  -- 'diaper', 'incident', 'medication'. Open string for forward
  -- compat — UI maps unknown kinds to a generic "Entry" presentation.
  kind          text not null,

  -- Free-form narrative. Required for observation / incident; usually
  -- short or empty for meal / nap / diaper (those rely on `details`).
  text          text,

  -- Optional photo. Storage path resolved to a public URL via
  -- PhotoService (bypasses PowerSync — see CLAUDE.md "binary media").
  photo_url     text,

  -- Kind-specific structured payload. Shape examples:
  --   observation: {tags: [...]}
  --   meal: {meal_type: 'lunch', items: ['eggs', 'toast'], amount: 'most'}
  --   nap: {started_at: '...', ended_at: '...', quality: 'good'}
  --   diaper: {kind: 'wet'|'soiled'|'dry', changed_by: ...}
  --   incident: {severity: 1..5, parties: [...]}
  details       jsonb not null default '{}'::jsonb,

  recorded_by   uuid not null references public.members(id),
  recorded_at   timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

alter table public.entries replica identity full;

-- Common access patterns.
create index if not exists entries_subject_idx
  on public.entries(subject_id, recorded_at desc);
create index if not exists entries_group_recorded_idx
  on public.entries(group_id, recorded_at desc);
create index if not exists entries_space_kind_idx
  on public.entries(space_id, kind);

alter table public.entries enable row level security;

create policy "entries_authenticated_all" on public.entries
  for all to authenticated
  using (true) with check (true);

alter publication powersync add table public.entries;
