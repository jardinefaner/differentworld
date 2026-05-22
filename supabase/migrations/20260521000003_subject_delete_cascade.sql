-- ---------------------------------------------------------------------------
-- COPPA / right-to-deletion cleanup: tighten the two `subject_id` FKs
-- that were `on delete set null` to `on delete cascade`.
--
-- When a parent requests deletion of their child's data, the schema has
-- to make that complete. Today most subject_id FKs cascade correctly
-- (entries, attendance, messages, survey_responses, subject_guardians,
-- guardians, permission_slips). Two were inconsistent:
--
--   * `exports.subject_id` — an export is generated ABOUT one child.
--     Leaving an orphan export row (subject_id = NULL) after the child's
--     deletion keeps the snapshot text + recipient list + signed URLs
--     around, which is a privacy leak.
--
--   * `tasks.subject_id` — a subject-attached task is specifically about
--     that child. Leaving "(former child)" tasks around hints that data
--     existed and is operationally useless.
--
-- One column intentionally STAYS as set-null:
--   * `captures.promoted_subject_id` — captures' free-text bodies often
--     mention multiple children ("today Owen and Sam built…"). Deleting
--     the capture because of one of them would lose the other's data.
--     The per-subject promotion link severs; the row stays.
-- ---------------------------------------------------------------------------

alter table public.exports
  drop constraint if exists exports_subject_id_fkey;
alter table public.exports
  add constraint exports_subject_id_fkey
    foreign key (subject_id) references public.subjects(id)
    on delete cascade;

alter table public.tasks
  drop constraint if exists tasks_subject_id_fkey;
alter table public.tasks
  add constraint tasks_subject_id_fkey
    foreign key (subject_id) references public.subjects(id)
    on delete cascade;

-- Indexes for both — cascade on parent delete shouldn't trigger a scan.
create index if not exists exports_subject_id_idx
  on public.exports(subject_id);
create index if not exists tasks_subject_id_idx
  on public.tasks(subject_id);
