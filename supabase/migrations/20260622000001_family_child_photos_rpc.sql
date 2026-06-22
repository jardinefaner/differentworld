-- Family-safe per-child PHOTO-FOLDER read.
--
-- The staff per-child photo folder (ChildPhotosFolderScreen,
-- /subjects/:id/photos) reads `attachments` from local Drift via the
-- `by_space` PowerSync stream. Guardians never join a space
-- (`members.space_id` is null), so `by_space` delivers them NO rows — the
-- staff folder is an empty mirror on a guardian device.
--
-- This RPC is the family path: the guardian passes ONLY their child's
-- subject_id, and Postgres returns that child's whole photo collection —
-- the photos the child SHOT (`captured_by_subject_id = p_subject_id`) and
-- the photos OF the child (`subject_id = p_subject_id`). The union of the
-- two tagging axes is exactly the two lenses the folder's segmented toggle
-- ("Took" / "Of {name}") splits on, so we return both axes on every row and
-- let the client partition them.
--
-- Privacy — NO caption column. A staff caption is free text that can name
-- ANOTHER child ("Sofia and Mateo built a fort"). Staff-side that's fine
-- (canSeeSubject-gated); but a guardian device has no roster to scrub other
-- children's names with (CLAUDE.md "Any family-facing artifact built from
-- staff free-text must scrub other-child names"). Rather than ship a scrub
-- the device can't perform, we OMIT captions entirely family-side — the
-- folder shows photos only, never a caption. (Mirrors the recap peek, which
-- also drops the caption for the same reason.) A photo tagged to ANOTHER
-- child can't surface here either: we only ever match `p_subject_id` on the
-- two axes, so another child's keepsake is excluded by construction.
--
-- SECURITY DEFINER + explicit `caller_uid`: on ES256-keyed projects
-- `auth.uid()` is null inside the function (see CLAUDE.md / migration
-- 20260523000003), so the Dart client passes `session.user.id` and we
-- coalesce with `auth.uid()` as a fallback. The guardian↔child link is
-- re-checked server-side, so a replayed call with a foreign subject id
-- returns nothing.

create or replace function app.family_child_photos_for_subject(
  caller_uid uuid,
  p_subject_id uuid
)
returns table (
  id uuid,
  url text,
  thumb_url text,
  captured_by_subject_id uuid,
  subject_id uuid,
  schedule_block_id uuid,
  taken_at timestamptz,
  created_at timestamptz
)
language sql
security definer
set search_path = ''
as $$
  select
    a.id,
    a.url,
    a.thumb_url,
    a.captured_by_subject_id,
    a.subject_id,
    a.schedule_block_id,
    a.taken_at,
    a.created_at
  from public.attachments a
  where (
      -- the photos OF this child, OR the photos this child SHOT
      a.subject_id = p_subject_id
      or a.captured_by_subject_id = p_subject_id
    )
    and a.url not like 'pending:%'            -- skip not-yet-uploaded bytes
    -- caller must be a guardian linked to this child
    and exists (
      select 1
      from public.subject_guardians sg
      join public.guardians g on g.id = sg.guardian_id
      where sg.subject_id = p_subject_id
        and g.user_id = coalesce(caller_uid, auth.uid())
    )
  order by a.created_at desc;
$$;

grant execute on function app.family_child_photos_for_subject(uuid, uuid)
  to authenticated;
