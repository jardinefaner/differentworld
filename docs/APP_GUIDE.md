# Different World — what is here, how to find it, why it generalizes

> **Looking for something specific?** [docs/README.md](README.md) is
> the index of every doc in this folder + a "if you're asking X, open
> Y" lookup. Open it first if you don't know what to read.
>
> **Looking for roles, capabilities, abilities?** Jump to the
> [Quick reference: roles + bundle defaults](#quick-reference-roles--bundle-defaults)
> section below, or open the full catalog at
> [CAPABILITIES.md](CAPABILITIES.md). Typed string constants live in
> `lib/core/capabilities/capability_keys.dart`.

Two-part doc:

1. **What everything is, and how to find it** — a non-buried map of
   every feature, where it lives, and the multiple ways to reach
   it. Read this if you ever feel "I know we built X but I can't
   find the path."
2. **How this maps to any vertical** — the engine is domain-
   agnostic. The childcare labels (Program, Children, Classrooms)
   are a skin over a generic Space / Subject / Group model that
   maps cleanly to construction, healthcare, hospitality,
   manufacturing, and anything else with roles + capabilities.

---

## Part 1 — How the app works

### The five ways to navigate

The app has five paths to anywhere. If a feature feels buried, the
fix is usually wiring it into one of these, not building a new
screen.

| Path | Where | What it's for |
|---|---|---|
| **Omnibox composer (bottom bar)** | Bottom of every signed-in screen | The spine. Type anything → fuzzy-matches the catalog. Slash commands. Free-form text saves a capture. Mic dictates via Deepgram. |
| **Drawer (hamburger top-left)** | On every signed-in screen | 5 top-level destinations: Today, Schedule, Captures, Tasks, Settings. Plus a hero "Search anything" tile that opens the omnibox. |
| **Today's Quick Actions** | The horizontally-scrolling tile row on `/` | The 6–8 most-pressed verbs, sorted by urgency (state-driven tiles like "Return van" or "Inbox · 3" come first). |
| **Cards on Today** | Insights card, cohort cards, Now/Next strip | Tap-to-drill-in. The card knows what's relevant right now and links straight to the right surface. |
| **Deep links** | `differentworld://invite/...`, `https://differentworld.app/invite/...` | Cold-launch into a specific destination (invite acceptance is the only one wired today). |

### The chrome layer

The persistent app chrome sits ABOVE the page transitions so you're
always anchored. It's rendered by `AppShell` (in
`lib/shared/widgets/app_shell.dart`); per-screen `EdgeScaffold`
publishes its props into a stack-backed `routeChromeProvider`.

| Position | What | When |
|---|---|---|
| Top-left | **Hamburger** | Always, when signed in + not in kid mode |
| Top-left (right of hamburger) | **Back arrow** | When the navigator can pop (drill-in routes) |
| Top-right | **Action pill** | Per-screen actions (sync indicator, save, edit, share…) |
| Bottom | **Omnibox composer** | Always, when signed in + not in kid mode |

When you push a new route, only the page content slides — the
hamburger, back arrow, action pill, and bottom bar stay anchored.
Page transitions feel like a single surface that morphs, not a
stack of cards sliding around.

### The omnibox modes

The composer is multi-modal — it morphs based on what you're
typing. The detection function lives in
`lib/features/omnibox/omnibox_mode.dart`.

| Mode | Trigger | Bar tint | What Enter does |
|---|---|---|---|
| **Search** (default) | Anything that matches the catalog, or empty | Surface tint, magnifier | Open the top-scored result |
| **Capture** | Long free text with no catalog match | Primary tint (lightning bolt) | Save as a capture |
| **Slash** | Starts with `/` | Tertiary tint (chevron) | Exec the matched command |

#### Slash commands today

| Command | Aliases | What |
|---|---|---|
| `/today` | `/home` | Jump to the home landing |
| `/captures` | `/inbox` | Capture inbox |
| `/tasks` | — | Task list |
| `/insights` | — | Insights surface |
| `/review` | — | Walk-me-through review |
| `/schedule` | — | Week schedule |
| `/attendance {group}` | `/atd` | Resolve cohort name → attendance |
| `/log {kid}` | `/observe`, `/obs` | Resolve kid name → observation |
| `/checkout {vehicle}` | `/co` | Resolve vehicle name → checkout form |
| `/checkin {vehicle}` | `/ci`, `/return` | Resolve vehicle name → checkin form |

Adding a command: see `omnibox-modes` skill.

### Voice dictation

