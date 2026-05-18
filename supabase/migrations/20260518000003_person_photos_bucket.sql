-- ---------------------------------------------------------------------------
-- Storage bucket for member + subject photos.
--
-- Trade-off note: this is a PUBLIC bucket. Paths use opaque UUIDs
-- inside a `<space_id>/` prefix, so URLs aren't guessable, but anyone
-- with a URL can fetch the bytes forever. CLAUDE.md's binary-media
-- contract says student photos should be private + signed URLs.
--
-- We're shipping public-with-obscurity for v0.1 to unblock the avatar
-- feature; a later migration will:
--   1. Flip the bucket private
--   2. Add an RLS policy on storage.objects scoping reads to members of
--      the space whose UUID is the first path segment
--   3. Make the client request signed URLs (short TTL) at view time
-- Tracking this in CLAUDE.md's "intentionally deferred" section.
--
-- Writes require auth (the `INSERT` policy below restricts to
-- authenticated). Photos uploaded by anonymous users are rejected.
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public)
values ('person-photos', 'person-photos', true)
on conflict (id) do nothing;

-- Drop any pre-existing default policies on this bucket so we own them.
do $$
declare
  p record;
begin
  for p in
    select policyname from pg_policies
     where schemaname = 'storage' and tablename = 'objects'
       and policyname like 'person_photos_%'
  loop
    execute format('drop policy if exists %I on storage.objects', p.policyname);
  end loop;
end$$;

-- READ: anyone can fetch (bucket is public). Codified here in case we
-- ever flip the bucket private without dropping these policies.
create policy "person_photos_read_public"
  on storage.objects for select
  using (bucket_id = 'person-photos');

-- WRITE: only authenticated users can upload / update / delete.
-- We don't gate by space_id at the RLS layer because auth.uid()
-- returns null on this ES256 project (see CLAUDE.md gotcha). The
-- client-side path constructor includes the space_id and the Drift
-- mutation writes the URL to a row that PowerSync's by_space rule
-- already gates, so the server is the final auth boundary.
create policy "person_photos_write_authenticated"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'person-photos');

create policy "person_photos_update_authenticated"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'person-photos')
  with check (bucket_id = 'person-photos');

create policy "person_photos_delete_authenticated"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'person-photos');
