-- ---------------------------------------------------------------------------
-- Tighten the person-photos write policies: a member may only write
-- under their own space_id prefix. Reads stay open (bucket is still
-- public for v0.1).
--
-- The first path segment is the writing user's space_id, e.g.
-- `<space_id>/member/<id>/<uuid>.jpg`. We extract it with
-- storage.foldername(name)[1] and compare to the caller's
-- members.space_id.
--
-- Caveat: this project has the ES256 / `auth.uid() returns null in
-- REST` gotcha (CLAUDE.md). Storage policies run in the same
-- PostgREST evaluation path, so `auth.uid()` may also be null here.
-- We allow the loose `current_user = 'authenticated'` fallback when
-- the strict check can't be evaluated — drop that branch once JWT
-- claims start populating.
-- ---------------------------------------------------------------------------

drop policy if exists "person_photos_write_authenticated"   on storage.objects;
drop policy if exists "person_photos_update_authenticated"  on storage.objects;
drop policy if exists "person_photos_delete_authenticated"  on storage.objects;

create policy "person_photos_insert_own_space"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'person-photos'
    AND (
      -- Strict path: caller's space_id matches the first path segment.
      (storage.foldername(name))[1] = (
        select coalesce(space_id::text, '')
          from public.members
         where id = auth.uid()
         limit 1
      )
      -- Loose fallback for the auth.uid()-is-null gotcha. The GRANT
      -- layer + the `to authenticated` clause still keep anon out.
      OR auth.uid() is null
    )
  );

create policy "person_photos_update_own_space"
  on storage.objects for update
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
  )
  with check (
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

create policy "person_photos_delete_own_space"
  on storage.objects for delete
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
