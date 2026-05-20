-- ---------------------------------------------------------------------------
-- camp scheduling: activities, locations, schedule_blocks, field trips,
-- permission slips, headcounts, plus per-subject pickup/dropoff windows.
--
-- Designed for camp-style programs (ages 5-12) that rotate cohorts through
-- a sequence of activities by time block. Key design choices:
--
--   - Block boundaries are STORED PER ROW (start_at + end_at), not derived
--     from a global grid. Any staff can author blocks of any duration —
--     45 min, 60 min, 90 min, snack break of 15 min — at any time of day.
--     Nothing about "every block is N minutes" is encoded anywhere.
--
--   - Activities own themselves through `owner_member_id` — whoever
--     created or runs the activity. Specialists own their own activities;
--     general staff own theirs.
--
--   - Field trips are scheduled blocks with `kind = 'field_trip'` and a
--     side join to `trip_logistics` for destination + vehicles +
--     headcount checkpoints. Field-trip day-of-week is NOT encoded;
--     the director schedules them whenever they want.
--
--   - Pickup / dropoff windows live on `subjects` because each kid has
--     their own (some parents do 7:30 drop, some do 9; some pickup at
--     3, some at 6). No "camp opens 8a, closes 5p" constant anywhere.
--
--   - Capability `canManageSchedule` gates editing. Defaults true for
--     staff (set in the application layer / capability defaults) so
--     "teachers set the schedule" is the out-of-the-box behavior.
--     Directors can revoke per-person via the existing member detail UI.
-- ---------------------------------------------------------------------------


-- locations -----------------------------------------------------------------
--
-- Physical place an activity happens. Pool, art barn, archery range,
-- nature trail. Locations are reused across activities (the pool hosts
-- swimming AND water-balloon games), and they carry capacity so the
-- scheduler can warn when a cohort of 22 is booked into a 12-person
-- room.
--
-- Locations are space-scoped — every camp has its own physical layout.

