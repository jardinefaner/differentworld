-- Take the legacy `enrollments` table off the wire — this time in order.
--
-- 20260824000004 tried this and broke the running instance, because the sync
-- rules referencing the table were still deployed on the dashboard;
-- 20260824000005 restored it. The correct order (now recorded in CLAUDE.md)
-- is one-way:
--
--   1. Edit sync_rules.yaml to stop referencing the table.   ✅
--   2. DEPLOY those rules on the PowerSync dashboard.        ✅ 2026-08-24
--   3. Then drop the table from the publication.             ← this migration
--
-- Step 2 is confirmed rather than assumed: the device's local database now
-- declares `terms`, `placements`, `rotation_rounds` and `room_events` and no
-- longer declares `enrollments`, which is only true of the new rules. So no
-- deployed rule references this table and dropping it streams nothing away.
--
-- The TABLE itself stays. It may hold staff assignments predating
-- `group_members`, and a drop is irreversible where this is not.

alter publication powersync drop table public.enrollments;
