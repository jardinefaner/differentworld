-- Different World — Wave 155
-- Schedule block status — let leads mark a block as skipped or
-- cancelled without deleting it. The block still appears on the
-- day view (dimmed) so the director can see what was planned but
-- not done, and the family lens can render an honest narrative
-- ("Outdoor play was cancelled because of rain").
--
-- Three states:
--   'planned'    — default. The block is happening as written.
--   'skipped'    — kid-side / staff didn't run the block today.
--                  Visual: dim. Don't count toward "blocks done"
--                  stats.
--   'cancelled'  — director cancelled the block (admin reason). Same
--                  visual treatment as skipped; semantically distinct
--                  for reporting later.
--
-- 'skipped' is the everyday button on the today view. 'cancelled'
-- is a director-level state you reach through the edit sheet.

alter table public.schedule_blocks
  add column if not exists status text not null default 'planned'
    check (status in ('planned', 'skipped', 'cancelled'));

-- Optional reason — free-text "rain," "low attendance," "guest
-- cancelled," etc. Surfaces on the family lens explanation.
alter table public.schedule_blocks
  add column if not exists status_reason text;
