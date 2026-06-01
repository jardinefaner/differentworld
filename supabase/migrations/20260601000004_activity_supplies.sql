-- Activity pack lists (docs/SUPPLIES.md "Making it more useful" #4): an
-- activity declares the supplies it needs, by reference to the Supplies
-- catalog. This is the join that lets an activity say "needs 12 markers"
-- and lets a schedule block / day roll up a pack list.
--
-- Join table → explicit `id` PK + UNIQUE(activity_id, supply_id) (the
-- PowerSync join-table rule in CLAUDE.md; composite PKs break the local
-- "id is required" insert).

create table if not exists public.activity_supplies (
  id           uuid primary key default gen_random_uuid(),
  space_id     uuid not null references public.spaces(id) on delete cascade,
  activity_id  uuid not null references public.activities(id) on delete cascade,
  supply_id    uuid not null references public.supplies(id) on delete cascade,

  -- How many of this supply the activity needs. NULL = "some / see notes".
  quantity     real,

  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),

  unique (activity_id, supply_id)
);

alter table public.activity_supplies replica identity full;

create index if not exists activity_supplies_activity_idx
  on public.activity_supplies(activity_id);
create index if not exists activity_supplies_space_idx
  on public.activity_supplies(space_id);

alter table public.activity_supplies enable row level security;

create policy "activity_supplies_authenticated_all" on public.activity_supplies
  for all to authenticated
  using (true) with check (true);

alter publication powersync add table public.activity_supplies;
