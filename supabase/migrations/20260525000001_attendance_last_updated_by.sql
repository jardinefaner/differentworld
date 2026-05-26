-- Different World — Wave 105
-- Audit trail for attendance writes. Today the only author tracked on
-- attendance_records is `recorded_by` (set at first insert and never
-- updated). When two teachers race to mark Emma at 8:00, last-write-
-- wins is silent and unattributable — a regulated childcare program
-- can't tell who flipped Emma from absent to present.
--
-- New column `last_updated_by` carries the member who LAST wrote the
-- row. `recorded_by` keeps its meaning (original author). On the
-- attendance row, a footnote "Last updated by X · 2m ago" surfaces
-- only when last_updated_by differs from recorded_by (calm path stays
-- visually quiet).
--
-- Nullable on purpose: backfilling every existing row would require
-- inventing data. The UI gates the footnote on non-null.

alter table public.attendance_records
  add column if not exists last_updated_by uuid
    references public.members(id) on delete set null;

create index if not exists attendance_last_updated_by_idx
  on public.attendance_records(last_updated_by);

-- REPLICA IDENTITY FULL was set in the original migration, no change
-- needed — PowerSync picks up the new column automatically once the
-- sync rules redeploy.
