-- Attendance is a (subject, date) fact: at most one row per child per day.
--
-- The PowerSync connector already upserts attendance on the natural key
-- (subject_id, date) — see `_naturalKeyByTable` in
-- lib/core/sync/supabase_connector.dart — but the matching unique index was
-- never created. So `INSERT ... ON CONFLICT (subject_id, date)` had no target,
-- and two devices marking the same child concurrently (each with its own local
-- uuid) could land TWO rows for the same kid+day — an accountability gap the
-- day-flow pressure-test (Red Team #7) surfaced.
--
-- This adds the missing index, after de-duplicating any existing collisions.

-- 1) De-duplicate: keep the most-recently-updated row per (subject_id, date),
--    delete the rest. The (updated_at, id) tuple gives a deterministic winner
--    even when two rows share an updated_at.
delete from public.attendance_records a
using public.attendance_records b
where a.subject_id = b.subject_id
  and a.date = b.date
  and a.id <> b.id
  and (coalesce(a.updated_at, 'epoch'::timestamptz), a.id)
    < (coalesce(b.updated_at, 'epoch'::timestamptz), b.id);

-- 2) Enforce the natural key the connector relies on. `if not exists` keeps
--    this safe to re-run and a no-op if the index was ever added by hand.
create unique index if not exists attendance_records_subject_date_key
  on public.attendance_records (subject_id, date);
