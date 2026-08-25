-- Stop syncing the legacy `enrollments` table (docs/ROOMS.md).
--
-- `enrollments` is the ORIGINAL staff↔classroom join from the foundation
-- migration. It was superseded by `group_members`, which carries the same
-- relationship plus a per-room role and an assigned-at stamp, and which is
-- the only one the app actually reads.
--
-- The legacy table is now pure weight: PowerSync downloads every row to
-- every device, the local schema creates a table for them, and no Dart code
-- has ever queried it — there is not even a Drift class. It also cost a
-- failed migration, by colliding with a new table that reused the name.
--
-- DELIBERATELY NOT DROPPED. It may hold historical staff assignments that
-- predate `group_members`, and dropping it is irreversible while removing
-- it from the publication is not. This takes it off the wire and off every
-- device; the rows stay on the server for anyone who needs to look. If it
-- is ever confirmed empty or fully superseded, dropping it is a one-line
-- follow-up.

alter publication powersync drop table public.enrollments;
