-- Different World — Roster migration
-- Tables: students, guardians, student_guardians (M2M)

-- ---------------------------------------------------------------------------
-- students
-- ---------------------------------------------------------------------------
create table public.students (
  id            uuid primary key default gen_random_uuid(),
  program_id    uuid not null references public.programs(id) on delete cascade,
  classroom_id  uuid references public.classrooms(id) on delete set null,
  first_name    text not null,
  last_name     text not null,
  dob           date,
  photo_url     text,
  allergies     text,
  notes         text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index students_program_id_idx on public.students(program_id);
create index students_classroom_id_idx on public.students(classroom_id);

create trigger students_touch_updated_at
  before update on public.students
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- guardians — family members / authorized pickup contacts
-- ---------------------------------------------------------------------------
create table public.guardians (
  id                       uuid primary key default gen_random_uuid(),
  program_id               uuid not null references public.programs(id) on delete cascade,
  name                     text not null,
  relationship             text,
  phone                    text,
  email                    text,
  authorized_for_pickup    boolean not null default true,
  notes                    text,
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now()
);

create index guardians_program_id_idx on public.guardians(program_id);

create trigger guardians_touch_updated_at
  before update on public.guardians
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- student_guardians — many-to-many; program_id denormalized for RLS speed
-- ---------------------------------------------------------------------------
create table public.student_guardians (
  id           uuid primary key default gen_random_uuid(),
  student_id   uuid not null references public.students(id) on delete cascade,
  guardian_id  uuid not null references public.guardians(id) on delete cascade,
  program_id   uuid not null references public.programs(id) on delete cascade,
  is_primary   boolean not null default false,
  created_at   timestamptz not null default now(),
  unique (student_id, guardian_id)
);

create index student_guardians_program_id_idx on public.student_guardians(program_id);
create index student_guardians_student_id_idx on public.student_guardians(student_id);
create index student_guardians_guardian_id_idx on public.student_guardians(guardian_id);

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.students          enable row level security;
alter table public.guardians         enable row level security;
alter table public.student_guardians enable row level security;

-- Read: any staff member of the program.
-- Write: any staff member (roster updates are routine — not director-gated).

create policy "students_program_all"
  on public.students for all
  using (program_id = public.current_program_id())
  with check (program_id = public.current_program_id());

create policy "guardians_program_all"
  on public.guardians for all
  using (program_id = public.current_program_id())
  with check (program_id = public.current_program_id());

create policy "student_guardians_program_all"
  on public.student_guardians for all
  using (program_id = public.current_program_id())
  with check (program_id = public.current_program_id());
