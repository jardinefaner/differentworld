-- Different World — Wave 135
-- Identity capture for survey responses, anonymized.
--
-- The survey table view (survey_table_screen) used to show kid first
-- + last name as the row label. For data review / export, that's PII
-- the director doesn't always need: a state coordinator looking at
-- trends across the program doesn't need "Emma" — they need "7-9
-- band, 2nd grade, Lincoln Elementary." So:
--
-- (1) survey_responses gets three new columns: age_band / grade /
--     school. Captured during the survey-take flow (after the voice
--     picker, before question 1).
-- (2) A per-program catalog of options for each dimension lives in
--     survey_picker_options. Director's first kid taking the
--     survey: the picker shows zero options; they tap "+" to add
--     "2nd grade." The option persists; the next kid sees it as a
--     pre-existing choice. Same shape across age band + school.

-- 1. New columns on the response row.
alter table public.survey_responses
  add column if not exists age_band text,
  add column if not exists grade text,
  add column if not exists school text;

-- 2. Per-program catalog of picker options. One row per (program,
--    dimension, label). The dimension column is constrained to the
--    three known kinds — adding a fourth (e.g. neighborhood) needs
--    a follow-up migration to extend the check.
create table if not exists public.survey_picker_options (
  id          uuid primary key default gen_random_uuid(),
  space_id    uuid not null references public.spaces(id) on delete cascade,
  dimension   text not null check (dimension in ('age_band','grade','school')),
  label       text not null,
  sort_order  int  not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (space_id, dimension, label)
);

create index if not exists survey_picker_options_space_dim_idx
  on public.survey_picker_options(space_id, dimension);

alter table public.survey_picker_options replica identity full;
alter publication powersync add table public.survey_picker_options;

alter table public.survey_picker_options enable row level security;

-- Relaxed-write policy matching the rest of the schema (see migration
-- 20260517000002): RLS gate is the `authenticated` GRANT, fine-grained
-- per-space checks return once auth.uid() is non-null in JWT claims.
create policy "survey_picker_options_all"
  on public.survey_picker_options for all
  to authenticated
  using (true)
  with check (true);

create trigger survey_picker_options_touch_updated_at
  before update on public.survey_picker_options
  for each row execute function public.touch_updated_at();
