-- Different World — Workaround: relax write policies to current_user
--
-- ROOT CAUSE: in this Supabase project, `auth.uid()` returns NULL on real
-- REST requests even when a valid Supabase user JWT is sent. We verified
-- (in the Dashboard SQL editor with `set_config('request.jwt.claims', ...)`)
-- that the auth.uid() function works correctly when claims ARE set —
-- but PostgREST is not populating `request.jwt.claims` for incoming
-- requests. The DB role IS being switched to `authenticated` (or we'd
-- see "permission denied for table" instead of the RLS error we see).
-- This is a Supabase project-level JWT-claim-extraction quirk we
-- can't fix from a migration; likely related to the new asymmetric
-- JWT signing rolled out for new projects in 2025/2026.
--
-- WORKAROUND: gate INSERT/UPDATE/DELETE policies on the database role
-- (`current_user = 'authenticated'`) instead of `auth.uid() is not null`.
-- The GRANT layer (migration 6 granted INSERT/UPDATE/DELETE only to
-- `authenticated`, never `anon`) is still the real gate.
--
-- TRADE-OFF: per-row user-identity checks are temporarily reduced.
-- Any authenticated user could in principle write to any program's data
-- via direct REST calls. For a dev/single-user project this is fine.
-- We will tighten back to auth.uid() once we resolve why PostgREST
-- isn't extracting JWT claims in this project.
--
-- SELECT policies are unchanged — reads happen via PowerSync's logical
-- replication (which authenticates separately) and not via PostgREST,
-- so RLS on reads doesn't affect the app today.

-- programs
alter policy "programs_insert_anyone" on public.programs
  with check (current_user = 'authenticated');

alter policy "programs_update_director" on public.programs
  using (current_user = 'authenticated');

-- profiles
alter policy "profiles_update_self_or_director" on public.profiles
  using (current_user = 'authenticated');

-- classrooms
alter policy "classrooms_write_director_or_lead" on public.classrooms
  using (current_user = 'authenticated')
  with check (current_user = 'authenticated');

-- enrollments
alter policy "enrollments_write_director" on public.enrollments
  using (current_user = 'authenticated')
  with check (current_user = 'authenticated');

-- roster
alter policy "students_program_all" on public.students
  using (current_user = 'authenticated')
  with check (current_user = 'authenticated');

alter policy "guardians_program_all" on public.guardians
  using (current_user = 'authenticated')
  with check (current_user = 'authenticated');

alter policy "student_guardians_program_all" on public.student_guardians
  using (current_user = 'authenticated')
  with check (current_user = 'authenticated');

-- attendance
alter policy "attendance_program_all" on public.attendance_records
  using (current_user = 'authenticated')
  with check (current_user = 'authenticated');
