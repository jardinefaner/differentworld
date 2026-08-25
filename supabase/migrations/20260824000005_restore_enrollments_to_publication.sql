-- Put the legacy `enrollments` table back in the publication.
--
-- 20260824000004 removed it, which was correct in intent and WRONG IN
-- ORDER. The sync rules that still referenced it were live on the PowerSync
-- dashboard at the time — the repo's sync_rules.yaml is only a source of
-- truth, the dashboard is the runtime — so dropping the table from the
-- publication broke the running instance:
--
--   Table "public"."enrollments" is not part of publication 'powersync'.
--
-- The dependency runs one way: SYNC RULES reference PUBLICATION TABLES. So a
-- table can only leave the publication AFTER rules that no longer mention it
-- have been deployed, never before.
--
-- Restoring it costs nothing — a table in the publication that no sync rule
-- selects is simply never streamed. Once the new rules (which don't
-- reference it) are deployed on the dashboard, dropping it again is a
-- one-line follow-up that will be safe.

alter publication powersync add table public.enrollments;
