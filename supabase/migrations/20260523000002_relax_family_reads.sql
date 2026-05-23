-- Different World — Relax SELECT policies on subjects + attendance_records
-- + subject_guardians so guardian-side family providers can actually read.
--
-- ROOT CAUSE: same `auth.uid()` ES256-keyed-project quirk that bit
-- exports in `20260523000001_relax_exports_read.sql`. The universal-
-- rename migration (`20260518000001`) replaced the broad
-- `for all to authenticated using (true)` relax — established in
-- `20260517000003` for the pre-rename tables — with narrow per-space
-- SELECT policies:
--
--     using (space_id = app.current_space_id())
--
-- `app.current_space_id()` is `select space_id from public.members
-- where id = auth.uid()`. On this project `auth.uid()` returns null in
-- REST requests (PostgREST isn't populating `request.jwt.claims`), so
-- the function returns NULL, the SELECT policy evaluates `space_id =
-- NULL` → unknown → false, and the guardian device gets zero rows.
--
-- Staff devices never noticed because staff reads come from Drift via
-- PowerSync's service-role sync (which bypasses RLS). Only the family
-- lens reads these tables through direct PostgREST — see
-- `lib/features/family/family_providers.dart` — and is therefore the
-- only path the narrow policies break.
--
-- BROKEN ON GUARDIAN DEVICES TODAY:
--   subjects                — familyChildrenProvider, familySubjectByIdProvider
--   subject_guardians       — joined via `!inner` in familyChildrenProvider
--                             (PostgREST inner joins need SELECT on both)
--   attendance_records      — familyAttendanceForSubjectProvider
--
-- ALREADY OK (broad `for all to authenticated using (true)`):
--   entries                 — familyEntriesForSubjectProvider
--   attachments             — familyAttachmentsForEntityProvider
--
-- WORKAROUND: same shape as `20260523000001_relax_exports_read.sql` —
-- drop the narrow SELECT policies, replace with `for select to
-- authenticated using (true)`. The GRANT layer (only `authenticated`
-- has SELECT — never `anon`) plus the per-query `.eq(...)` filters in
-- the Dart providers (`subject_guardians.guardian_id = <my-id>`,
-- `subject_id = <child-i-can-see>`, etc.) plus the
-- `viewer.canSeeSubject(...)` defensive guard inside each family
-- provider are the effective gate.
--
-- TRADE-OFF: any authenticated user can SELECT any subject /
-- subject_guardians / attendance_records row via direct REST. For a
-- dev / single-program project this is acceptable. Tighten back to
-- per-user RLS once we resolve the JWT-claim extraction issue.
-- Tracked in CLAUDE.md under "auth.uid() returns null in REST
-- requests".
--
-- After this migration, the cards in `family_today_screen.dart`
-- (child carousel, today's attendance pill, recent observations,
-- received reports) should all render real data on guardian devices.

-- subjects
drop policy if exists "subjects_select_space" on public.subjects;
create policy "subjects_authenticated_read" on public.subjects
  for select to authenticated
  using (true);

-- subject_guardians (needed for the !inner join in familyChildrenProvider)
drop policy if exists "subject_guardians_select_space"
  on public.subject_guardians;
create policy "subject_guardians_authenticated_read"
  on public.subject_guardians
  for select to authenticated
  using (true);

-- attendance_records
drop policy if exists "attendance_select_space" on public.attendance_records;
create policy "attendance_authenticated_read" on public.attendance_records
  for select to authenticated
  using (true);
