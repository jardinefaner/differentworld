-- ---------------------------------------------------------------------------
-- Recover orphaned spaces — spaces where every member has role != 'director'.
--
-- A user reported soft-bricking their space by demoting themselves from
-- director to lead_teacher while being the sole director. Without a
-- director, no UI affordance can change anyone's role back. The space
-- is "orphaned."
--
-- This migration finds every space in that state and promotes the
-- oldest-joined member to director. Idempotent — re-running on a
-- healthy space (every space already has at least one director) is a
-- no-op.
--
-- The UI-side fix (Wave 23) prevents this from happening again by
-- disabling the "demote to non-director" affordance for the last
-- director in a space. This migration cleans up the existing
-- casualties.
-- ---------------------------------------------------------------------------

do $$
declare
  s record;
  m record;
begin
  for s in select id from public.spaces loop
    -- Skip if there's already a director.
    perform 1
      from public.members
      where space_id = s.id and role = 'director'
      limit 1;
    if found then
      continue;
    end if;

    -- Otherwise promote the oldest-joined member.
    select id
      into m
      from public.members
      where space_id = s.id
      order by created_at asc
      limit 1;

    if found then
      update public.members
        set role = 'director'
        where id = m.id;
      raise notice 'Recovered orphan space %, promoted member % to director.',
        s.id, m.id;
    end if;
  end loop;
end$$;
