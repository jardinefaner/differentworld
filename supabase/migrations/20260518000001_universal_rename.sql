-- Different World — universal-naming rename (aggressive refactor)
--
-- Renames domain-specific tables/columns to the generic engine names
-- defined in docs/NAMING.md:
--
--   programs              → spaces
--   profiles              → members
--   classrooms            → groups
--   students              → subjects
--   student_guardians     → subject_guardians
--
-- Columns:
--   program_id            → space_id        (across all tables)
--   classroom_id          → group_id        (across all tables)
--   student_id            → subject_id      (across all tables)
--   profile_id            → member_id       (across all tables)
--
-- Plus:
--   public.staff_role     → public.member_role  (enum rename)
--   app.current_program_id() → app.current_space_id()
--   handle_new_user trigger updated to insert into public.members
--   capabilities JSONB column added to spaces, members, groups, subjects
--   public.invites table + app.accept_invite() function
--
-- Kept (renamed-by-column-only):
--   guardians table — name unchanged, only program_id → space_id
--   enrollments, attendance_records — name unchanged, columns renamed
--   (Guardians will become Subjects-with-kind='guardian' in a later
--   migration; not aggressive enough today to also restructure
--   relationship semantics.)

-- ---------------------------------------------------------------------------
-- 0. Drop the publication first so logical replication doesn't choke on
--    the rename storm. Recreated at the end.
-- ---------------------------------------------------------------------------
drop publication if exists powersync;

-- ---------------------------------------------------------------------------
-- 1. Drop ALL existing RLS policies that reference soon-to-be-renamed
--    tables, columns, or functions. They'll be recreated at the end.
-- ---------------------------------------------------------------------------
drop policy if exists "programs_select_member"            on public.programs;
drop policy if exists "programs_authenticated_write"      on public.programs;

drop policy if exists "profiles_select_same_program"      on public.profiles;
drop policy if exists "profiles_authenticated_write"      on public.profiles;

drop policy if exists "classrooms_select_program"         on public.classrooms;
drop policy if exists "classrooms_authenticated_write"    on public.classrooms;

drop policy if exists "enrollments_select_program"        on public.enrollments;
drop policy if exists "enrollments_authenticated_write"   on public.enrollments;

drop policy if exists "students_authenticated_write"      on public.students;

drop policy if exists "guardians_authenticated_write"     on public.guardians;

drop policy if exists "student_guardians_authenticated_write"
  on public.student_guardians;

drop policy if exists "attendance_authenticated_write"
  on public.attendance_records;

-- ---------------------------------------------------------------------------
-- 2. Drop old helper functions (they reference public.profiles which is
--    about to be renamed).
-- ---------------------------------------------------------------------------
drop function if exists app.current_program_id();
drop function if exists app.is_director();

-- ---------------------------------------------------------------------------
-- 3. Rename tables.
-- ---------------------------------------------------------------------------
alter table public.programs           rename to spaces;
alter table public.profiles           rename to members;
alter table public.classrooms         rename to groups;
alter table public.students           rename to subjects;
alter table public.student_guardians  rename to subject_guardians;

-- ---------------------------------------------------------------------------
-- 4. Rename columns. `program_id` / `classroom_id` / `student_id` /
--    `profile_id` become `space_id` / `group_id` / `subject_id` /
--    `member_id` everywhere they appear.
-- ---------------------------------------------------------------------------
alter table public.members   rename column program_id   to space_id;

alter table public.groups    rename column program_id   to space_id;

alter table public.enrollments rename column program_id   to space_id;
alter table public.enrollments rename column profile_id   to member_id;
alter table public.enrollments rename column classroom_id to group_id;

alter table public.subjects  rename column program_id   to space_id;
alter table public.subjects  rename column classroom_id to group_id;

alter table public.guardians rename column program_id   to space_id;

alter table public.subject_guardians rename column program_id to space_id;
alter table public.subject_guardians rename column student_id  to subject_id;

alter table public.attendance_records rename column program_id   to space_id;
alter table public.attendance_records rename column classroom_id to group_id;
alter table public.attendance_records rename column student_id   to subject_id;

-- ---------------------------------------------------------------------------
-- 5. Rename the role enum type.
-- ---------------------------------------------------------------------------
alter type public.staff_role rename to member_role;

-- ---------------------------------------------------------------------------
-- 6. Recreate helper functions in `app` schema with the new names.
--    Lock search_path = '' per the security-hardening convention.
-- ---------------------------------------------------------------------------
create or replace function app.current_space_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select space_id from public.members where id = auth.uid();
$$;

grant execute on function app.current_space_id() to authenticated;

create or replace function app.is_director()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select role = 'director' from public.members where id = auth.uid()),
    false
  );
$$;

grant execute on function app.is_director() to authenticated;

-- Update handle_new_user to insert into the renamed members table.
create or replace function app.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.members (id, display_name)
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

-- Trigger already points to app.handle_new_user — just updated body.

