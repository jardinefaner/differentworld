-- Different World — Foundation migration
-- Tables: programs, profiles, classrooms, enrollments
-- Pattern: every table carries program_id so RLS is a single comparison
-- and PowerSync sync rules can bucket by program without joins.

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- Shared trigger: bump updated_at on every UPDATE.
-- ---------------------------------------------------------------------------
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- programs — one program per install in v1, but modeled as a table so multi-
-- program is a non-breaking change later.
-- ---------------------------------------------------------------------------
create table public.programs (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  slug        text unique,
  settings    jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create trigger programs_touch_updated_at
  before update on public.programs
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- profiles — extends auth.users. program_id is the membership claim.
-- role drives write permissions.
-- ---------------------------------------------------------------------------
create type public.staff_role as enum (
  'director',
  'lead_teacher',
  'teacher',
  'assistant'
);

create table public.profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  program_id   uuid references public.programs(id) on delete set null,
  display_name text not null,
  role         public.staff_role not null default 'teacher',
  avatar_url   text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index profiles_program_id_idx on public.profiles(program_id);

create trigger profiles_touch_updated_at
  before update on public.profiles
  for each row execute function public.touch_updated_at();

-- Auto-create a profile row when a new auth user signs up.
-- display_name falls back to email local-part; program_id stays null until
-- the user either creates a program or accepts an invite.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1))
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- classrooms
-- ---------------------------------------------------------------------------
create table public.classrooms (
  id          uuid primary key default gen_random_uuid(),
  program_id  uuid not null references public.programs(id) on delete cascade,
  name        text not null,
  age_range   text,
  color       text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index classrooms_program_id_idx on public.classrooms(program_id);

create trigger classrooms_touch_updated_at
  before update on public.classrooms
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- enrollments — staff ↔ classroom (many-to-many, with optional per-room role)
-- ---------------------------------------------------------------------------
create table public.enrollments (
  id            uuid primary key default gen_random_uuid(),
  profile_id    uuid not null references public.profiles(id) on delete cascade,
  classroom_id  uuid not null references public.classrooms(id) on delete cascade,
  program_id    uuid not null references public.programs(id) on delete cascade,
  role          public.staff_role not null default 'teacher',
  created_at    timestamptz not null default now(),
  unique (profile_id, classroom_id)
);

create index enrollments_program_id_idx on public.enrollments(program_id);
create index enrollments_profile_id_idx on public.enrollments(profile_id);
create index enrollments_classroom_id_idx on public.enrollments(classroom_id);

-- ---------------------------------------------------------------------------
-- RLS — program-scoped reads for all staff, role-gated writes.
-- ---------------------------------------------------------------------------

-- Helper: program_id for the current user.
create or replace function public.current_program_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select program_id from public.profiles where id = auth.uid();
$$;

-- Helper: is the current user a director?
create or replace function public.is_director()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select role = 'director' from public.profiles where id = auth.uid()),
    false
  );
$$;

alter table public.programs    enable row level security;
alter table public.profiles    enable row level security;
alter table public.classrooms  enable row level security;
alter table public.enrollments enable row level security;

-- programs ---------------------------------------------------------------
create policy "programs_select_member"
  on public.programs for select
  using (id = public.current_program_id());

create policy "programs_insert_anyone"
  on public.programs for insert
  with check (auth.uid() is not null);
  -- Anyone authenticated can create a program; first action after signup.
  -- The matching profile.program_id update is done by the client.

create policy "programs_update_director"
  on public.programs for update
  using (id = public.current_program_id() and public.is_director());

-- profiles ---------------------------------------------------------------
create policy "profiles_select_same_program"
  on public.profiles for select
  using (
    program_id = public.current_program_id()
    or id = auth.uid()
  );

create policy "profiles_update_self_or_director"
  on public.profiles for update
  using (id = auth.uid() or public.is_director());

-- classrooms -------------------------------------------------------------
create policy "classrooms_select_program"
  on public.classrooms for select
  using (program_id = public.current_program_id());

create policy "classrooms_write_director_or_lead"
  on public.classrooms for all
  using (
    program_id = public.current_program_id()
    and (
      public.is_director()
      or exists (
        select 1 from public.profiles
        where id = auth.uid() and role = 'lead_teacher'
      )
    )
  )
  with check (program_id = public.current_program_id());

-- enrollments ------------------------------------------------------------
create policy "enrollments_select_program"
  on public.enrollments for select
  using (program_id = public.current_program_id());

create policy "enrollments_write_director"
  on public.enrollments for all
  using (program_id = public.current_program_id() and public.is_director())
  with check (program_id = public.current_program_id());
