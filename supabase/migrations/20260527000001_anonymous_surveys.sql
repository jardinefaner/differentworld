-- Different World — Wave 138
-- Surveys go fully anonymous.
--
-- Before this wave: every survey response was keyed on a specific
-- subject_id, so the director picked the kid first and the survey
-- was attributed to them ("Emma's BASECamp survey"). That's PII the
-- audience for survey data doesn't need — a state coordinator
-- looking at trends across the program needs "7-9 age band, 2nd
-- grade, Lincoln Elementary," not "Emma." Wave 135 added the three
-- anonymized identity columns; this wave finishes the job by
-- dropping the subject linkage entirely.
--
-- Behavior changes:
--  * `subject_id` becomes nullable. New anonymous responses leave it
--    NULL; legacy rows get scrubbed to NULL too (we preserve their
--    answer data, just drop the kid attribution).
--  * No more uniqueness-by-(subject, template). Each "Start" creates
--    a brand-new row (no resume). The PK on `id` remains the only
--    uniqueness constraint.
--  * The survey-take flow generates the response id client-side at
--    initState (the same offline-write pattern every other table
--    uses), so we don't need DEFAULT gen_random_uuid() on the column.

-- 1. Drop the NOT NULL constraint so new anonymous rows can land AND
--    so the UPDATE below is allowed.
alter table public.survey_responses
  alter column subject_id drop not null;

-- 2. Anonymize legacy data. Keeps the answers + identity capture but
--    breaks the link to the kid's row. This is the "migrate / delete
--    old named responses" path — we keep the data for the table view,
--    just without the kid name. A director who wants to wipe them
--    entirely can run a DELETE manually.
update public.survey_responses
   set subject_id = null
 where subject_id is not null;

-- The publication + replica identity + RLS policies are unchanged —
-- `space_id` is still the gate, and that's still NOT NULL.
