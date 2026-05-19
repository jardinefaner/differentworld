-- ---------------------------------------------------------------------------
-- tasks: the third destination for a capture (and a first-class entity
-- in its own right).
--
-- Why a separate table from entries and captures: a task is *something
-- to do*, not something that happened (entries) or a thought waiting to
-- be triaged (captures). It has its own lifecycle:
--
--   open      → still to do
--   done      → completed (timestamp + completed_by tracked)
--   discarded → no longer worth doing (kept for audit, hidden from list)
--
-- A task may carry a subject_id when it's about a specific kid ("call
-- Bobby's mom about pickup"); subject-less tasks are program-level
-- ("reorder paint", "audit the medication log").
--
-- The capture→task promotion path is symmetric with the existing
-- capture→entry path: `captures.promoted_to_kind = 'task'` /
-- `promoted_to_id = tasks.id`. The Capture inbox's triage sheet
-- learns a third option; nothing else changes.
-- ---------------------------------------------------------------------------

create table if not exists public.tasks (
  id              uuid primary key default gen_random_uuid(),
  space_id        uuid not null references public.spaces(id) on delete cascade,

  -- Who created it. Nullable for former-staff-author parity with
  -- captures.
  author_id       uuid references public.members(id) on delete set null,

  -- Optional kid the task is about. Director-level tasks ("audit the
  -- medication log") leave this null.
  subject_id      uuid references public.subjects(id) on delete set null,

  -- The task itself. No length cap — sometimes a task is two
  -- paragraphs of context.
  body            text not null,

  -- Lifecycle.
  status          text not null default 'open'
                    check (status in ('open', 'done', 'discarded')),

  -- Optional due-by. Nullable means "no deadline".
  due_at          timestamptz,

  -- Who closed it + when. Both set together on completion.
  completed_by    uuid references public.members(id) on delete set null,
  completed_at    timestamptz,

  -- Where it came from, when promoted from a capture. Loose pointer
  -- (no FK to captures because the capture row may be discarded later
  -- without breaking the audit trail here).
  created_from_capture_id uuid,

  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- Open list, newest first — drives the tasks screen and the Today
-- launchpad's "open tasks" indicator.
create index if not exists tasks_space_status_due_idx
  on public.tasks (space_id, status, due_at nulls last, created_at desc);

-- Per-subject tasks (for the subject detail family-side surface).
create index if not exists tasks_subject_idx
  on public.tasks (subject_id, status) where subject_id is not null;

alter table public.tasks replica identity full;
alter table public.tasks enable row level security;

create policy "tasks_read_by_space"
  on public.tasks
  for select
  to authenticated
  using (
    space_id in (
      select space_id from public.members where id = auth.uid()
    )
  );

-- Write: relaxed per the CLAUDE.md ES256 / auth.uid() workaround. Same
-- pattern as the rest of the codebase. Re-tighten when JWT claims work.
create policy "tasks_insert_authenticated"
  on public.tasks
  for insert
  to authenticated
  with check (true);

create policy "tasks_update_authenticated"
  on public.tasks
  for update
  to authenticated
  using (true) with check (true);

create policy "tasks_delete_authenticated"
  on public.tasks
  for delete
  to authenticated
  using (true);

alter publication powersync add table public.tasks;
