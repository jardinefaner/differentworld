-- ---------------------------------------------------------------------------
-- Storage RLS for the `exports` bucket.
--
-- Migration 20260519000001 created the bucket as private but didn't add
-- storage.objects policies. Without them, every Storage REST call to
-- the bucket relies entirely on `public = false` — meaning an
-- authenticated user with a guessed path can download via the public
-- REST endpoint (signed URLs work, but so do raw GETs given the right
-- access).
--
-- This migration adds the RLS layer. Pattern mirrors
-- `person-photos`: relaxed writes for any authenticated user (RLS on
-- the *table* layer is the real auth boundary; storage paths are
-- UUID-namespaced inside `<space_id>/<export_id>.<format>`), and a
-- SELECT policy that gates by authenticated role only so the Dart
-- client can mint signed URLs for download.
--
-- Why not a path-gated SELECT? auth.uid() returns null in policy
-- evaluation on this ES256-keyed project (see CLAUDE.md gotcha), so
-- we can't authoritatively check "is this caller a member of the
-- space whose UUID matches the path's first folder." The trust chain
-- instead is: a caller can only learn an export's `storage_path`
-- from the `exports` table row, and the table's RLS DOES gate by
-- membership. Without a path you can't sign or fetch the file.
-- Re-tighten when JWT claims work.
-- ---------------------------------------------------------------------------

-- Idempotent drop in case this gets re-run.
do $$
declare
  p record;
begin
  for p in
    select policyname from pg_policies
     where schemaname = 'storage' and tablename = 'objects'
       and policyname like 'exports_%'
  loop
    execute format('drop policy if exists %I on storage.objects', p.policyname);
  end loop;
end$$;

-- SELECT: gated on the authenticated role so signed-URL minting works
-- via the user's JWT. Raw GETs from the public Storage endpoint also
-- pass this gate (any authenticated user), but the caller would still
-- need to know the path — which they can only learn from an
-- `exports` table row they have SELECT permission on.
create policy "exports_read_authenticated"
  on storage.objects for select
  to authenticated
  using (bucket_id = 'exports');

-- INSERT: authenticated only. Path validation happens client-side
-- (the Dart action constructs `<space_id>/<export_id>.<format>`).
create policy "exports_write_authenticated"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'exports');

create policy "exports_update_authenticated"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'exports')
  with check (bucket_id = 'exports');

create policy "exports_delete_authenticated"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'exports');
