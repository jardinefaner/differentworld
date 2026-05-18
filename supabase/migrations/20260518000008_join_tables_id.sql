-- ---------------------------------------------------------------------------
-- PowerSync requires every replicated table to have an `id` column.
-- The two composite-PK join tables (group_members, subject_guardians)
-- were created without one, so the local PowerSync SQLite adds an
-- implicit `id TEXT PRIMARY KEY NOT NULL`. Drift's INSERT doesn't know
-- about that column → constraint code 1811: "id is required".
--
-- Fix: give each join table an explicit `id uuid` PK and demote the
-- composite to a UNIQUE constraint so we still get idempotent
-- (group_id, member_id) / (subject_id, guardian_id) writes.
--
-- After this migration the Drift classes need updating to declare
-- `id` and the mutator methods need to generate a uuid client-side
-- (see CLAUDE.md "PowerSync join tables need id").
-- ---------------------------------------------------------------------------

-- group_members --------------------------------------------------------------
alter table public.group_members
  add column if not exists id uuid not null default gen_random_uuid();

do $$
declare
  v_pk text;
begin
  select conname into v_pk
    from pg_constraint
   where conrelid = 'public.group_members'::regclass and contype = 'p';
  if v_pk is not null then
    execute format('alter table public.group_members drop constraint %I', v_pk);
  end if;
end$$;

alter table public.group_members
  add constraint group_members_pkey primary key (id);

alter table public.group_members
  drop constraint if exists group_members_pair_unique;
alter table public.group_members
  add constraint group_members_pair_unique unique (group_id, member_id);

-- subject_guardians ----------------------------------------------------------
alter table public.subject_guardians
  add column if not exists id uuid not null default gen_random_uuid();

do $$
declare
  v_pk text;
begin
  select conname into v_pk
    from pg_constraint
   where conrelid = 'public.subject_guardians'::regclass and contype = 'p';
  if v_pk is not null then
    execute format('alter table public.subject_guardians drop constraint %I', v_pk);
  end if;
end$$;

alter table public.subject_guardians
  add constraint subject_guardians_pkey primary key (id);

alter table public.subject_guardians
  drop constraint if exists subject_guardians_pair_unique;
alter table public.subject_guardians
  add constraint subject_guardians_pair_unique unique (subject_id, guardian_id);
