-- Wave 165 — link schedule blocks to curriculum sessions.
--
-- A nullable text column carrying the curriculum session slug
-- (e.g. 'photo.s1.click-game'). When set, the schedule block is the
-- in-the-grid manifestation of that session: the block-edit screen
-- offers a deep-link back to the curriculum session detail, and the
-- schedule tiles show a small "Through My Eyes · Session N" badge so
-- staff can see at a glance that the block is part of a structured
-- program.
--
-- The slug is editorial; no FK to a database table (curricula are
-- shipped as Dart consts today, Wave 161/164 pattern). Wave 162-style
-- overrides will eventually wire slugs to a per-space table — at that
-- point this column will join that table.
--
-- The column is nullable + has no constraints: existing blocks keep
-- working unchanged, and removing a curriculum link is just nulling
-- the column.

alter table public.schedule_blocks
  add column if not exists curriculum_session_slug text;

comment on column public.schedule_blocks.curriculum_session_slug is
  'Optional: matching slug in the in-app curriculum catalog '
  '(e.g. photo.s1.click-game). NULL for ad-hoc blocks.';

-- No replica identity change needed — schedule_blocks is already
-- `replica identity full` from migration 20260518000003. New columns
-- on a full-replica table flow through PowerSync automatically once
-- the local schema picks them up.

-- No new policy needed — the column lives under the existing
-- schedule_blocks RLS contract (space-gated read, capability-gated
-- write).