Tap the mic in the omnibox bar. Streams to Deepgram via WebSocket
(`wss://api.deepgram.com/v1/listen`, `nova-2` model, 16 kHz PCM mono,
linear16 encoding). Interim transcripts update the composer in
real time; final segments commit on stop. Tap-mic-again to end.

Requirements:
- `DEEPGRAM_API_KEY` in `.env`
- `RECORD_AUDIO` (Android) / `NSMicrophoneUsageDescription` (iOS) —
  already wired
- Native only — `dart:io WebSocket` doesn't exist on web; the mic
  surfaces a "not available in the browser yet" snackbar there

### Kid mode

For surfaces a kid uses directly (today: `/surveys/:templateId/take/:subjectId`;
future: kid-journal). When on:

- Omnibox bar hidden
- Top chrome (back, hamburger, actions) hidden
- Drawer set to null (swipe-from-edge does nothing)
- System back is intercepted — refuses to pop without a staff
  unlock gesture

Staff exit: tap the top-right corner of the kid surface five
times within 1.5 s. A snackbar confirms "Unlocked. Press back to
exit." Once unlocked, normal pop works.

### Feature index — where everything lives

Grouped by what a user is trying to do.

#### Daily operations

| Verb | Where to find it | What it is |
|---|---|---|
| Drop a quick note mid-day | Bottom omnibox → type → save as capture | Free-form note. Triage later from the inbox. |
| Log a structured observation | Today → "New observation" tile, or `/log {kid}` | Attached to a kid + cohort + kind, photo + body. |
| Take attendance | Today → cohort card → "Take attendance", or `/attendance {group}` | Per-cohort roster with status pills. |
| Plan the week | Today → drawer → Schedule, or `/schedule` | Per-cohort time blocks with activities + locations. |
| Check out a vehicle | Today → "Check out a vehicle" tile, or `/checkout {name}` | Pre-trip inspection + driver assignment. |
| Return a vehicle | Today → "Return {van}" tile (only when out), or `/checkin {name}` | Post-trip inspection + close the log. |
| Run a survey for a kid | Today → "Surveys" tile, then pick template + kid | Locks into kid mode for the duration. |

#### Triage & review

| Verb | Where | What |
|---|---|---|
| See what needs attention | Today → top of screen (TopInsightCard) | The single highest-severity insight; "see all" peeks to full list. |
| Walk through everything | Today → "Walk me through" (when ≥ 2 insights), or `/review` | Step-by-step insight review. |
| Process the inbox | Today → "Inbox · N" tile (when N > 0) | Promote captures to observations or tasks; discard. |
| See all open tasks | Today → "Tasks · N" tile (when N > 0) | Grouped by due. |
| See all observations | Today → "Observations" tile, or omnibox "observations" | Reverse-chronological feed across all cohorts. |

#### Admin (director-only)

| Verb | Where | What |
|---|---|---|
| Invite staff | Drawer → Settings → Team → "Invite" | Mints a code-share invite or email invite. |
| Add a cohort / classroom | Today → swipe drawer → Settings → Schedule library or omnibox "add a classroom" | New Group row. |
| Edit a kid | Omnibox → type kid's name → tap → "Edit" | Subject detail screen. |
| Manage activities catalog | Omnibox → "activities" | Pool, archery, art — what kids can do in a schedule block. |
| Manage locations catalog | Omnibox → "locations" | Pool, art barn — where activities happen. |
| Manage vehicles | Today → "Fleet" tile (director without canDrive), or omnibox "vehicles" | Fleet roster. |

#### Account / settings

| Verb | Where |
|---|---|
| Sign in | Land on `/login` automatically when signed out |
| Sign out | Drawer → top profile card → logout icon |
| Change text size | Drawer → Settings → Preferences → Text size |
| Switch program (future) | Drawer → header → program switcher (not yet built) |

### When you feel like something is "buried"

The triage:

1. **Can you type the noun?** Open the omnibox, type a fragment of
   the thing's name (a kid, a cohort, a vehicle, a location). If
   it doesn't surface, the catalog needs an entry — see
   `omnibox-modes` skill.
2. **Can you type the verb as a slash command?** If `/checkout`
   exists but `/whatever-you-want` doesn't, that's a missing
   command — add to `slash_commands.dart`.
3. **Does it deserve a Today Quick Action tile?** Quick actions
   are for the 6–8 most-pressed verbs. Adding a 9th pushes the
   8th off-screen — only promote if it's daily-use AND
   state-driven.
4. **Is it a top-level destination?** If you'd want to land on it
   from a cold app launch, it belongs in the drawer (currently
   5 entries — adding a 6th is a real decision).

