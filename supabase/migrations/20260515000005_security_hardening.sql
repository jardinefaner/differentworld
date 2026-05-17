-- Different World — Security hardening
--
-- Addresses the following Supabase linter warnings:
--   - function_search_path_mutable (touch_updated_at)
--   - anon/authenticated_security_definer_function_executable
--     (current_program_id, is_director, handle_new_user)
--
-- Strategy: SECURITY DEFINER helpers can't be removed (they're required
-- in RLS policies to avoid infinite recursion when reading profiles
-- inside profiles' own policy), and we can't revoke EXECUTE from
-- authenticated because that would break RLS evaluation itself.
--
-- The fix is to move them out of `public` into a private `app` schema
-- that PostgREST does not expose via the auto-generated REST API. The
-- functions stay callable from RLS policies; they just stop appearing
-- at /rest/v1/rpc/<name>.

-- ---------------------------------------------------------------------------
-- 1. Private schema for internal helpers, not exposed by PostgREST.
-- ---------------------------------------------------------------------------

create schema if not exists app;
grant usage on schema app to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 2. Recreate helpers in `app` with locked search_path.
--    `set search_path = ''` forces every identifier to be fully qualified
--    so the function can't be hijacked by a malicious search_path.
-- ---------------------------------------------------------------------------

create or replace function app.current_program_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select program_id from public.profiles where id = auth.uid();
$$;

grant execute on function app.current_program_id() to authenticated;

create or replace function app.is_director()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select role = 'director' from public.profiles where id = auth.uid()),
    false
  );
$$;

grant execute on function app.is_director() to authenticated;

create or replace function app.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data->>'display_name',
      new.raw_user_meta_data->>'full_name',
      split_part(new.email, '@', 1)
    )
  );
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Repoint the auth.users trigger at the new function.
-- ---------------------------------------------------------------------------

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function app.handle_new_user();

-- ---------------------------------------------------------------------------
-- 4. Repoint every RLS policy at the new app.* helpers.
--    ALTER POLICY preserves the policy name and existing role targeting;
--    we only swap the expression.
-- ---------------------------------------------------------------------------

-- programs
alter policy "programs_select_member" on public.programs
  using (id = app.current_program_id());

alter policy "programs_update_director" on public.programs
  using (id = app.current_program_id() and app.is_director());

-- profiles
alter policy "profiles_select_same_program" on public.profiles
  using (
    program_id = app.current_program_id()
    or id = auth.uid()
  );

alter policy "profiles_update_self_or_director" on public.profiles
  using (id = auth.uid() or app.is_director());

-- classrooms (FOR ALL policy needs both USING and WITH CHECK)
alter policy "classrooms_select_program" on public.classrooms
  using (program_id = app.current_program_id());

alter policy "classrooms_write_director_or_lead" on public.classrooms
  using (
    program_id = app.current_program_id()
    and (
      app.is_director()
      or exists (
        select 1 from public.profiles
        where id = auth.uid() and role = 'lead_teacher'
      )
    )
  )
  with check (program_id = app.current_program_id());

-- enrollments
alter policy "enrollments_select_program" on public.enrollments
  using (program_id = app.current_program_id());

alter policy "enrollments_write_director" on public.enrollments
  using (program_id = app.current_program_id() and app.is_director())
  with check (program_id = app.current_program_id());

-- roster
alter policy "students_program_all" on public.students
  using (program_id = app.current_program_id())
  with check (program_id = app.current_program_id());

alter policy "guardians_program_all" on public.guardians
  using (program_id = app.current_program_id())
  with check (program_id = app.current_program_id());

alter policy "student_guardians_program_all" on public.student_guardians
  using (program_id = app.current_program_id())
  with check (program_id = app.current_program_id());

-- attendance
alter policy "attendance_program_all" on public.attendance_records
  using (program_id = app.current_program_id())
  with check (program_id = app.current_program_id());

-- ---------------------------------------------------------------------------
-- 5. Drop the now-unreferenced public.* helpers. PostgREST will stop
--    exposing /rest/v1/rpc/current_program_id etc. once these are gone.
-- ---------------------------------------------------------------------------

drop function if exists public.current_program_id();
drop function if exists public.is_director();
drop function if exists public.handle_new_user();

-- ---------------------------------------------------------------------------
-- 6. Lock search_path on the remaining public.* function.
--    touch_updated_at is SECURITY INVOKER (runs as caller) but the linter
--    still flags mutable search_path because a malicious search_path
--    could shadow `now()` or similar in plpgsql functions. Locking it
--    eliminates that whole class of attacks.
-- ---------------------------------------------------------------------------

alter function public.touch_updated_at() set search_path = '';
