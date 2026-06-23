-- Field-trip maps + location, slice 1 (plumbing only, no UI).
--
-- Adds the coordinate columns the embedded OpenStreetMap (flutter_map)
-- + the "we are here" live pin will read/write. Two coordinate pairs:
--
--   destination_*  — the trip's DESTINATION pin, set once at prep time
--                    from the typed address (on-device geocoder) or a
--                    manual map tap. Powers "Get directions" + the map
--                    marker for where the group is HEADED.
--
--   pinned_*       — the group's LIVE "we are here" pin, dropped by a
--                    staffer on the trip from the device's GPS. Updated
--                    repeatedly during the trip; pinned_at is the moment
--                    of the last drop so the family/staff map can show
--                    "last seen 4 min ago".
--
-- All nullable: a trip has no coordinates until prep (destination) or
-- until the group pins itself (live). double precision matches LatLng's
-- doubles; on the local SQLite side these map to REAL (destination_*,
-- pinned_lat/lng) and TEXT (pinned_at, an ISO-8601 string).
--
-- trip_logistics already has `replica identity full`, is in the
-- powersync publication, and the by_space sync rule is `SELECT *` — so
-- adding columns needs only this ALTER; no publication / sync-rule /
-- dashboard change. (Local devices DO need a storage wipe to pick up
-- the new local-schema columns — see the slice report.)

alter table public.trip_logistics
  add column if not exists destination_lat double precision,
  add column if not exists destination_lng double precision,
  add column if not exists pinned_lat      double precision,
  add column if not exists pinned_lng      double precision,
  add column if not exists pinned_at       timestamptz;
