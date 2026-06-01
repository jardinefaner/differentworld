-- Wave A — formless schedule create: free-text title on schedule blocks.
--
-- "Free text, link later": the inline-create flow (tap + → spotlight
-- card → type a name) needs somewhere to store that name. The card shows
-- `title` when set; an activity link (for color/defaults) can be attached
-- on the card afterward. Nullable so existing blocks — which derive their
-- display name from the linked activity or curriculum session — are
-- unaffected.
--
-- No publication / sync-rule / RLS change: schedule_blocks is already in
-- the powersync publication with `replica identity full`, and the
-- by_space sync rule selects *, so the new column rides along.
alter table public.schedule_blocks
  add column if not exists title text;
