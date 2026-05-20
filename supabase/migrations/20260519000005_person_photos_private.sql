-- ---------------------------------------------------------------------------
-- Flip `person-photos` private + scope reads to space members.
--
-- Up to now this bucket was public-with-obscurity (UUID paths under a
-- <space_id>/ prefix). CLAUDE.md's binary-media contract requires
-- private + signed URLs for student photos. This migration completes
-- that flip on the server side; the Dart client switches in lockstep
-- to mint signed URLs via supabase.storage.createSignedUrl().
--
-- What changes:
--   1. storage.buckets.public flips false (bucket now requires auth
--      for every fetch).
--   2. The wide-open `person_photos_read_public` policy is dropped
--      and replaced with `person_photos_read_own_space`, which only
--      lets authenticated callers read objects whose first path
--      segment matches the caller's members.space_id.
--   3. Existing client-side stored URLs (full https://…/object/public/
--      …) stop resolving — the Dart client now extracts the path and
--      mints a fresh signed URL each view. New uploads store paths,
--      not URLs.
--
-- ES256 / `auth.uid()` is null gotcha (see CLAUDE.md):
-- Same workaround as the write policies — keep a loose
-- `auth.uid() is null` arm so the policy doesn't reject everything
-- while JWT claims aren't populated. The grant layer + `to
-- authenticated` clause is the remaining hard gate against anon
-- traffic; tighten once JWT claims are working.
-- ---------------------------------------------------------------------------

update storage.buckets
   set public = false
 where id = 'person-photos';

drop policy if exists "person_photos_read_public"  on storage.objects;

create policy "person_photos_read_own_space"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'person-photos'
    AND (
      (storage.foldername(name))[1] = (
        select coalesce(space_id::text, '')
          from public.members
         where id = auth.uid()
         limit 1
      )
      OR auth.uid() is null
    )
  );
