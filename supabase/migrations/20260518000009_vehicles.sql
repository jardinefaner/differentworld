-- ---------------------------------------------------------------------------
-- vehicles + vehicle_logs: fleet management + pre/post-trip safety checks.
--
-- vehicles is a first-class space-scoped entity. Directors manage the
-- fleet (create / edit / delete). Anyone in the space can SEE the
-- vehicle list; only members with `can_drive` (a cert-gated capability,
-- see lib/core/capabilities/certifications.dart) can perform check-out
-- and check-in actions, which insert vehicle_logs rows.
--
-- vehicle_logs is the event stream — one row per check-out OR check-in.
-- A "trip" is the pair (checkout → checkin). Current state of a
-- vehicle is derived from the latest log row.
--
-- The FACES inspection checklist (lights, tires, gauges, leaks, etc.)
-- is stored in vehicle_logs.items as JSONB, with each item a tri-state:
--   "ok"           — driver checked it; safe to drive
--   "needs_repair" — flag for the next mechanic visit; vehicle still drives
--   "unsafe"       — DO NOT DRIVE; report immediately
-- ---------------------------------------------------------------------------

create table if not exists public.vehicles (
  id              uuid primary key default gen_random_uuid(),
  space_id        uuid not null references public.spaces(id) on delete cascade,

  -- Display name the driver sees ("Big Green Van", "Sprinter #2").
  -- Often duplicates the make/model but doesn't have to.
  name            text not null,

  -- Identifying details. All optional so a director can stub a vehicle
  -- with just a name and fill the rest later.
  make            text,
  model           text,
  year            int,
  license_plate   text,
  color           text,

  -- Photo of the vehicle (Storage path → signed URL; not synced).
  photo_url       text,

  -- Free-form notes (insurance contact, fuel card #, etc.).
  notes           text,

  -- Capabilities blob: fuel_type, max_passengers, has_lift, etc.
  -- Per docs/CAPABILITIES.md — typed accessors in Dart.
  capabilities    jsonb not null default '{}'::jsonb,

  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

alter table public.vehicles replica identity full;

create index if not exists vehicles_space_idx
  on public.vehicles(space_id, name);

alter table public.vehicles enable row level security;

create policy "vehicles_authenticated_all" on public.vehicles
  for all to authenticated
  using (true) with check (true);

alter publication powersync add table public.vehicles;


create table if not exists public.vehicle_logs (
  id                  uuid primary key default gen_random_uuid(),
  space_id            uuid not null references public.spaces(id) on delete cascade,
  vehicle_id          uuid not null references public.vehicles(id) on delete cascade,

  -- 'checkout' = driver taking the vehicle out (pre-trip inspection)
  -- 'checkin'  = driver returning the vehicle  (post-trip inspection)
  kind                text not null check (kind in ('checkout', 'checkin')),

  driver_member_id    uuid not null references public.members(id),

  -- Odometer reading at time of event (integer miles).
  odometer            int,

  -- Fuel level. Free-form so a driver can write "3/4", "F", "1/2 tank"
  -- without us prescribing a slider UI in v1.
  fuel_level          text,

  -- The FACES inspection results.
  -- Shape: {"lights": {"headlights": "ok", "brake": "needs_repair", ...},
  --         "tires":  {"inflated": "ok"},
  --         "gauges": {"fuel": "ok", "temp": "ok", "engine_service": "ok"},
  --         "leaks":  {"oil": "ok", "other": "ok"},
  --         "other":  {"windows_mirrors": "ok", "wipers": "ok",
  --                    "fans_defroster": "ok", "brakes": "ok",
  --                    "horn": "ok", "emergency_kit": "ok"},
  --         "interior": {"noises": "ok", "seat_belts": "ok"}}
  -- Each item is "ok" | "needs_repair" | "unsafe".
  items               jsonb not null default '{}'::jsonb,

  -- Free-form notes section on the FACES form.
  notes               text,

  -- Body damage notes (separate from generic notes — distinct field on
  -- the paper form too).
  body_damage_notes   text,

  created_at          timestamptz not null default now()
);

alter table public.vehicle_logs replica identity full;

create index if not exists vehicle_logs_vehicle_idx
  on public.vehicle_logs(vehicle_id, created_at desc);
create index if not exists vehicle_logs_driver_idx
  on public.vehicle_logs(driver_member_id, created_at desc);
create index if not exists vehicle_logs_space_idx
  on public.vehicle_logs(space_id, created_at desc);

alter table public.vehicle_logs enable row level security;

create policy "vehicle_logs_authenticated_all" on public.vehicle_logs
  for all to authenticated
  using (true) with check (true);

alter publication powersync add table public.vehicle_logs;