If none of those four are right, the feature might be misplaced —
flag it and we redesign the IA.

---

## Part 2 — How this generalizes beyond classroom programs

The engine doesn't know it's a classroom app. The schema, providers,
sync engine, omnibox, chrome, capability system, and routing are
all built around generic primitives. The childcare labels are a
skin on top.

### The five engine primitives

| Engine name | What it represents | Childcare label | Construction label | Healthcare clinic | Restaurant | Manufacturing |
|---|---|---|---|---|---|---|
| **Space** | The tenant org. One install = one space (with planned multi-space later). | Program | Company | Clinic | Restaurant | Plant |
| **Member** | A staff user. Has a role + a capabilities JSONB. | Staff | Foreman / Electrician / Apprentice / PM | Doctor / Nurse / Tech / Admin | Manager / Server / Cook / Host | Operator / Supervisor / QA |
| **Group** | A subdivision a member belongs to. | Classroom | Crew / Job site | Department / Shift | Section / Shift | Line / Shift |
| **Subject** | The "thing the work is about". The unit you observe, schedule against, attach photos to. | Child | Project (with line items) | Patient | Guest / Reservation | Work order / Unit |
| **Entry** | An atomic observation, status note, or event attached to a Subject. | Observation | Daily update / Status note / Incident | Chart note / Vitals | Order note / Allergy | Defect log / QC step |

The Drift schema literally uses `spaces`, `members`, `groups`,
`subjects`. Every UI string that says "Children" or "Classroom" is
domain-specific dressing.

### The capability system is the abstraction that makes this work

Every Member, Group, Subject, and Space carries a `capabilities`
JSONB column. Capabilities are typed string keys (no magic strings
in code — see `MemberCaps` / `GroupCaps` / etc. in
`lib/core/capabilities/capability_keys.dart`).

A role is just a SEED for capabilities. The same member can lose
or gain individual caps without changing role.

#### Quick reference: roles + bundle defaults

| Role | Caps seeded on invite |
|---|---|
| **director** | Every staff capability EXCEPT cert-gated ones (`canAdministerMedication`, `canDrive` stay false until a certification is added) |
| **lead_teacher** | `canObserve`, `canTakeAttendance`, all `canRecord*`, `canOpenBuilding`, `canCloseBuilding`, `canAuthorizePickup`, `canManageSchedule` |
| **teacher** | `canObserve`, `canTakeAttendance`, all `canRecord*`, `canManageSchedule` |
| **assistant** | `canTakeAttendance`, all `canRecord*` (no `canObserve`) |
| **guardian** | None of the staff caps. Family-side reads only. |

Roles live in the `public.member_role` enum (added via
migration `20260518000001_universal_rename.sql` + extended with
`'guardian'` in `20260519000004_member_role_guardian.sql`). The
bundle map is `RoleBundles.defaultsFor(role)` in
`lib/core/capabilities/capability_keys.dart`.

#### Quick reference: capability keys

##### Member (what a staff user can DO)

| Key | Gates |
|---|---|
| `canObserve` | Create observation entries |
| `canTakeAttendance` | Check kids in / out |
| `canRecordMeal` / `canRecordNap` / `canRecordDiaper` | Per-routine entry forms |
| `canAdministerMedication` | Medication-administered entries (cert-gated; stays false until member has a CPR/MAT certification on file) |
| `canDrive` | Vehicle check-in / check-out, slash commands `/checkout` `/checkin`, Today vehicle tile (cert-gated) |
| `canOpenBuilding` / `canCloseBuilding` | Building-access ops (key holders) |
| `canAuthorizePickup` | Edit a child's authorized pickup list |
| `canViewBilling` / `canViewAuditLog` | Director-only reads |
| `canInviteStaff` | Team screen + "Invite" action |
| `canActAsDirector` | Backup admin role (used when director is offsite) |
| `canManageSchedule` | Schedule editor (create/edit blocks) |
| `isSpecialist` | Narrow-scope staff (yoga, swim, archery); their Today screen defaults to "what am I leading" |

##### Group (what's tracked in this room / cohort)

| Key | Drives |
|---|---|
| `ageBand` | `infant` / `toddler` / `preschool` / `prek` / `mixed` — auto-derives the other GroupCaps |
| `tracksDiapers` / `tracksNaps` / `tracksMealsDetailed` / `tracksBottleFeeds` | Which logging forms appear for this group |
| `napSchedule` | `{start, end}` for nap-time prompts |
| `hasOutdoorTime` | Sun-safety reminders, weather card on Today |
| `hasFieldTrips` | Trips module toggle |
| `bilingualLanguages` | e.g. `['en', 'es']` for immersion rooms |

