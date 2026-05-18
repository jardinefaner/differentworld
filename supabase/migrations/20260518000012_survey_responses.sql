-- ---------------------------------------------------------------------------
-- survey_responses: one row per (subject, survey-template) pair. Each
-- survey itself (the question list) is an app-defined template — see
-- `lib/features/surveys/survey_templates.dart`. The DB only stores the
-- *response* a kid gave, keyed by template_id + question_key.
--
-- Why not a `surveys` / `survey_questions` table:
--   v1 surveys are program-wide instruments authored by us (BASECamp
--   2025-26 to start). The director isn't building a question editor
--   yet. If that's ever a feature, the template moves to a row and
--   `template_id` becomes a foreign key; until then a Dart class is
--   the right shape and zero migration cost.
--
-- Status lifecycle: 'draft' (started, partial answers) → 'completed'
-- (every question answered, submit tapped). A kid can re-open a draft
-- across sessions because the answers JSONB persists at write time.
-- ---------------------------------------------------------------------------

create table if not exists public.survey_responses (
  id              uuid primary key default gen_random_uuid(),
  space_id        uuid not null references public.spaces(id) on delete cascade,

  -- Template identity: a stable string like 'basecamp_2025_26' that
  -- the Dart-side template registry maps to a question list.
  template_id     text not null,

  -- The kid taking the survey. One response per (subject, template);
  -- unique constraint enforces this.
  subject_id      uuid not null references public.subjects(id) on delete cascade,

  -- Lifecycle. 'draft' rows hold partial answers; 'completed' rows
  -- are submitted and shouldn't be edited (UI gates this).
  status          text not null default 'draft'
                    check (status in ('draft', 'completed')),

  -- The teacher who administered the survey — the kid points at
  -- smileys, the instructor taps. Audit + accountability.
  recorded_by     uuid references public.members(id),

  -- Answer payload: { "<question_key>": <value> } where value shape
  -- depends on the question kind:
  --   agree3:      0 | 1 | 2  (disagree / kind-of / agree)
  --   multiselect: ["opt_key", ...]  (subset of the question's options)
  --   text:        "free-form string"
  answers         jsonb not null default '{}'::jsonb,

  started_at      timestamptz not null default now(),
  completed_at    timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create unique index if not exists survey_responses_subject_template_uniq
  on public.survey_responses(subject_id, template_id);

create index if not exists survey_responses_space_template_idx
  on public.survey_responses(space_id, template_id, status);

alter table public.survey_responses replica identity full;
alter table public.survey_responses enable row level security;

create policy "survey_responses_authenticated_all"
  on public.survey_responses
  for all to authenticated
  using (true) with check (true);

alter publication powersync add table public.survey_responses;
