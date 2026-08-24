-- The Room console's two tables (docs/ROTATION.md).
--
-- 1. rotation_rounds — one row per ARRANGEMENT. The pair history is derived
--    from these rows rather than stored in a second table: `groups` already
--    says who was together, so the engine rebuilds RotationHistory by
--    folding the rounds. That keeps undo trivial (delete the row and the
--    history is genuinely gone, not orphaned) and means there is exactly one
--    place a round can be wrong. It bit the reference implementation the
--    other way round — a demo purge hard-deleted people still referenced by
--    rounds, silently corrupting the history.
--
-- 2. room_events — ONE log for every fairness instrument (who was picked,
--    who spoke first, who spoke, points, which prompt was used). They all
--    ask the same question — who has had their share, and how recently — so
--    separate stores would have made cross-instrument fairness impossible
--    and turned five instruments into five apps in a trench coat.
--
-- Both are per-GROUP because in this app the roster lives inside the room:
-- the children are members of a cohort, and fairness is scoped to the
-- cohort they sit in.

create table if not exists public.rotation_rounds (
  id            uuid primary key default gen_random_uuid(),
  space_id      uuid not null references public.spaces(id) on delete cascade,
  group_id      uuid not null references public.groups(id) on delete cascade,

  -- Monotonic per group. Minted client-side from max(round_no)+1 — NOT from
  -- a count, which collides after an undo and silently corrupts the history.
  round_no      integer not null,

  mode          text not null,             -- 'groups_of' | 'number_of_groups'
  n             integer not null,
  remainder     text not null default 'absorb', -- absorb|sit_out|own_group

  -- The arrangement itself: [["subjectId","subjectId"],…] and the children
  -- who sat this one out. jsonb here (not a join table) because a round is
  -- read and written whole, never queried by member.
  groups        jsonb not null,
  sat_out       jsonb not null default '[]'::jsonb,

  -- Stored so the same arrangement can be reproduced and shown to be unrigged.
  seed          bigint not null,

  new_pairs     integer not null default 0,
  repeat_pairs  integer not null default 0,

  created_by    uuid,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- The hot read is "this cohort's rounds, newest first" (rebuilding history
-- and showing the last arrangement).
create index if not exists rotation_rounds_group_idx
  on public.rotation_rounds (group_id, round_no desc);

create table if not exists public.room_events (
  id           uuid primary key default gen_random_uuid(),
  space_id     uuid not null references public.spaces(id) on delete cascade,
  group_id     uuid not null references public.groups(id) on delete cascade,

  -- Null for events about the room rather than a child (a prompt was used).
  subject_id   uuid references public.subjects(id) on delete cascade,

  kind         text not null,   -- picked|spoke_first|spoke|points|prompt_used
  -- Kind-dependent magnitude: seconds spoken, points awarded, else 1.
  value        integer not null default 1,
  -- Free slot for the non-person payload (which prompt, which round).
  detail       text,

  occurred_at  timestamptz not null default now(),
  created_by   uuid,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index if not exists room_events_group_idx
  on public.room_events (group_id, occurred_at desc);

alter table public.rotation_rounds replica identity full;
alter table public.room_events     replica identity full;

alter table public.rotation_rounds enable row level security;
alter table public.room_events     enable row level security;

-- Relaxed policies, consistent with the ES256 auth.uid()-null workaround
-- (CLAUDE.md): the sync rules' by_space stream + the GRANT layer are the
-- real gate. NOTE these rows ARE about children — a round names who sat with
-- whom — so they must never reach the by_guardian stream. Staff-only.
create policy "rotation_rounds_authenticated_all" on public.rotation_rounds
  for all to authenticated
  using (true) with check (true);
create policy "room_events_authenticated_all" on public.room_events
  for all to authenticated
  using (true) with check (true);

alter publication powersync add table public.rotation_rounds;
alter publication powersync add table public.room_events;