##### Subject (what's tracked for this individual child)

Mostly overrides Group defaults plus per-child fields. See
[CAPABILITIES.md](CAPABILITIES.md) for the full table — allergies,
medications, IEP notes, pickup-strict, photo consent, photo
visibility, comfort items, nap routine, transition notes.

##### Space (program-wide feature toggles)

| Key | Default | Controls |
|---|---|---|
| `feature_observations` | true | Observation capture UI + sync rule for observations |
| `feature_medication_log` | false | Medication entries + `canAdministerMedication` |
| `feature_field_trips` | false | Trips module + permission slips + `canDrive` |
| `feature_meal_logging` / `feature_nap_logging` / `feature_diaper_logging` | varies | Per-routine logging |
| `feature_incident_reports` | true | Incident-report entries + parent notification |
| `feature_family_login` | false | Family-facing UI for guardians (v2+) |
| `feature_billing` | false | Billing module (later) |
| `pickup_window_start` / `pickup_window_end` | `15:00` / `18:00` | "Pickup soon" / "Late pickup" prompts |
| `state_compliance` | `'none'` | One of `none` / `CA` / `NY` / `TX` / … — drives state-specific reports |
| `photo_default_consent` | false | Default for `Subject.photo_consent` on new enrollments |

#### How the gates compose

For each cap, the UI gates by `viewer.can(MemberCaps.foo)`. The
viewer abstraction (`viewerProvider`) makes screens never compare
`member.role == 'director'` directly — instead they check the cap
that the role would seed. **Any layer can veto**: Space → Member →
Group → Subject. If `Space.feature_medication_log == false`, no
member sees the medication UI even with `canAdministerMedication`.

Full catalog with defaults + per-key UI surface + runtime check
patterns: [CAPABILITIES.md](CAPABILITIES.md). The typed string
constants for every key live in
`lib/core/capabilities/capability_keys.dart`.

### Maps to other verticals

#### Construction / trades

| Engine | Construction |
|---|---|
| Space | The construction company |
| Member roles | Owner, PM, Foreman, Journeyman, Apprentice, Subcontractor |
| Groups | Crews and/or job sites |
| Subjects | Projects (with their own life cycle) — OR the unit being built (a house, a unit, a tower floor) |
| Entries | Daily progress notes, incident reports, change orders, RFI notes |
| Surveys | Toolbox-talk attendance, safety audits, daily JHA |
| Vehicles | Trucks, generators, lifts — the fleet check-in/out + pre-trip inspection works identically |
| Attendance | Site check-in (who's onsite, who's on which crew today) |
| Captures | Photo + voice note from a foreman: "Found this defect on east elevation — taking pic." Triaged later into observations / RFIs / change orders. |
| Capabilities | `canAuthorizePO` / `canApproveRFI` / `canCloseTicket` / `canSubmitTimesheet` / `canSignSafetyDoc` |
| Insights | "Crew X has missed safety briefings this week", "PO threshold exceeded" |

The kid-mode equivalent: **a tablet kiosk handed to a sub-contractor
who needs to sign in for site access**. Locks the device into the
safety-briefing-acknowledge surface; staff PIN unlocks.

#### Healthcare / clinic

| Engine | Healthcare |
|---|---|
| Space | The clinic / practice |
| Member roles | Physician, NP, RN, Tech, MA, Admin |
| Groups | Departments / shifts / care teams |
| Subjects | Patients |
| Entries | Chart notes, vitals, med admin events |
| Surveys | Intake forms, PHQ-9 / GAD-7, satisfaction surveys |
| Vehicles | Mobile clinic vans (rural health) or just absent |
| Attendance | Staff sign-in for shift coverage |
| Captures | Quick voice note between patients ("Mr. Lee said hip still bothering him") — Deepgram dictation is the killer feature here |
| Capabilities | `canPrescribe` / `canSignOrders` / `canViewPHI` / `canBillEncounter` / `canAdministerControlledSub` |
| Kid mode | A patient-facing intake tablet — patient fills the survey, can't escape to staff routes; nurse uses the corner-tap exit |

#### Hospitality / restaurant

