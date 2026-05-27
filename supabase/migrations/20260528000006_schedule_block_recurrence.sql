-- Wave 166.2 — link blocks spawned from the same "Repeat…" action
-- so future "edit all in series" / "delete all in series" affordances
-- can find them.
--
-- The column is the UUID of the FIRST block in the series. All blocks
-- spawned in the same batch carry the same value. NULL = ad-hoc
-- one-off block. No FK constraint — the "first block" may be deleted
-- later and the rest of the series should keep their grouping.
--
-- No new RLS / sync rule needed — the column rides the existing
-- schedule_blocks contract.

alter table public.schedule_blocks
  add column if not exists recurrence_id text;

comment on column public.schedule_blocks.recurrence_id is
  'UUID shared by all blocks spawned in one Repeat-creation batch. '
  'Null = ad-hoc one-off block.';
