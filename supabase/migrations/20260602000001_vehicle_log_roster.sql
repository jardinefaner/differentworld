-- ---------------------------------------------------------------------------
-- Roster column on vehicle_logs — the headcount (docs/VISION.md vehicle
-- safety ritual). Stores the boarded subject ids (JSON array) so a trip's
-- occupancy is recorded: pick who boards at check-out, tap each child off at
-- check-in. The count-to-zero pairs with the empty-cabin photo — the actual
-- hot-car prevention (the photo is proof; the name-by-name sweep is the act).
--
-- Nullable + NO server default ON PURPOSE: a `default` is a no-op over
-- PowerSync's local SQLite (the recurring footgun — see the schedule-status
-- bug in CLAUDE.md), so relying on it would yield NULL locally. The Dart
-- client ALWAYS sets `roster` explicitly (jsonEncode of the ids, or '[]') and
-- coalesces null → [] on read.
--
-- vehicle_logs already has replica identity full + RLS + the powersync
-- publication + the by_space sync rule (SELECT *), so no other server change
-- is needed — `SELECT *` picks up the new column automatically.
-- ---------------------------------------------------------------------------

alter table public.vehicle_logs
  add column if not exists roster text;
