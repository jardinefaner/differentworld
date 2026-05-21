-- ---------------------------------------------------------------------------
-- Substitute lead handoff on schedule blocks.
--
-- Pat persona — a counselor calls out sick; the director wants a one-tap
-- "make X the lead for {Group} today" action. Adds a nullable
-- `lead_substitute_member_id` column to schedule_blocks so the original
-- planned lead survives for record-keeping while the substitute takes
-- over for the day.
--
-- Query semantics: "blocks I'm leading today" becomes
-- `COALESCE(lead_substitute_member_id, lead_member_id) = me`. The
-- substitute sees the absent person's blocks with a "Covering for X"
-- badge; the absent person's blocks no longer surface in their own
-- LeadingTodayCard (because they're not actually leading them today).
-- ---------------------------------------------------------------------------

alter table public.schedule_blocks
  add column if not exists lead_substitute_member_id uuid
    references public.members(id) on delete set null;

-- The query path is "for date D and group G, who's actually leading?"
-- which is already covered by the existing (space_id, date) indexes —
-- no additional index needed for this column.
