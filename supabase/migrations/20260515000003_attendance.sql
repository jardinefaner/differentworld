-- Different World — Attendance migration
-- Daily attendance record per (student, date). Built first because it's the
-- highest-frequency offline write path and proves the whole sync stack.

create type public.attendance_status as enum (
  'present',
  'absent',
  'late',
  'early_pickup',
  'excused'
);

create table public.attendance_records (
  id           uuid primary key default gen_random_uuid(),
  program_id   uuid not null references public.programs(id) on delete cascade,
  classroom_id uuid references public.classrooms(id) on delete set null,
  student_id   uuid not null references public.students(id) on delete cascade,
  date         date not null,
  status       public.attendance_status not null default 'present',
  notes        text,
  recorded_by  uuid not null references public.profiles(id) on delete set null,
  recorded_at  timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (student_id, date)
);

create index attendance_program_id_idx on public.attendance_records(program_id);
create index attendance_classroom_date_idx
  on public.attendance_records(classroom_id, date);
create index attendance_date_idx on public.attendance_records(date);

create trigger attendance_touch_updated_at
  before update on public.attendance_records
  for each row execute function public.touch_updated_at();

alter table public.attendance_records enable row level security;

create policy "attendance_program_all"
  on public.attendance_records for all
  using (program_id = public.current_program_id())
  with check (program_id = public.current_program_id());
