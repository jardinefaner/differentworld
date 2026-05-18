-- ---------------------------------------------------------------------------
-- group_members: which staff are assigned to which classrooms.
--
-- Directors don't need rows here — they implicitly have access to every
-- classroom in their space (the viewer + queries handle that fallback).
-- Lead teachers / teachers / assistants ARE scoped: they only see and
-- act on classrooms whose group_members row connects them.
--
-- The composite primary key (group_id, member_id) gives us idempotent
-- assignment writes — re-assigning is a no-op rather than a constraint
-- violation, and unassign is a simple delete by both keys.
-- ---------------------------------------------------------------------------

create table if not exists public.group_members (
  group_id    uuid not null references public.groups(id) on delete cascade,
  member_id   uuid not null references public.members(id) on delete cascade,
  space_id    uuid not null references public.spaces(id) on delete cascade,
  -- Optional per-room override: a staffer's role can differ per classroom
  -- (e.g. they're a 'lead' in Sunshine but a 'teacher' in Toddler Room).
  -- Default null = follow the member-level role.
  role_in_group text,
  assigned_at timestamptz not null default now(),
  primary key (group_id, member_id)
);

alter table public.group_members replica identity full;

create index if not exists group_members_member_idx
  on public.group_members(member_id);
create index if not exists group_members_space_idx
  on public.group_members(space_id);

alter table public.group_members enable row level security;

-- Relaxed policy per CLAUDE.md's auth.uid()-null gotcha. The GRANT
-- layer + the to-authenticated clause keep anon out.
create policy "group_members_authenticated_all" on public.group_members
  for all to authenticated
  using (true) with check (true);

alter publication powersync add table public.group_members;
