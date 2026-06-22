-- ---------------------------------------------------------------------------
-- attachment tags — the per-child / who-shot-it / per-activity axes.
--
-- Today a photo is tagged ONLY by the polymorphic (entity_kind, entity_id)
-- owner + space_id, so "every photo Maya made" or "this block's photos" is an
-- N+1 walk through entries (and the photo-session/subject silos miss it).
--
-- Denormalize three nullable axes directly on the row — mirroring how
-- `entries` already carries subject_id + schedule_block_id side by side — so
-- each scope becomes a single-column query / index:
--   * subject_id              — the child the media is OF
--   * captured_by_subject_id  — the child who SHOT it (NEW: "they took these
--                               themselves" — the per-child timed photo turns)
--   * schedule_block_id       — the activity / block it came from (seam 3:
--                               a capture auto-associates with its block)
--
-- `on delete set null` — deleting a child or block UNSETS the tag, never
-- deletes the photo (a child's work outlives the schedule row). The
-- polymorphic owner is untouched, so all existing read sites keep working.
-- SELECT * sync rule picks the columns up; replica identity full already set.
-- ---------------------------------------------------------------------------

alter table public.attachments
  add column if not exists subject_id uuid
    references public.subjects(id) on delete set null,
  add column if not exists captured_by_subject_id uuid
    references public.subjects(id) on delete set null,
  add column if not exists schedule_block_id uuid
    references public.schedule_blocks(id) on delete set null;

-- Backfill: entry-owned photos inherit the entry's child + block.
update public.attachments a
set subject_id = e.subject_id
from public.entries e
where a.entity_kind = 'entry' and a.entity_id = e.id
  and a.subject_id is null and e.subject_id is not null;

update public.attachments a
set schedule_block_id = e.schedule_block_id
from public.entries e
where a.entity_kind = 'entry' and a.entity_id = e.id
  and a.schedule_block_id is null and e.schedule_block_id is not null;

-- subject-owned photos already name the child via entity_id.
update public.attachments a
set subject_id = a.entity_id
where a.entity_kind = 'subject' and a.subject_id is null;

-- Index each new query axis so the per-child folder / per-block package
-- watches don't full-scan the growing table (mirrors the entries indexes).
create index if not exists attachments_subject_idx
  on public.attachments(subject_id, created_at desc);
create index if not exists attachments_captured_by_idx
  on public.attachments(captured_by_subject_id, created_at desc);
create index if not exists attachments_block_idx
  on public.attachments(schedule_block_id, created_at desc);