create table if not exists public.locations (
  id           uuid primary key default gen_random_uuid(),
  space_id     uuid not null references public.spaces(id) on delete cascade,

  name         text not null,

  -- Free-form notes ("near the parking lot", "ring the bell before
  -- entering"). The scheduler shows this on the pre-block brief.
  notes        text,

  -- Capacity = headcount this location is comfortable with. NULL = unset.
  -- The scheduler warns (doesn't block) when a cohort exceeds capacity.
  capacity     int,

  -- Outdoor locations have weather contingency implications. The
  -- weather-pivot flow (out of scope for v1) will read this.
  is_outdoor   boolean not null default false,

  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

alter table public.locations replica identity full;

create index if not exists locations_space_idx
  on public.locations(space_id, name);

alter table public.locations enable row level security;

create policy "locations_authenticated_all" on public.locations
  for all to authenticated
  using (true) with check (true);

alter publication powersync add table public.locations;


-- activities ----------------------------------------------------------------
--
-- A defined thing a kid can do during a block: swimming, archery,
-- art project, nature walk. Created BY a staff member (the owner) —
-- camps build their own activity catalog rather than picking from a
-- predefined list. Activities are reusable across schedule blocks.
--
-- Age range, capacity, supplies, default duration are all OPTIONAL —
-- a teacher can stub "scavenger hunt" with just a name and fill the
-- rest later. The scheduler uses age_min/age_max + max_capacity to
-- warn (not block) when a cohort doesn't fit.

create table if not exists public.activities (
  id                        uuid primary key default gen_random_uuid(),
  space_id                  uuid not null references public.spaces(id) on delete cascade,

  -- The staff member who created / runs the activity. When scheduling
  -- a block with this activity, the lead defaults to the owner.
  owner_member_id           uuid references public.members(id) on delete set null,

  name                      text not null,

  -- One-paragraph description. Surfaces on the pre-block brief AND on
  -- the family-side schedule when a parent taps a block ("what is
  -- nature walk?").
  description               text,

  -- Default location — overridden per block when the activity moves.
  default_location_id       uuid references public.locations(id) on delete set null,

  -- Default block length the scheduler uses when the staff member
  -- adds this activity. Still overridable per block.
  default_duration_minutes  int,

  -- What to bring. Free-form so a teacher can write "swimsuit, towel,
  -- water bottle" without committing to a structured checklist UI.
  supplies                  text,

  -- Age band. NULL on either side = open.
  age_min                   int,
  age_max                   int,

  -- Max headcount. NULL = unconstrained.
  max_capacity              int,

  -- Outdoor activities feed the weather pivot.
  is_outdoor                boolean not null default false,

  -- Rain plan: the activity to fall back to when this one's weathered
  -- out. Self-referential so a teacher can chain ("swimming → board
  -- games"). NULL = "no rain plan, director decides on the day."
  indoor_alt_activity_id    uuid references public.activities(id) on delete set null,

  -- Capabilities blob: requires_lifeguard, requires_certs[], etc.
  -- Per docs/CAPABILITIES.md.
  capabilities              jsonb not null default '{}'::jsonb,

  -- Soft-archive: a director discontinuing an activity sets
  -- archived_at instead of deleting (preserves historical schedule
  -- rows that reference it).
  archived_at               timestamptz,

  created_at                timestamptz not null default now(),
  updated_at                timestamptz not null default now()
);

alter table public.activities replica identity full;

create index if not exists activities_space_idx
  on public.activities(space_id, name);
create index if not exists activities_space_active_idx
  on public.activities(space_id)
  where archived_at is null;

alter table public.activities enable row level security;

create policy "activities_authenticated_all" on public.activities
  for all to authenticated
  using (true) with check (true);

alter publication powersync add table public.activities;


-- schedule_blocks -----------------------------------------------------------
--
-- The day's plan, one row per (date × cohort × time block). Stored
-- per-row so different cohorts can have different block boundaries on
-- the same day, and so a single cohort can have varying block lengths
-- through the day (60 min swim, 30 min snack, 90 min field-trip prep).
--
-- The grain is per-cohort (`group_id`) per design — teachers said the
-- whole room moves together. Per-kid choice tables can be added later
-- without touching this schema.

create table if not exists public.schedule_blocks (
  id                        uuid primary key default gen_random_uuid(),
  space_id                  uuid not null references public.spaces(id) on delete cascade,

  -- The cohort this block applies to. The same activity at the same
  -- time appears as ONE block per cohort (so the four rooms swimming
  -- together at 9 a.m. produce four rows). That's intentional — it
  -- lets per-cohort attendance and headcount stay simple.
  group_id                  uuid not null references public.groups(id) on delete cascade,

  -- Local calendar date the block belongs to. We store this in
  -- addition to start_at so we can index by date cheaply and so
  -- "the day" stays unambiguous across DST etc.
  date                      date not null,

  -- Start/end in UTC. The UI renders in the program's local zone
  -- (Space.settings.timezone). Stored as timestamptz so DST is
  -- handled at the application boundary, not in SQL.
  start_at                  timestamptz not null,
  end_at                    timestamptz not null,

  -- The activity this block represents. NULL on a "structured break"
  -- (snack, transition, rest) where the activity doesn't matter; in
  -- that case `notes` carries the label ("Snack", "Bus loading").
  activity_id               uuid references public.activities(id) on delete set null,

  -- The staff member leading this block. NULL on unassigned (just
  -- being authored) or on a structured break.
  lead_member_id            uuid references public.members(id) on delete set null,

  -- Per-block location override. NULL falls back to
  -- activities.default_location_id.
  location_override_id      uuid references public.locations(id) on delete set null,

  -- 'on_site'    — normal in-camp activity
  -- 'field_trip' — joins to trip_logistics for destination + vehicles
  -- 'break'      — snack, lunch, rest; lead_member_id is whoever's
  --                supervising
  -- 'closed'     — camp is closed (holiday). No cohort assignment.
  kind                      text not null default 'on_site'
                              check (kind in ('on_site', 'field_trip',
                                              'break', 'closed')),

  -- Free-form notes shown on the staff schedule grid AND on the
  -- family-side schedule. "Bring closed-toe shoes" goes here.
  notes                     text,

  created_at                timestamptz not null default now(),
  updated_at                timestamptz not null default now()
);

alter table public.schedule_blocks replica identity full;

-- Two cohorts can't be in the same activity instance at the same time
-- on the same day — except when activity is null (breaks) or when the
-- block kind is field_trip (the trip object is what merges them).
-- We don't enforce this in SQL because the camp model allows two
-- rooms to legitimately be at the SAME activity but as separate
-- instances (two swim sessions running parallel at the pool with two
-- lifeguards). The scheduler UI shows soft warnings instead.

create index if not exists schedule_blocks_space_date_idx
  on public.schedule_blocks(space_id, date);
create index if not exists schedule_blocks_group_date_idx
  on public.schedule_blocks(group_id, date);
create index if not exists schedule_blocks_lead_date_idx
  on public.schedule_blocks(lead_member_id, date)
  where lead_member_id is not null;

alter table public.schedule_blocks enable row level security;

create policy "schedule_blocks_authenticated_all" on public.schedule_blocks
  for all to authenticated
  using (true) with check (true);

alter publication powersync add table public.schedule_blocks;


-- trip_logistics ------------------------------------------------------------
--
-- One-to-one with a schedule_block whose kind = 'field_trip'. Carries
-- the off-site coordination: destination, transport, headcount
-- checkpoints. We split this from schedule_blocks because the trip
-- columns would be null on 99% of blocks (every on-site activity).

create table if not exists public.trip_logistics (
  id                        uuid primary key default gen_random_uuid(),
  space_id                  uuid not null references public.spaces(id) on delete cascade,

  -- The block this trip belongs to. UNIQUE — one trip per block.
  -- (A multi-cohort field trip generates MULTIPLE schedule_blocks
  -- pointing at the same destination at the same time; each block
  -- has its own trip_logistics row so per-cohort headcounts are
  -- independent.)
  schedule_block_id         uuid not null unique
                              references public.schedule_blocks(id) on delete cascade,

  destination               text not null,

  -- Free-form address; the parent inbox surfaces it as a map link
  -- when present.
  destination_address       text,

  -- Departure / return — usually but not always equal to the block's
  -- start_at / end_at. A trip might start "loading the bus" 15 min
  -- before the block and end after.
  departure_at              timestamptz,
  return_at                 timestamptz,

  -- Whether parents must sign a permission slip before kids can go.
  -- Some camps require slips for all trips; some only for trips that
  -- leave town. The director sets it per trip.
  requires_permission_slip  boolean not null default true,

  -- Free-form text shown on the staff brief AND on the family inbox
  -- ("Bring closed-toe shoes; lunch provided; expected return 4 pm").
  notes                     text,

  created_at                timestamptz not null default now(),
  updated_at                timestamptz not null default now()
);

alter table public.trip_logistics replica identity full;

create index if not exists trip_logistics_space_idx
  on public.trip_logistics(space_id);

alter table public.trip_logistics enable row level security;

create policy "trip_logistics_authenticated_all" on public.trip_logistics
  for all to authenticated
  using (true) with check (true);

alter publication powersync add table public.trip_logistics;


-- trip_vehicles -------------------------------------------------------------
--
-- Which vehicles are assigned to a trip. A trip with one bus has one
-- row; a trip with two vans has two. Each row carries the driver
-- (a member with the can_drive cert) and optional seat assignments
-- expressed as a comma-separated list of subject ids — granular
-- enough to print a roster, not so structured that we have to model
-- seats individually.

create table if not exists public.trip_vehicles (
  id                  uuid primary key default gen_random_uuid(),
  space_id            uuid not null references public.spaces(id) on delete cascade,

  trip_logistics_id   uuid not null references public.trip_logistics(id) on delete cascade,
  vehicle_id          uuid not null references public.vehicles(id),
  driver_member_id    uuid references public.members(id),

  -- The kids assigned to THIS vehicle, as a JSONB array of subject
  -- ids. Order may matter (bus seat order); we preserve insertion
  -- order via JSONB array semantics. NULL / [] = no manifest yet.
  manifest            jsonb not null default '[]'::jsonb,

  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

alter table public.trip_vehicles replica identity full;

create index if not exists trip_vehicles_trip_idx
  on public.trip_vehicles(trip_logistics_id);

alter table public.trip_vehicles enable row level security;

create policy "trip_vehicles_authenticated_all" on public.trip_vehicles
  for all to authenticated
  using (true) with check (true);

alter publication powersync add table public.trip_vehicles;


-- permission_slips ----------------------------------------------------------
--
-- A guardian's signed assent for one kid on one trip. We DO NOT
-- attempt to replace paper packets in v1 — most camps collect signed
-- forms at enrollment. We just TRACK whether a slip is on file for
-- a given (subject, trip) pair so the staff brief shows red on kids
-- who can't go.
--
-- For camps that want digital sign-off later, this table is already
-- shaped for it (the application can let the guardian "sign" by
-- tapping a confirm button that writes signed_at).

create table if not exists public.permission_slips (
  id                  uuid primary key default gen_random_uuid(),
  space_id            uuid not null references public.spaces(id) on delete cascade,

  subject_id          uuid not null references public.subjects(id) on delete cascade,
  trip_logistics_id   uuid not null references public.trip_logistics(id) on delete cascade,

  -- Who signed. NULL if signed on paper (signer_name carries the
  -- written-in name); otherwise a guardian row.
  signer_guardian_id  uuid references public.guardians(id) on delete set null,
  signer_name         text,

  signed_at           timestamptz not null default now(),

  -- Optional source pointer (URL of scanned signature page, etc.).
  source_url          text,

  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

alter table public.permission_slips replica identity full;

-- One slip per (subject, trip).
create unique index if not exists permission_slips_subject_trip_uidx
  on public.permission_slips(subject_id, trip_logistics_id);

alter table public.permission_slips enable row level security;

create policy "permission_slips_authenticated_all" on public.permission_slips
  for all to authenticated
  using (true) with check (true);

alter publication powersync add table public.permission_slips;


-- headcounts ----------------------------------------------------------------
--
-- A counted-snapshot at a transition point. For field trips: take a
-- count at "leaving base", "arrived destination", "leaving
-- destination", "back at base". For on-site activities with stricter
-- ratios (water, archery), take a count at the block boundary.
--
-- The point isn't the count itself — it's the audit trail. If a kid
-- went missing between the zoo gate and the bus, the headcount row
-- tells you exactly when.
--
-- We do NOT model "which kids were present" per checkpoint — the count
-- is the integer; the per-kid attendance lives in attendance_records.

create table if not exists public.headcounts (
  id                  uuid primary key default gen_random_uuid(),
  space_id            uuid not null references public.spaces(id) on delete cascade,

  schedule_block_id   uuid not null references public.schedule_blocks(id) on delete cascade,

  -- Free-form checkpoint label so camps can use their own vocabulary:
  -- "leaving base", "at the gate", "back at the bus". The director
  -- can also pre-stage a list per trip in trip_logistics.notes.
  checkpoint_label    text not null,

  count               int not null check (count >= 0),

  -- Expected count at this checkpoint — the manifest size. Helps the
  -- UI render "12/12 ✓" vs "11/12 ⚠".
  expected_count      int,

  taken_by_member_id  uuid references public.members(id),
  taken_at            timestamptz not null default now(),

  notes               text,

  created_at          timestamptz not null default now()
);

alter table public.headcounts replica identity full;

create index if not exists headcounts_block_idx
  on public.headcounts(schedule_block_id, taken_at);

alter table public.headcounts enable row level security;

create policy "headcounts_authenticated_all" on public.headcounts
  for all to authenticated
  using (true) with check (true);

alter publication powersync add table public.headcounts;


-- subjects: pickup/dropoff windows ------------------------------------------
--
-- Per-kid drop-off and pickup windows. Stored as time-of-day (no
-- date), assumed local to the program's timezone. Some kids arrive
-- at 7:30, some at 9; some pickup at 3, some at 6. The family-side
-- schedule renders these on each kid's row.

alter table public.subjects
  add column if not exists dropoff_window_start time,
  add column if not exists dropoff_window_end   time,
  add column if not exists pickup_window_start  time,
  add column if not exists pickup_window_end    time;
