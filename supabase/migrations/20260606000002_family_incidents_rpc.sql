-- Family-safe incident read.
--
-- The family lens must NEVER receive an incident's internal narrative
-- (`entries.text`) or `details.action_taken` — both can name OTHER
-- children (a conflict: "pushed by Timmy"). The UI hiding those fields is
-- not enough: RLS on `entries` is `for select ... using (true)`, so a
-- plain PostgREST `select()` ships every column to the guardian's device
-- where it's readable over the wire (Red Team B1). This RPC strips them
-- SERVER-SIDE so the bytes never leave Postgres.
--
-- It also enforces the access gate server-side (caller must be a guardian
-- of the child) and the surfacing policy (only incidents staff have
-- notified OR written a family note for), so the client is defense-in-depth
-- rather than the sole gate.
--
-- SECURITY DEFINER + explicit `caller_uid`: on ES256-keyed projects
-- `auth.uid()` is null inside the function (see CLAUDE.md / migration
-- 20260523000003), so the Dart client passes `session.user.id` and we
-- coalesce with `auth.uid()` as a fallback.

create or replace function app.family_incidents_for_subject(
  caller_uid uuid,
  p_subject_id uuid
)
returns table (
  id uuid,
  space_id uuid,
  group_id uuid,
  subject_id uuid,
  kind text,
  "text" text,
  photo_url text,
  details jsonb,
  recorded_by uuid,
  recorded_at timestamptz,
  updated_at timestamptz
)
language sql
security definer
set search_path = ''
as $$
  select
    e.id,
    e.space_id,
    e.group_id,
    e.subject_id,
    e.kind,
    null::text as "text",        -- strip the internal narrative
    null::text as photo_url,     -- strip any photo path
    jsonb_build_object(          -- strip action_taken; keep only safe keys
      'incident_type', e.details->>'incident_type',
      'parent_notified',
        coalesce((e.details->>'parent_notified')::boolean, false),
      'family_note', e.details->>'family_note'
    ) as details,
    e.recorded_by,
    e.recorded_at,
    e.updated_at
  from public.entries e
  where e.subject_id = p_subject_id
    and e.kind = 'incident'
    -- caller must be a guardian linked to this child
    and exists (
      select 1
      from public.subject_guardians sg
      join public.guardians g on g.id = sg.guardian_id
      where sg.subject_id = e.subject_id
        and g.user_id = coalesce(caller_uid, auth.uid())
    )
    -- only SURFACED incidents (notified OR a non-empty family note)
    and (
      coalesce((e.details->>'parent_notified')::boolean, false) = true
      or nullif(trim(e.details->>'family_note'), '') is not null
    )
  order by e.recorded_at desc
  limit 100;
$$;

grant execute on function app.family_incidents_for_subject(uuid, uuid)
  to authenticated;
