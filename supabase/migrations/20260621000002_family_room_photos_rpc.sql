-- Family-safe ROOM-photo read.
--
-- The family "photo of the moment" peek surfaces, alongside a child's own
-- tagged photos, the cohort's ROOM moments today — block captures with NO
-- subject tag (`subject_id IS NULL`). The family lens used to fetch those over
-- plain PostgREST, scoped by a CLIENT-SIDE list of today's block ids. RLS on
-- `attachments` is `for all ... using (true)`, so a technical guardian could
-- REPLAY that call with ANOTHER cohort's block id and read its room photos
-- (no specific-child leak — those are subject_id-tagged + canSeeSubject-gated;
-- this is the room-level hole flagged in commit c2dc886).
--
-- The fix moves the scope SERVER-SIDE: the guardian passes only the child's
-- subject_id, and Postgres resolves that child's group, then returns ONLY the
-- room photos on THAT group's blocks. A replayed call with a foreign block or
-- subject id returns nothing — the block-id filter the client used to own can
-- no longer be tampered with.
--
-- SECURITY DEFINER + explicit `caller_uid`: on ES256-keyed projects
-- `auth.uid()` is null inside the function (see CLAUDE.md / migration
-- 20260523000003), so the Dart client passes `session.user.id` and we
-- coalesce with `auth.uid()` as a fallback.

create or replace function app.family_room_photos_for_subject(
  caller_uid uuid,
  p_subject_id uuid,
  p_day date
)
returns table (
  id uuid,
  url text,
  caption text,
  created_at timestamptz,
  schedule_block_id uuid
)
language sql
security definer
set search_path = ''
as $$
  select
    a.id,
    a.url,
    a.caption,
    a.created_at,
    a.schedule_block_id
  from public.attachments a
  join public.schedule_blocks b on b.id = a.schedule_block_id
  -- The room scope, resolved server-side from the child, not the client:
  -- the block must belong to THIS child's group.
  join public.subjects s on s.id = p_subject_id and b.group_id = s.group_id
  where a.subject_id is null                 -- room-level only (no child tag)
    and a.created_at::date = p_day            -- today
    and a.url not like 'pending:%'            -- skip not-yet-uploaded bytes
    -- caller must be a guardian linked to this child
    and exists (
      select 1
      from public.subject_guardians sg
      join public.guardians g on g.id = sg.guardian_id
      where sg.subject_id = p_subject_id
        and g.user_id = coalesce(caller_uid, auth.uid())
    )
  order by a.created_at desc
  limit 12;
$$;

grant execute on function app.family_room_photos_for_subject(uuid, uuid, date)
  to authenticated;