-- ---------------------------------------------------------------------------
-- 7. Add `capabilities` jsonb column to each entity table. Default {} so
--    existing rows are valid.
-- ---------------------------------------------------------------------------
alter table public.spaces   add column if not exists capabilities jsonb not null default '{}'::jsonb;
alter table public.members  add column if not exists capabilities jsonb not null default '{}'::jsonb;
alter table public.groups   add column if not exists capabilities jsonb not null default '{}'::jsonb;
alter table public.subjects add column if not exists capabilities jsonb not null default '{}'::jsonb;

-- ---------------------------------------------------------------------------
-- 8. Invites table.
-- ---------------------------------------------------------------------------
create table if not exists public.invites (
  id             uuid primary key default gen_random_uuid(),
  space_id       uuid not null references public.spaces(id) on delete cascade,
  email          text,
  code           text unique,
  role           public.member_role not null default 'teacher',
  capabilities   jsonb not null default '{}'::jsonb,
  created_by     uuid references public.members(id) on delete set null,
  created_at     timestamptz not null default now(),
  expires_at     timestamptz,
  accepted_at    timestamptz,
  accepted_by    uuid references public.members(id) on delete set null,
  check (email is not null or code is not null)
);

alter table public.invites replica identity full;

create index if not exists invites_email_idx
  on public.invites(email) where accepted_at is null;
create index if not exists invites_code_idx
  on public.invites(code)  where accepted_at is null;
create index if not exists invites_space_idx
  on public.invites(space_id);

alter table public.invites enable row level security;

-- ---------------------------------------------------------------------------
-- 9. accept_invite — server-side function that consumes an invite.
-- ---------------------------------------------------------------------------
create or replace function app.accept_invite(invite_code text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_invite public.invites%rowtype;
  v_email  text;
begin
  select email into v_email from auth.users where id = auth.uid();

  select * into v_invite
    from public.invites
   where accepted_at is null
     and (expires_at is null or expires_at > now())
     and (
       (invite_code is not null and code = invite_code)
       or (invite_code is null and email = v_email)
     )
   order by created_at desc
   limit 1;

  if v_invite.id is null then
    raise exception 'No matching active invite';
  end if;

  update public.members
     set space_id     = v_invite.space_id,
         role         = v_invite.role,
         capabilities = coalesce(capabilities, '{}'::jsonb) || v_invite.capabilities,
         updated_at   = now()
   where id = auth.uid();

  update public.invites
     set accepted_at = now(),
         accepted_by = auth.uid()
   where id = v_invite.id;
end;
$$;

grant execute on function app.accept_invite(text) to authenticated;

-- ---------------------------------------------------------------------------
-- 10. Recreate RLS policies using the new table/column/function names.
--     Same workaround as migration 20260517000003 (relaxed to
--     `to authenticated` + permissive checks) since `auth.uid()` returns
--     null in REST requests on this Supabase project — see CLAUDE.md
--     "auth.uid() returns null in REST requests" gotcha.
-- ---------------------------------------------------------------------------

-- spaces
create policy "spaces_select_member" on public.spaces
  for select
  using (id = app.current_space_id());
create policy "spaces_authenticated_write" on public.spaces
  for all to authenticated
  using (true) with check (true);

-- members
create policy "members_select_same_space" on public.members
  for select
  using (space_id = app.current_space_id() or id = auth.uid());
create policy "members_authenticated_write" on public.members
  for update to authenticated
  using (true) with check (true);

-- groups
create policy "groups_select_space" on public.groups
  for select
  using (space_id = app.current_space_id());
create policy "groups_authenticated_write" on public.groups
  for all to authenticated
  using (true) with check (true);

-- enrollments
create policy "enrollments_select_space" on public.enrollments
  for select
  using (space_id = app.current_space_id());
create policy "enrollments_authenticated_write" on public.enrollments
  for all to authenticated
  using (true) with check (true);

-- subjects
create policy "subjects_select_space" on public.subjects
  for select
  using (space_id = app.current_space_id());
create policy "subjects_authenticated_write" on public.subjects
  for all to authenticated
  using (true) with check (true);

-- guardians
create policy "guardians_select_space" on public.guardians
  for select
  using (space_id = app.current_space_id());
create policy "guardians_authenticated_write" on public.guardians
  for all to authenticated
  using (true) with check (true);

-- subject_guardians
create policy "subject_guardians_select_space" on public.subject_guardians
  for select
  using (space_id = app.current_space_id());
create policy "subject_guardians_authenticated_write" on public.subject_guardians
  for all to authenticated
  using (true) with check (true);

-- attendance_records
create policy "attendance_select_space" on public.attendance_records
  for select
  using (space_id = app.current_space_id());
create policy "attendance_authenticated_write" on public.attendance_records
  for all to authenticated
  using (true) with check (true);

-- invites
create policy "invites_select_space_or_self" on public.invites
  for select
  using (
    space_id = app.current_space_id()
    or (email = (select email from auth.users where id = auth.uid()))
  );
create policy "invites_authenticated_write" on public.invites
  for all to authenticated
  using (true) with check (true);

-- ---------------------------------------------------------------------------
-- 11. Recreate the powersync publication with the renamed tables (plus
--     the new invites table).
-- ---------------------------------------------------------------------------
create publication powersync for table
  public.spaces,
  public.members,
  public.groups,
  public.enrollments,
  public.subjects,
  public.guardians,
  public.subject_guardians,
  public.attendance_records,
  public.invites;