| Engine | Restaurant |
|---|---|
| Space | The restaurant |
| Member roles | GM, Manager, Server, Bartender, Cook, Host, Busser |
| Groups | Sections / shifts |
| Subjects | Guests / reservations (or tables, depending on model) |
| Entries | Order notes, allergy notes, comp memos |
| Surveys | Guest satisfaction post-meal |
| Vehicles | Delivery vehicles for caterers; otherwise absent |
| Capabilities | `canVoid` / `canComp` / `canApplyDiscount` / `canCloseDrawer` / `canAccessLiquorRoom` |
| Insights | "Server X has highest comp rate this week — review?" |

#### Manufacturing

| Engine | Manufacturing |
|---|---|
| Space | The plant |
| Member roles | Operator, Lead, Supervisor, QA, Maintenance |
| Groups | Lines / shifts / cells |
| Subjects | Work orders (or production units, or batches) |
| Entries | Defect logs, QC step results, downtime notes |
| Surveys | Safety/lockout-tagout acknowledgements |
| Vehicles | Forklifts, AGVs |
| Capabilities | `canPerformLOTO` / `canOverrideQC` / `canSignFirstArticle` / `canRunMachine_X` |

### What changes when you re-skin for a new vertical

The work is bounded. Three layers:

1. **UI labels** — every string that says "Children" / "Classrooms"
   / "Program" / etc. Today these are hard-coded; for a multi-
   vertical product they'd resolve through a `VerticalLabels`
   provider keyed off `Space.vertical` (a column to be added).
   Implementation: a `Map<VerticalKey, Labels>` constant +
   `labelsProvider`; widgets read `labels.subjectPlural` instead
   of "Children".
2. **Capability vocabulary** — the keys + role bundles in
   `capability_keys.dart`. Construction needs `canAuthorizePO`,
   not `canRecordDiaper`. Make these vertical-conditional too —
   a `MemberCaps.bundleFor(vertical, role)`.
3. **Per-vertical screens** — most ops surfaces (omnibox,
   captures, observations, schedule, vehicles, attendance, surveys,
   insights, exports) are domain-agnostic and need no per-vertical
   build. The exceptions:
   - Childcare-specific: meal / nap / diaper logs, age-band caps
   - Construction-specific: PO approval, RFI tracker, photo log
     with location metadata
   - Healthcare-specific: med admin, chart, vitals
   - These belong in vertical-specific feature folders behind a
     vertical gate.

The engine — Drift schema, PowerSync sync rules, RLS policies,
omnibox infrastructure, chrome stack, kid mode, voice — **does not
change**. That's the load-bearing point.

### Why this matters as a product

What you actually built is "the operations spine for a small team
working with subjects under capability-gated roles." Childcare is
the launch vertical because it's the one closest to home and the
one where omnibox + capture + capability-driven UI are
unambiguously useful. But the same spine is the right shape for
any team that:

- Has 3–20 staff with role differences
- Works ON repeated subjects (kids, patients, projects, guests,
  work orders)
- Needs offline-first because the work happens away from desks
- Has a regulator or audit consumer downstream
- Has roles that gate what the UI lets you see / do

That's a large addressable surface. Childcare is a beachhead.
Construction is probably the second-best fit (also offline-first,
also regulated, also has fleet + sites + scheduled crews + safety
forms). Healthcare and hospitality come after.

### Roadmap suggestion (not committed)

If you wanted to take the vertical-config thing seriously:

1. Add `vertical text not null default 'childcare'` to
   `public.spaces`.
2. Add a typed `Vertical` enum + a `VerticalLabels` map.
3. Audit every hardcoded "Children" / "Classroom" / "Program"
   string — about 30–50 across the app per a grep. Replace with
   `ref.watch(verticalLabelsProvider).subjectPlural` etc.
4. Add a `VerticalConfig` provider that exposes which features are
   ON for that vertical (e.g. construction has `vehicles=true`,
   `meals=false`).
5. Repeat the role-bundle work in `capability_keys.dart` to
   produce per-vertical defaults.

That's 2–4 days of dedicated work. The reward is one binary that
sells to multiple verticals with config flips.

---

## Where this doc fits

- `docs/SCREEN_QA_MATRIX.md` — what each screen MUST show in each
  state (per-screen testing checklist)
- `docs/APP_GUIDE.md` (this file) — what the app IS and how it
  generalizes (architectural + product layer)
- `CLAUDE.md` — the agent runbook + gotchas (engineering layer)
- `.claude/skills/index/SKILL.md` — catalog of every prescriptive
  pattern (style + scaffolding layer)

If you only have time to read one of these and you want the user-
facing surface, read this one. If you're implementing a screen,
read `new-screen` then this. If you're debugging weird behavior,
start with CLAUDE.md's "Known gotchas."
