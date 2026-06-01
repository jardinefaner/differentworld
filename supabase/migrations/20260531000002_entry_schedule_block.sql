-- Live-block capture — the keystone column. See docs/LIVE_BLOCK_CONTEXT.md.
--
-- When a schedule block is live, captures/observations tie to it, so the
-- day self-assembles into a timeline of tagged moments. ONE nullable
-- link, on `entries` only — NOT on `attachments` (photos inherit via
-- entity_kind='entry') and NOT on `captures` (block lands at promote
-- time, keeping the inbox clean pre-triage).
--
-- Intentionally NO foreign key to schedule_blocks: the design rule is
-- "block cancelled/deleted → the entry KEEPS its (now-dangling) tag and
-- renders gracefully," which a hard FK (restrict / set null / cascade)
-- would all violate. Nullable so untagged moments (nothing live) stay
-- honest. No publication / sync-rule / RLS change — entries is already
-- replicated and by_space selects *.
alter table public.entries
  add column if not exists schedule_block_id uuid;
