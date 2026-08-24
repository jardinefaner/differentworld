-- Year rollover, made additive (docs/ROLLOVER.md).
--
-- The problem this fixes: the app had no idea a year could end. A child's
-- room was a single `subjects.group_id`, overwritten when they moved up, so
-- there was no record they had ever been anywhere else — and the only way to
-- clear last year's roster was `Remove student`, which hard-deletes and
-- cascades from seven tables. A September cleanup destroyed a year of
-- observations, messages, survey answers and character sheets.
--
-- So: a period is a first-class row, membership-in-a-room-for-a-period is a
-- first-class row, and a child is NEVER deleted to make space for a new
-- intake — they become alumni and keep everything.
--
-- `subjects.group_id` is deliberately LEFT IN PLACE as the child's CURRENT
-- room. Every existing roster query keeps working unchanged; enrollments add
-- the history beside it rather than migrating fifty call sites at once.

-- A named period. One table serves a school year ('2026–27') and a session
-- ('Summer 2026') — an afterschool program needs both words and the shape is
-- identical, so nesting years-over-terms would buy nothing but joins.
create table if not exists public.terms (
  id          uuid primary key default gen_random_uuid(),
  space_id    uuid not null references public.spaces(id) on delete cascade,
  name        text not null,
  starts_on   date not null,
  ends_on     date,                    -- null = still open-ended
  is_current  boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- Exactly one current period per program, enforced by the database rather
-- than by whichever screen happens to set the flag.
create unique index if not exists terms_one_current_per_space
  on public.terms (space_id) where is_current;

create index if not exists terms_space_idx on public.terms (space_id, starts_on desc);

-- One child, in one room, for one period. The missing spine: this is what
-- makes "Owen was in Sparrows last year and Ospreys this year" a fact the
-- app holds rather than something overwritten.
--
-- NOT called `enrollments`: that name has been taken since the foundation
-- migration by the STAFF↔classroom join (member_id / group_id / role). Two
-- different relationships, one word — so this one is `placements`, which
-- says what it is without borrowing a name that already means something.
create table if not exists public.placements (
  id          uuid primary key default gen_random_uuid(),
  space_id    uuid not null references public.spaces(id) on delete cascade,
  subject_id  uuid not null references public.subjects(id) on delete cascade,
  -- Null = enrolled for the period but not yet placed in a room.
  group_id    uuid references public.groups(id) on delete set null,
  term_id     uuid not null references public.terms(id) on delete cascade,
  started_at  timestamptz not null default now(),
  -- Null = still open. Rollover CLOSES rather than deletes.
  ended_at    timestamptz,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists placements_subject_idx
  on public.placements (subject_id, started_at desc);
create index if not exists placements_term_idx
  on public.placements (term_id, group_id);

-- enrolled | alumni. Alumni keep every row they ever had; they simply stop
-- appearing in attendance, pickers and today's rosters.
alter table public.subjects
  add column if not exists status text not null default 'enrolled';

create index if not exists subjects_status_idx
  on public.subjects (space_id, status);

alter table public.terms       replica identity full;
alter table public.placements replica identity full;

alter table public.terms       enable row level security;
alter table public.placements enable row level security;

-- Relaxed policies, consistent with the ES256 auth.uid()-null workaround
-- (CLAUDE.md). Staff-only data: a placement names which child sat in which
-- room, so neither table joins the by_guardian stream.
create policy "terms_authenticated_all" on public.terms
  for all to authenticated using (true) with check (true);
create policy "placements_authenticated_all" on public.placements
  for all to authenticated using (true) with check (true);

alter publication powersync add table public.terms;
alter publication powersync add table public.placements;
