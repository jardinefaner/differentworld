-- Different World — Relax the SELECT policy on public.members.
--
-- SYMPTOM: every PowerSync CRUD upload of a `members` patch fails with
--
--     42501 · new row violates row-level security policy for table "members"
--
-- and retries forever. PowerSync drains its queue IN ORDER, so one op that
-- can never succeed blocks every write behind it. Observed on device at 101
-- consecutive retries with `ops=1` throughout — local writes all landing,
-- nothing reaching the server. The app's offline-first design is what makes
-- this so quiet: nothing errors in the UI, it just never syncs.
--
-- ROOT CAUSE: the same ES256 `auth.uid()` quirk already fixed twice —
-- `20260523000001_relax_exports_read.sql` (exports) and
-- `20260523000002_relax_family_reads.sql` (subjects, subject_guardians,
-- attendance_records). `members` has the identical shape and was missed:
--
--     members_select_same_space  FOR SELECT TO public
--       USING (space_id = app.current_space_id() OR id = auth.uid())
--
-- On this project PostgREST does not populate `request.jwt.claims`, so
-- `auth.uid()` is NULL in REST requests. `app.current_space_id()` reads
-- `space_id from members where id = auth.uid()` → also NULL. So the policy
-- is `space_id = NULL OR id = NULL` → unknown → FALSE for every row, for
-- every caller. The policy does not narrow access; it denies it outright.
--
-- Confirmed against the live database (2026-08-26): both policies are
-- PERMISSIVE, relforcerowsecurity is false, and there is no restrictive
-- policy hiding the behaviour. The UPDATE policy is already
-- `using (true) with check (true)` — so the write side is open and the
-- READ side is the only thing that can be rejecting.
--
-- Staff never noticed the read half because staff reads come from Drift via
-- PowerSync's service-role replication, which bypasses RLS entirely. Only
-- the PostgREST path — which is exactly what the CRUD uploader uses — sees
-- it.
--
-- HONEST LIMIT OF THIS FIX: a SELECT policy that hides every row should
-- normally make an UPDATE affect zero rows rather than raise 42501, so the
-- precise mechanism producing that particular error is not fully explained.
-- What IS established is that this policy denies every row for every caller
-- and is broken on its own terms. Fixing it is correct regardless; if the
-- upload failure persists afterwards the next suspect is PostgREST claim
-- population itself, not this policy.
--
-- SCOPE: `authenticated` only — never `anon`. The GRANT layer already gives
-- anon SELECT on public tables, so the role check here is what keeps signed-
-- out callers out. Members rows carry a display name, role and avatar path
-- for staff inside one program; this restores the same posture the other
-- three tables already have, and is no broader than the pre-rename policy
-- established in 20260517000003.
--
-- RE-TIGHTEN when PostgREST populates `request.jwt.claims` on this project.
-- Tracked in CLAUDE.md under the ES256 gotcha alongside the other relaxes.

drop policy if exists "members_select_same_space" on public.members;

create policy "members_select_authenticated" on public.members
  for select to authenticated
  using (true);
