# Different World — agent guidance

Context for any AI assistant working on this codebase. Optimized for the
non-obvious — things that'd take a turn to rediscover.

**This is a living doc.** Any time we burn a turn on a non-obvious gotcha
or settle a convention, append it here so the next session inherits the
lesson. Better to bloat slightly than to re-discover. New gotchas go in
the "Known gotchas" section; new conventions go in "Cross-cutting
standards"; permission/workflow grants go in "Tooling permissions
granted".

---

## What the app is

Offline-first classroom planning + logging for **early-childhood program
staff** (directors, lead teachers, teachers, assistants). Each install
runs one program with many classrooms, shared automatically with every
teacher on the team. Children's data is sensitive PII — every decision
that touches it should reflect that.

**The dream behind it lives in [docs/VISION.md](docs/VISION.md)** — the
*why* this exists, in the user's own words, kept as a living document.
Read it to understand what we're building toward before the *how*. When
the user voices a new dream, it lands there the same turn.

**Primary product context (2026-05): afterschool program for ages 4-12.**
Decisions about labels, age bands, default group capabilities, activity
catalogs, and pickup rules should optimize for this segment first. Other
segments (infant care, full-day preschool, K-12 enrichment) are
supported by the same vertical-agnostic engine, but the defaults should
feel right for an afterschool director on day one.

Targets: **mobile-first** (iOS/iPad/Android), plus web + macOS/Windows/Linux.
A single codebase serves all six.

## Universal naming convention

**The engine is domain-agnostic; the UI is domain-specific.** Core
structural names are **Space / Member / Subject / Group / Entry**
(see [docs/NAMING.md](docs/NAMING.md) for the contract). Classroom-
specific labels — Program, Staff, Child, Classroom, Attendance —
live only in UI strings.

Schema and Dart-side rename done in migration
`20260518000001_universal_rename.sql`:

| Generic engine | Was (domain) |
|---|---|
| `spaces` | `programs` |
| `members` | `profiles` |
| `groups` | `classrooms` |
| `subjects` | `students` |
| `subject_guardians` | `student_guardians` |
| `space_id` | `program_id` (everywhere) |
| `group_id` | `classroom_id` |
| `subject_id` | `student_id` |
| `member_id` | `profile_id` |
| `member_role` (enum) | `staff_role` |
| `app.current_space_id()` | `app.current_program_id()` |

Drift classes: `Space`, `Member`, `Group`, `Subject`,
`AttendanceRecord`. Feature folders: `lib/features/groups/`,
`subjects/`, `attendance/`. Routes: `/groups/:id`,
`/groups/:id/attendance`.

`attendance_records` table kept (only columns renamed) — it's the
fast path for attendance; new Entry kinds will use the unified
`entries` table when we add it.

Capabilities (`jsonb` column on spaces / members / groups /
subjects) and invites (`public.invites` + `app.accept_invite()`)
were also added in that migration. UI for editing them is deferred.

---

## Stack

| Layer | Choice |
|---|---|
| UI | Flutter, Material 3 |
| State | Riverpod 3 — plain `Provider`/`Notifier` (no `riverpod_generator`; see Gotchas) |
| Routing | go_router with auth-aware redirect |
| Backend | Supabase (Postgres + RLS + Storage + Auth) |
| Sync | PowerSync — bidirectional Supabase ↔ local SQLite |
| Local DB | Drift over the *same* SQLite that PowerSync owns |
| Models | freezed + json_serializable for non-Drift domain models |

**Auth is Google OAuth only.** No email/password, no magic links, no OTP.
Mobile uses custom scheme `com.jardine.differentworld://login-callback`.

**Bundle ID is `com.jardine.differentworld`** across every platform folder.
Don't reintroduce `com.example`.

---

## Architecture invariants

These five rules are load-bearing — break them and the offline guarantees,
performance, or correctness suffer. Treat them as inviolate.

### 1. Local-first reads, local-first writes

**The local SQLite is the source of truth for the UI.** Never query
Supabase directly from a widget, provider, or repository. Reads come from
Drift; writes go through Drift; PowerSync handles the round-trip in the
background.

- ✅ `ref.watch(currentProfileProvider)` → `db.watchProfile(id)`
- ❌ `await supabase.from('profiles').select()` from UI code

The only places that talk to Supabase directly are:
- [lib/core/sync/supabase_connector.dart](lib/core/sync/supabase_connector.dart) — PowerSync's upload callback.
- Auth (`supabase.auth.signInWithOAuth`) — PowerSync doesn't manage it.
- [lib/core/db/drift_provider.dart](lib/core/db/drift_provider.dart) — two
  documented PostgREST fallbacks for the guardian + child-roster
  reads that prime the family viewer (the `by_guardian` PowerSync
  stream is the canonical path; the fallback covers cold-launch on a
  fresh device before the stream delivers its first batch).
- [lib/features/family/family_providers.dart](lib/features/family/family_providers.dart) —
  per-subject family reads (subjects / attendance / entries /
  attachments) — see the "Family lens" gotcha section for the
  2-level-subquery deferral.
- [lib/features/photos/person_photo_url.dart](lib/features/photos/person_photo_url.dart) +
  [lib/features/exports/signed_export_url.dart](lib/features/exports/signed_export_url.dart) —
  signed-URL minting for Storage assets (binary media doesn't
  ride PowerSync; see "Binary media never goes through
  PowerSync").
- [lib/features/photos/photo_service.dart](lib/features/photos/photo_service.dart) +
  [lib/features/photos/photo_upload_queue.dart](lib/features/photos/photo_upload_queue.dart) +
  [lib/features/exports/exports_providers.dart](lib/features/exports/exports_providers.dart) —
  Storage uploads for person photos + exported PDFs (same binary-
  media exception).
- [lib/features/live_session/live_session.dart](lib/features/live_session/live_session.dart) —
  Supabase **Realtime** channels (`client.channel(...)`, broadcast +
  presence) for the present/control layer (docs/LIVE_SESSIONS.md). This
  is **ephemeral coordination** (which slide is up, a join code), NOT
  durable child data — it deliberately does NOT go through PowerSync, the
  same way auth doesn't. No row is read or written here; nothing persists.

Any other `Supabase.instance.client.from(...)` /
`.storage.from(...)` call from UI / providers / repositories is a
bug — route the read through Drift or the appropriate fallback
provider, and route the binary upload through the photo / export
helpers above. (Realtime `.channel(...)` is the one allowed
non-Drift live surface — for coordination only, never data.)

**Writes are optimistic.** A user tap commits to local SQLite in one frame
and the UI reflects it immediately. PowerSync uploads later. Never `await`
a network round-trip in a user-facing handler.

### 2. Every synced table carries `program_id`

RLS policies and PowerSync stream queries gate on a single column
comparison. Joins inside RLS are slow; subqueries in sync rules get ugly;
single-column comparisons are conflict-free.

### Helper functions live in the `app` schema, not `public`

`public.current_program_id()`, `public.is_director()`, and
`public.handle_new_user()` were moved to `app` in migration 5. Reason:
PostgREST auto-exposes every function in schemas listed in its `db.schemas`
config (default: `public`) at `/rest/v1/rpc/<name>`. We can't simply
revoke EXECUTE from `authenticated` because RLS policies need to call
these — that'd cause an "infinite recursion" error or worse, break all
data access. Putting them in `app` keeps them callable from policies
while invisible to the REST API.

Rules for adding a new `SECURITY DEFINER` helper:
- Put it in `app`, not `public`.
- Lock its search_path: `SET search_path = ''` and fully qualify every
  identifier inside (e.g. `public.profiles`, not just `profiles`).
- `GRANT EXECUTE ON FUNCTION app.<name>() TO authenticated;` so RLS can
  call it.
- Reference it from policies as `app.<name>()`.

### 3. Adding a synced table touches **six** places

Miss any and the table silently won't sync — or its mutators will clog
the AppDatabase root, violating the DAO pattern below.

1. **Migration SQL** (`supabase/migrations/<ts>_<name>.sql`): create
   the table with `space_id uuid not null references public.spaces(id)`,
   add `alter table public.<name> replica identity full;`, add RLS
   policies.
2. **Publication**: `alter publication powersync add table public.<name>;`
3. **Sync rules** (`supabase/sync_rules.yaml`): add a `SELECT * FROM
   <name> WHERE space_id IN (SELECT space_id FROM members WHERE id =
   auth.user_id())` line to the `by_space` stream, **redeploy on the
   PowerSync dashboard** (the YAML file in the repo is just a source
   of truth — the dashboard is the runtime).
4. **PowerSync local schema** (`lib/core/db/power_sync_schema.dart`):
   add `Table('<name>', [Column.text('col'), …])`. Don't declare `id`.
   **If the table will GROW (entries, attendance, logs) and the DAO
   watches it with `WHERE <owner> … ORDER BY <ts> DESC`, add `indexes:`**
   — one `Index('<t>_<owner>', [IndexedColumn('<owner>'),
   IndexedColumn.descending('<ts>')])` per query shape. With none, every
   stream emission full-scans + sorts the whole table locally (the cost
   that bit `entries` / `attendance_records`). Indexes are
   non-destructive — they build on the next launch over existing rows, no
   re-sync / wipe. See the entries/attendance blocks for the pattern.
5. **Drift Table class** (`lib/core/db/app_database.dart`): add
   `class <Name>s extends Table { … }`, add to
   `@DriftDatabase(tables: […], daos: […])`. **Mutators do NOT go here
   anymore — they live in the DAO** (next step).
6. **DAO** (`lib/core/db/dao/<name>_dao.dart`): one file per feature
   domain, owns the watch / find / create / update_ / delete methods
   for that entity. Register on `@DriftDatabase(daos:)`. Run
   `dart run build_runner build`. See the `split-dao` skill for the
   full template, naming conventions, and the `update_` trailing-
   underscore convention.

Call sites read `db.<noun>Dao.<verb>(...)` — e.g.
`db.capturesDao.watchOpen(spaceId)`, `db.entriesDao.create(...)`.

### 3a. Adding a new top-level feature touches **four more places**

The six-place checklist above is for the DATA. The FEATURE also has
discoverability surfaces that have to be wired or users can never
find it. Every time we've forgotten one, the feature shipped as a
"hidden page only accessible via deep link from this one card" —
which is the same as not shipping it.

**This is now enforced by the `feature-mapper` agent (see the Feature
registry section below).** The agent watches the four places listed
below and emits a "Discovery drift" warning when a feature's claimed
surfaces in `docs/FEATURES.md` don't match what's actually wired in
code. The rule used to live in your head; now it's an automated
check. Keep reading for what the four places are — you still need to
wire them — but the **audit is no longer manual**.

When a new screen lands at a new top-level route, update:

1. **Routes** (`lib/app/router.dart`): nest the route(s) so deep
   links work + the back stack is right. Don't put a top-level page
   under `/settings/...` unless it's actually a settings sub-page.
2. **Omnibox** (`lib/features/omnibox/omnibox_results.dart`): add a
   `_Suggestion` per screen / action. **Mirror existing patterns**:
   gate by capability when the destination is gated; emit per-cohort
   "Schedule · {Group.name}" variants where the feature has a
   per-cohort shape; include broad keywords (`'field trip', 'pool',
   'barn'`) so users discover via what they actually call the thing.
3. **Nav destinations** (`lib/shared/widgets/nav_destinations.dart`):
   if it's a top-level destination (Today, Schedule, Captures, Tasks…),
   add ONE `NavDestination` to `buildNavDestinations`. Both the mobile
   `MainDrawer` AND the `DesktopNavRail` render from this single list —
   editing one surface directly is the anti-pattern that let the two
   drift (the drawer was missing Observations / Insights / Surveys /
   Vehicles for ages). Capability gates go in `onlyFor:`; a trailing
   badge count goes in `countProvider:`; a section break goes in
   `dividerBefore:` (drawer renders it as whitespace, rail as a
   `Divider`). If it's a "library" surface (Activities, Locations) it
   belongs under Settings, not the nav list.
   - **Drawer-length guardrail (regressed twice — once on the nav-slim,
     once when the cockpit reorg rehomed `YourToolsStrip` there):**
     anything you add to the drawer's scroll body goes in a **collapsed
     `CollapsibleSection`**, NEVER a flat list of tiles. The drawer must
     land on the short daily spine + collapsed group headers; a flat
     cluster (even a "nice" role palette) re-creates the 16-item wall the
     slim fixed. One header row until tapped — that's the rule.
4. **Settings entries** (`lib/features/settings/settings_screen.dart`):
   any settings-section route gets a `ListTile` row in the right
   `_SettingsGroup`. Group new rows with adjacent ones — don't add a
   new group for one item.

Then **claim those surfaces in `docs/FEATURES.md`** under the feature's
section (Routes / Omnibox / Slash / Drawer / Settings fields). The
`feature-mapper` agent will verify the wiring on its next run; if you
claim a drawer entry that doesn't exist, the agent flags it as drift.

Anti-pattern this prevents (we've shipped it twice): adding a
fully-built screen and forgetting one of the four surfaces, so the
only way to reach it is a deep link from one other screen that
already happens to know about it. Users never find it.

Cross-table transactions (e.g. `createSpaceForMember` which writes
spaces + members in one transaction) live on `AppDatabase`.

### 4. IDs are uuid server-side, text client-side

Always generate with `const Uuid().v4()` in Dart before insert. Offline
writes need stable PKs that survive the eventual sync. Never let Postgres
assign IDs after the fact — sync would have to rewrite them.

### 5. Type mapping: Postgres → local SQLite

PowerSync's local SQLite only has TEXT, INTEGER, REAL.

| Postgres | Local schema | Notes |
|---|---|---|
| `uuid` PK | implicit `id` TEXT | PowerSync adds it; don't declare |
| `text` / `varchar` | `Column.text` | |
| `boolean` | `Column.integer` | 0/1 |
| `date` / `timestamptz` | `Column.text` | ISO 8601 string |
| `jsonb` | `Column.text` | raw JSON string; parse client-side |
| `int` / `float` | `Column.integer` / `Column.real` | |

---

## Feature registry

The app is bigger than a single mental model can hold. Two living docs
keep the map fresh, and three agents maintain + query them.

### The docs

- **[docs/VISION.md](docs/VISION.md)** — the *why*: a living document of
  what the user dreams this app to be, in their own words. Not a feature
  list — the north star the features serve. New dreams land here the
  same turn they're spoken. **Authoritative for intent.**
- **[docs/PRIMITIVES.md](docs/PRIMITIVES.md)** — the *what it's made of*:
  the eleven atoms every feature decomposes into (Verb, Three, Pick,
  Reveal, Wall, Book, Circle, Timer, Question, Name, Scale), each grounded
  in its real code construct AND its UI/UX design law. **Authoritative for
  architecture.** When adding a feature, check it's expressible as a
  combination of these eleven; needing a twelfth is a signal, not a
  default. A screen that obeys the eleven laws feels like the system.
- **[docs/BRAND.md](docs/BRAND.md)** — the *how it shows up*: positioning
  (book, not ledger — Brightwheel is the foil), the calm-host
  personality, the five visual laws, voice, the Mobbin reference set,
  and where each is mechanically enforced. **Authoritative for
  identity.** A screen that violates it is a defect, not taste.
- **[docs/VERTICALS.md](docs/VERTICALS.md)** — the *where else it fits*:
  the two axes of portability. The ENGINE (Space/Member/Group/Subject/
  Entry) re-skins to five operational verticals (childcare / construction
  / healthcare / hospitality / manufacturing — the `verticalLabelsProvider`
  switch is LIVE; a picker + curriculum-gate are the gaps). The EXPERIENCE
  (the eleven primitives + bundled content) re-skins to human-development
  contexts (teams / elders / families / therapy / camps). Childcare is the
  first content pack, not the ceiling.
- **[docs/FEATURES.md](docs/FEATURES.md)** — folder-grained list of
  every feature in `lib/features/`. Each entry has a fixed shape:
  purpose, personas served, discovery surfaces (routes / omnibox /
  slash / drawer / settings), capabilities required, data tables
  touched, surface sublist, depends-on / consumed-by, last-verified
  date. **Authoritative for what the user can see.**
- **[docs/SCHEMA.md](docs/SCHEMA.md)** — table-grained list of every
  synced Drift table. Each entry: purpose, key columns, RLS gist,
  sync rule, consumer features. **Authoritative for what the data
  layer looks like.** Cross-linked bidirectionally with FEATURES.md
  (the `**Data:**` field in FEATURES = the `**Consumers:**` field in
  SCHEMA).

Both docs are written in a fixed schema (see headers in each file).
Don't invent new fields — propose them if you need them.

### The agents

- **`feature-mapper`** — maintains both docs. Auto-invoke when files
  under `lib/features/`, `lib/app/router.dart`,
  `omnibox_results.dart`, `omnibox_catalog.dart`, `main_drawer.dart`,
  `settings_screen.dart`, or `supabase/migrations/` change. Includes
  the **teeth-bearing check**: it verifies a feature's CLAIMED
  discovery surfaces (omnibox / drawer / settings / routes) match
  what the code wires; mismatches surface as "Discovery drift"
  warnings. Replaces the manual "four-places-to-wire" audit (the
  rule still applies; the check is now automated).
- **`blast-radius`** — on-demand. Takes a feature name, file path,
  table, column, capability, persona, or route, and returns the
  impact zone: upstream dependencies, downstream consumers, discovery
  surfaces touched, data graph, personas affected, what to test
  before shipping a change. Run BEFORE non-trivial edits.
- **`persona-audit`** — on-demand. Reads FEATURES.md and reports
  coverage by persona. Surfaces gaps the feature-by-feature view
  can't see (e.g., "Lauren has no entry point to today's photos").
  Run weekly or after major feature waves.

### Keeping the registries current — per WAVE, not per session

`docs/FEATURES.md`, `docs/SCHEMA.md` and `gallery/README.md` are only
authoritative if they are true. All three went stale in one long session
(SCHEMA.md by seven weeks, the component bible by five months), and the
reason is worth knowing:

**There is now a checker with teeth** — run it any time:

```sh
scripts/check_registries.sh    # exit 0 = registries match the code
```

It diffs the Drift table classes against `docs/SCHEMA.md`'s sections, the
feature folders against `docs/FEATURES.md`'s, and the gallery's claimed
plate counts against what is on disk — and NAMES what is missing.

`feature-registry-stop-gate.sh` runs it before you stop (rewritten
2026-08-24). It used to nag once per session and be satisfied by merely
TOUCHING the docs, which is how months of drift accumulated underneath it.
Now it stays SILENT when the checker passes, blocks with the actual gap list
when it does not, and re-arms on every commit — both its sentinels are keyed
to HEAD, and a commit that touches a trigger path counts as a trigger, so
each wave gets exactly one check.

**The hook is GLOBAL, so its scope is deliberate.** A project with no
`docs/FEATURES.md` is untouched. A project that has one but no
`scripts/check_registries.sh` keeps the gentler once-per-session behaviour —
per-commit re-arming is earned by having a checker that can name a real gap,
not granted by default, because a timestamp guess repeated every commit is
noise wearing a badge. To give a new project the teeth, copy
`scripts/check_registries.sh`; it no-ops on whichever of the three checks
that repo lacks.

The rule the tooling now enforces:

- **Update the registries in the same wave as the code**, alongside the
  commit — not at the end of the session, and never on the assumption that
  the hook will catch it.
- **A new synced table** gets a `docs/SCHEMA.md` section in the same commit
  as its migration. A **changed column** on an existing table gets its bullet
  updated (`subjects.status` and `groups.status` were both missed this way).
- **A new shared widget** gets a `gallery/README.md` row and a plate in the
  same wave. A component with no plate is invisible to the gallery-critic.
- **Never restate a completeness claim you have not just verified.** The
  bible claimed "ALL CATALOGUED" while six widgets had no plate; SCHEMA.md's
  counts were wrong by three. Prefer a command that re-derives the number
  over a number someone has to trust.

Feature widgets are NOT in the bible by design — but when one gains its
second consumer outside its own feature it is a promotion candidate, and by
its third it is overdue. `PersonPhotoNetwork` (14 consumers) and
`PhotoViewer` (8) are both overdue; the queue lives in `gallery/README.md`.

### The workflow

When you ADD a feature:
1. Wire the four discovery surfaces (router / omnibox / drawer /
   settings) as before. The rule above hasn't changed.
2. Claim those surfaces in `docs/FEATURES.md` under the new feature's
   section. If you skip this, the next `feature-mapper` run will add
   a stub that says `**Purpose**: TODO — please describe.` and flag
   it in the report.
3. Run `Agent feature-mapper` (or wait for the stop-hook to do it).

When you CHANGE a feature:
1. Run `Agent blast-radius <feature-or-file>` to see what else moves.
2. Make the change.
3. The `feature-mapper` will pick up the change on the next run.

When you ASK "is X served":
- Run `Agent persona-audit`.

### What the rule changes

- The old four-places audit was manual: `grep // UX_DECISIONS §7`
  and check by hand. **That's gone.** The teeth-bearing check is now
  in `feature-mapper`.
- `docs/FEATURES.md` is the single source of truth for "what exists."
  Drawer / omnibox / settings entries are derived facts the agent
  reconciles against.

### Curricula — a session is a runnable, castable deck

The Through-My-Eyes curriculum is authored as a **beat-by-beat runnable deck**,
not prose:

- **Model:** `lib/features/curricula/session_script.dart` —
  `SessionScript` / `SessionBeat` / `ScriptLine` / `BeatGame` / `BeatKind`.
- **Content:** `photo_s1..s6_script.dart` (the 6 sessions). Every say-line is
  **VERBATIM — editorial, do NOT paraphrase** when touching these.
- **Registry:** `session_scripts.dart` — `allSessionScripts` +
  `scriptForSession(slug)`. Adding a session = one new data file + one
  `allSessionScripts` entry; **zero presenter changes.**
- **Runner:** `SessionRunScreen` (`/session/run?slug=&block=`) runs it; per-beat
  tools (cast / review / capture / start-shooting / notify) reuse existing flows.
- **Casting law:** casting shows the **ROOM** a kid-facing deck via
  `sessionRoomSlides`, drawn **ONLY** from structured fields
  (`keyLines` / `game` / `vocab` / `callResponse`) — **NEVER** the script's
  `say` / `cue` lines, so the teacher's script never reaches the TV.

---

## Cross-cutting standards

How to build any new feature so it ages well.

### Offline-first behavior

The app must **never show an "offline" error state** to a user trying to
read or write. Offline is the default condition, not an exception.

- **Reads**: Drift streams. If the local DB hasn't synced the data yet,
  show a skeleton/spinner labeled with what's loading (e.g. "Syncing your
  classrooms…"), not an error.
- **Writes**: optimistic. Commit locally, queue upload, move on. If
  PowerSync upload fails (RLS rejection, schema mismatch), surface it via
  a non-blocking banner — but the local write stays put.
- **Sync indicator** in the AppBar is the *only* place online/offline
  state is exposed to the user. Everywhere else, the app behaves the
  same online or off.

### Data efficiency / sync scope

PowerSync downloads everything in the `by_program` stream on first sync.
With years of attendance/observation history, this grows. Strategies:

- **Time-window everything that grows**: attendance, observations, pickup
  logs should be filtered to "this term" or "last 90 days" by default in
  the sync rule. Older data lives in a separate opt-in stream the user
  pulls only when viewing history.
- **Avoid wide tables**: keep heavy fields (long notes, structured JSON)
  in side tables with their own sync window. A row in a list view should
  be small.

### Binary media never goes through PowerSync

**PowerSync's data budget is for text and numbers only.** Photos, and
later videos/audio if we ever add them, take a parallel path through
Supabase Storage. Violating this rule means we'd pay PowerSync to ship
megabytes per row.

The rule: **the synced row carries a URL or path string; the bytes live
in Supabase Storage.**

Photo flow:
- **Upload** (teacher takes a photo):
  1. Compress bytes to ~1 MB target (`image` package).
  2. `supabase.storage.from('student-photos').upload(...)` — direct HTTP,
     bypasses PowerSync.
  3. INSERT/UPDATE the row's `photo_url` text field via Drift; only that
     small string goes through PowerSync.
- **Offline upload**: save bytes to app-docs dir, write
  `photo_url = 'pending:<local-path>'` in the row. A small upload-when-
  online queue swaps the URL once Storage accepts it. (To be built when
  we wire observations.)
- **Download** (any teacher views a photo): `cached_network_image` lazy-
  loads from the signed URL when the widget mounts; caches forever to
  disk. No PowerSync involvement.
- **Bucket access**: private buckets with short-lived signed URLs, RLS
  scoped to program membership. Never `getPublicUrl(...)` for student
  photos.
- **Thumbnails**: at upload time, generate a 256 dp variant alongside
  the full-size. Store both URLs on the row. List views use the thumb;
  detail views use the full.

**Videos and audio are out of scope for v1.** Don't add columns for them
to any table; don't add Storage buckets for them. If a teacher asks for
voice notes on observations later, we'll design that feature properly
(streaming chunked uploads, separate sync stream for transcripts, etc.)
rather than retrofitting.

#### Selective photo sync — the photo-turns model (a shot stays LOCAL until hearted)

Most photos upload immediately (above). The timed per-child TURN shot is the
exception: it's held **local on the device and NOT auto-uploaded** — only the
ones a teacher HEARTS leave the phone. This keeps Storage (and PowerSync's
budget) to the keepers, not every throwaway frame.

- **Capture (timed turn only):** `PhotoService.uploadOnly(deferUpload: true)`
  saves the bytes to the offline queue as a `deferred` entry and writes the
  row's `url = 'pending:<id>'`. The attachment ROW + its tags still sync via
  PowerSync, so the folder + the whose-turn count work offline — only the
  bytes wait. `deferUpload` is true **ONLY** on the timed-turn path
  (`widget.isTurn`); the plain studio + observations upload normally.
- **Heart → upload:** hearting sets the attachment's `sort_order == 0`
  ("for print"). `AttachmentActions.reorder` fires `PhotoUploadQueue.processQueue`
  when `sortOrder == 0`; `processQueue` gates each deferred entry on its
  attachment's `sort_order` (wait / orphan / upload) and only then pushes the
  bytes to Storage + swaps the `pending:` URL.
- **Un-hearted cleanup:** `PhotoUploadQueue.cleanupExpiredDeferred` at app boot
  clears local shots, but ONLY when **ALL THREE** hold: `deferred == true` AND
  `createdAt.toLocal() < today's local midnight` AND not-a-keeper (row gone OR
  `sort_order != 0`). A hearted keeper — **even one hearted OFFLINE that's
  still waiting to upload** — is NEVER deleted.
- **Web has no local hold:** `deferUpload` falls back to immediate upload on
  web (no app-docs dir).

### Face-aligned auto-snap camera (planned)

For attendance check-in / student photos / observation photos, we'll
build a single shared widget at `lib/shared/widgets/face_aligned_camera.dart`
that handles "preview + auto-snap when a face is aligned" in one place.

- Use `camera` (preview/capture) + `google_mlkit_face_detection`
  (on-device detection only — no network)
- Alignment score combines: face bbox inside target oval, eyes detected,
  head angle within threshold, eyes not closed
- Auto-snap after N consecutive aligned frames (~800ms)
- Captured `XFile` goes through the same Storage upload path as any other
  photo (see "Binary media" above) — Supabase Storage, signed URL, the
  row carries only `photo_url`
- Face *detection* is on-device; we do NOT do face *recognition* /
  matching in v1 (different problem: embeddings, vector search, much
  bigger privacy surface). If we ever add it, embeddings stay on-device.

First integration target: attendance check-in in the daily-use flow.

### Performance & responsiveness

Frame budget is 16 ms (60 fps) or 8 ms (120 fps on newer devices). The
build method runs in that window — be conservative.

- **`const` everywhere it works.** Const widgets skip rebuilds.
- **`ListView.builder` / `SliverList`**, never `ListView(children: [...])`
  with large lists.
- **`ref.watch(p.select((s) => s.foo))`** to subscribe to a slice of a
  provider instead of the whole object. Cuts unnecessary rebuilds.
- **`ref.read` in callbacks** (`onPressed`, `onTap`), never `ref.watch` —
  watch rebuilds the widget on every change, but callbacks shouldn't.
- **No computation inside `build()`.** Move derived data into providers
  that memoize.
- **`RepaintBoundary`** around expensive subtrees that change
  independently from siblings (e.g. animated indicators).
- **Defer to isolates** (`Isolate.run`) for any CPU work > 1ms — JSON
  decoding of large blobs, image processing, encryption.
- **Drift watches batch.** `db.watch(...)` emits at most once per
  transaction, so streams don't thrash.

### Responsive layout

Treat layout as a first-class API, not an afterthought. Every screen
must look intentional on:

| Form factor | Width | Pattern |
|---|---|---|
| Phone portrait | < 600 dp | Single column, bottom nav |
| Phone landscape / small tablet | 600–840 dp | Single column, side nav rail |
| iPad / desktop window | 840–1200 dp | Two-column master-detail |
| Desktop / wide | > 1200 dp | Three-column, persistent side panel |

Conventions:
- A shared `Breakpoints` class in `lib/shared/` exposes the constants.
  Don't sprinkle magic numbers.
- Use **`LayoutBuilder`** for size-aware children. Avoid
  `MediaQuery.of(context).size` in `build` — it rebuilds on every metric
  change (keyboard, rotation).
- **Touch targets ≥ 48 dp** even on desktop.
- **Wrap forms / content in `ConstrainedBox(maxWidth: 600)`** centered —
  prevents text from stretching uncomfortably wide on desktop.
- **`SafeArea`** every Scaffold body that isn't a full-bleed image. Phone
  notches and home indicators eat content otherwise.
- **Mouse + touch + keyboard** all work on every interactive element.
  `Focus` and `Shortcuts` for keyboard, `MouseRegion` for cursor.

### Floating-glass chrome — one visual language

**THE UI NORTH STAR — a PERMANENT law (2026-06-20, user: "I won't say this
anymore… chrome bar and omnibox must ALWAYS have transparent background so we
can see body content edge to edge, for all screens — but each screen still
knows to stay clear of those at init and at end").** Three parts, every screen,
no exceptions:
1. The floating chrome — the top hamburger/back/actions/cast **pills** and the
   bottom **omnibox bar** — ALWAYS has **NO colour fill**: transparent fill,
   blur kept ("clear glass", not frosted-and-tinted), hairline border only.
2. The screen's **background fills edge-to-edge UNDER the chrome** (top AND
   bottom), so the chrome floats over continuous body content — **NEVER a dark
   band**. A tinted bar, or a bg that stops short of the chrome, is the
   anti-pattern this kills.
3. Yet the screen's **content stays CLEAR of the chrome at init (top) and end
   (bottom)** — the title/first row clears the top pills, the last
   row/save-button clears the bottom bar — so nothing interactive hides behind
   the glass. Background under, content clear. (This is why the EdgeScaffold
   bleeds the BACKGROUND under the bar while the BODY keeps its reservation —
   part 2 and part 3 at once.)

Enforcement:
- Chrome pills: `GlassPill` defaults `tintOpacity: 0.0`. The omnibox bar's
  `containerColor` is `Colors.transparent` in every mode (search / capture
  / slash) — mode reads from the **border + leading icon + hint**, never a
  fill. Don't reintroduce a tinted chrome fill.
- A screen with a **distinct full-bleed background** (cockpit beats, themed
  rooms) MUST paint it via **`EdgeScaffold(background: …)`** — NOT in the
  body. That one hook handles BOTH bands automatically: it fills under the
  top chrome, AND `EdgeScaffold` **bleeds** it the omnibox-bar height past
  the bottom edge (`Stack(clipBehavior: Clip.none)` + a negative `bottom`),
  so the bg also runs under the transparent bottom bar — with ZERO change to
  the body's content spacing (the body keeps its 76dp reservation, so save
  buttons never hide under the bar). No per-screen opt-in. Painting the bg
  in the body instead → dark Scaffold strip top + bottom (the bug). See
  `now_cockpit_screen._beatBg` (the bg) + `edge_scaffold.dart` (the bleed).
- Most screens sit on the app `surface` already, so the transparent chrome
  shows that same surface with no band — nothing to do. Only a screen with a
  DISTINCT bg needs `EdgeScaffold(background:)`; the bleed does the rest.

Beyond the pills + bar, the other chrome surfaces (suggestion overlay,
drawer, modal sheets) still use the shared translucent BackdropFilter blur
over a tinted surface — those are dense and need the tint for legibility.
**The single source of truth is
`lib/shared/widgets/glass_panel.dart`.** Don't write a new solid
Material wrapper for chrome; reach for `GlassPanel` (with the
shape variant that matches the surface) or the existing widgets
that already wrap it (`GlassPill`, drawer, `showGlassSheet`).

Shapes:
- `GlassPanelShape.pill` — small floating chrome (top pills).
  Used via `GlassPill`.
- `GlassPanelShape.bar` — full-width floating bar (bottom omnibox).
  Inline in `bottom_omnibox_bar.dart`.
- `GlassPanelShape.sheet` — drawer panel, modal bottom sheets.
  `MainDrawer` wraps its body in this; ad-hoc sheets use
  `showGlassSheet(context: ctx, builder: ...)` from `glass_panel.dart`.
- `GlassPanelShape.overlay` — full-screen panels (omnibox
  suggestion list). Inline in `app_shell.dart`.
- `GlassPanelShape.side` — right-docked full-height "third panel"
  (rounded left edge only). What a `showGlassSheet` becomes at
  desktop widths; you rarely use it directly.

**`showGlassSheet` is responsive by viewport width (Wave 180).** One
helper, three presentations — pick a sheet, get the right one for free:
phone (< 840) → bottom sheet; small-tablet / landscape (840–1200) →
centered dialog; desktop (≥ 1200, where the nav rail is a column) →
right-docked `GlassPanelShape.side` panel that slides in over the
(lightly-dimmed) page, completing the `rail | content | panel` layout.
It stays a `Navigator` route at every width, so `Navigator.pop(result)`
/ `await showGlassSheet(...)` is unchanged — re-skinning a sheet for
desktop costs ZERO call-site edits. Opt a sheet out of the desktop
treatments with `dialogAtDesktop: false` (stays a bottom sheet
everywhere — for genuinely one-handed gestural pickers only). The side
panel adds the `Material` + `SafeArea` that `showGeneralDialog` lacks,
raises the IME on autofocus once the slide-in completes, and routes its
close button + Esc through `maybePop` so `DismissGuard` still fires.

**Drag-handle pills: use `GlassDragHandle`, never a hand-rolled
`Container(width: 36, height: 4, …)`.** It reads `GlassSheetScope` (set
by `showGlassSheet` around every body) and renders the grab-pill ONLY on
the bottom-sheet surface — it self-suppresses in the dialog + side-panel
shapes, where a stray "draggable" pill is a meaningless artifact. Any new
sheet body that wants a handle gets one that adapts to all three widths
for free.

When you need glass for a new surface (e.g. a context-menu sheet, a
help bubble, a system-message banner):
1. Pick the shape that matches the surface size + roundness.
2. Wrap the content in `GlassPanel(shape: ..., child: ...)`.
3. If you're routing through `showModalBottomSheet`, use
   `showGlassSheet` so the outer Material is transparent + the
   glass becomes the only visible surface.
4. Do NOT theme the bottom sheet / drawer / dialog backgrounds
   globally to translucent — that breaks every existing dialog
   that expects a solid surface. Opt in per-surface.

The blur strength + alpha is tuned per shape in `GlassPanel`;
don't override them inline without a clear reason. Visual
consistency across chrome is what makes the floating language
read as "one system" instead of "a bunch of slightly translucent
things."

### Color: one theme, enforced — never hardcode on a themed surface

The app has ONE centralized theme (`lib/app/theme.dart` +
`design_tokens.dart` → seeded `ColorScheme` light/dark + the
`AppColors` extension). A bare `Colors.white` / `Colors.black` /
`Color(0xFF…)` for a fill or text on a normal surface is a bug — it
can't follow OS dark/light and is the root of the recurring
dark/light + "white-on-light pill" defects. Read color from
`Theme.of(context).colorScheme.<role>` or
`Theme.of(context).extension<AppColors>()`.

- **Content-driven colors** (a world `block.color`, a `vibe.accent`
  from JSON) aren't theme colors — no theme governs them. When one is
  a FILL behind text/icons, pick the foreground for contrast:
  `AppColors.onAccent(fill)` (black/white by luminance — the light
  worlds fail white-on-light) or `AppColors.readableOnDark(accent)`
  (a pale AA tint for accent text on a dark surface).
- **Hardcoding IS allowed** only on the four raw-canvas types — print/
  PDF, projection/immersive stages, camera viewfinders, and the
  palette/scheme definitions. The authoritative list + the contract
  live in **[docs/THEME_ADHERENCE.md](docs/THEME_ADHERENCE.md)**.
- **The boundary trap**: a control/HUD region inside an immersive
  surface (a game's control bar over the stage) is THEMED even though
  the stage is raw. Painting theme text on the raw stage is the
  `game_scaffold` bug — controls sit on `surfaceContainerHighest`.
- **Teeth**: `scripts/check_theme_adherence.sh` (diff-scoped; runs in
  CI) fails on a NEW hardcode in a themed surface; the **Flutter Theme
  Guard** agent runs in the Review Council for the judgment the regex
  can't. A genuinely-new raw canvas gets added to the allowlist in the
  same change — and to `scripts/check_type_adherence.sh`, its sibling,
  which shares the SAME allowlist so the two can never disagree about
  what counts as a raw canvas.
  - **Type has teeth too, since 2026-09-03.**
    `scripts/check_type_adherence.sh` fails on a NEW uppercase label or
    w800+ weight in a themed surface (BRAND.md law 4). It did not exist
    before, which is how 61 themed files drifted back to the retired
    Jost-era eyebrow (46 uppercase, 25 w800+) while colour was enforced
    three different ways and BRAND.md claimed all five laws were
    "mechanically enforced". **All 61 were migrated 2026-09-03**, so the
    guard now protects a clean tree rather than a documented debt.
    **Use `SectionEyebrow` (`lib/shared/widgets/section_eyebrow.dart`)
    for the label above a title**; it exists precisely because there was
    nowhere to import the treatment from, so every screen re-derived it
    wrong.
  - **Four kinds of caps are NOT drift**, and a sweep that changes them
    is a regression: the wordmark (a logotype), a printed-document
    facsimile, machine strings (license plates, join codes, channel
    topics, format acronyms, initials), and the curriculum scripts,
    whose say-lines are VERBATIM by rule. The first two carry a
    per-line `// raw-canvas` marker; the rest are non-display code.
  - **The allowlist is FILE-scoped, not folder-scoped.** Whole-folder
    entries (`^lib/features/live_session/`, etc.) used to exempt themed
    surfaces that happened to share a folder with a raw stage — that's
    how the board/cast LOBBIES hardcoded colors without the guard
    noticing (the lobby is themed; the cockpit/doc-view is the raw
    stage). List the specific raw FILES, not the folder.
  - **A MIXED file** (a themed lobby + a raw stage in one file) marks
    its raw LINES with a trailing `// raw-canvas` comment — the guard
    drops those lines (like `.withValues(`), so the themed parts stay
    checked instead of allowlisting the whole file. Reference:
    `board_screen.dart` `_darkStage`, `cast_screen.dart` cockpit bg,
    `family_today` over-photo labels.
  - **The guard is diff-scoped — it structurally CANNOT see legacy
    debt** (the ~750 grandfathered literals in untouched files). The
    full-codebase audit is **`tool/score_screens.py`** → it scores every
    gallery screen 0–100 from source (allowlist-gated hardcode count) +
    the rendered light/dark plates (theme_delta, contrast), and writes
    `gallery/screen_scores.md`. Run it after every golden regen. A
    near-zero light/dark delta on a NON-allowlisted, NON-content-driven
    screen is the "hardcoded, doesn't follow theme" smell. Content
    stages (board's `_present`, the game stages, world-present) are not
    bugs — classify them onto the allowlist, don't theme them (that
    breaks the "color the whole screen" design).

### Composition primitives — reach for these before you build

A new feature's first `build()` should be **composition**, not
invention. The primitives below cover ~90% of what feature surfaces
need; only build a custom widget when the shape genuinely doesn't
fit. Each one has a single responsibility and known visual contract,
so a screen built from them inherits the app's vocabulary for free.

| Need | Reach for | Lives in |
|---|---|---|
| The chrome around any screen | `EdgeScaffold` | `lib/shared/widgets/edge_scaffold.dart` |
| A responsive dashboard of modular tiles (overview/home/matrix) | `BentoGrid` (+ `BentoSpan` / `BentoTile`) — [docs/GRID.md](docs/GRID.md) | `lib/shared/widgets/bento_grid.dart` |
| Page title + subtitle inside the scrollable body | `ContentHeader` | `lib/shared/widgets/content_header.dart` |
| Top-right action(s) in the glass pill | `actions:` slot on `EdgeScaffold` + `PrimaryActionButton` / `SecondaryActionButton` | `lib/shared/widgets/` |
| Loading state | `LoadingSlot` (`.list` / `.cards` / `.spinner`) | `lib/shared/widgets/async_loading.dart` |
| Empty state | `EmptyState(icon:, title:, message:, action:)` | `lib/shared/widgets/empty_state.dart` |
| Error state | `ErrorState(title:, detail:, onRetry:)` | `lib/shared/widgets/error_state.dart` |
| Tappable row card (person / item / template) | `FeatureCard(leading:, title:, subtitle:, trailing:, tone:, onTap:)` | `lib/shared/widgets/feature_card.dart` |
| Aggregator section that hides when empty | `SectionCard(visible:, icon:, title:, tone:, child:)` | `lib/shared/widgets/section_card.dart` |
| Person identity (member / subject / guardian) | `PersonAvatar(name:, photoUrl:, radius:)` | `lib/shared/widgets/person_avatar.dart` |
| Modal sheet | `showGlassSheet(context:, builder:)` | `lib/shared/widgets/glass_panel.dart` |
| Top-of-screen actions pill | `GlassPill` wrapping action buttons | `lib/shared/widgets/glass_panel.dart` |
| Form sheet > 3 fields | `DismissGuard(isDirty:, child:)` | `lib/shared/widgets/dismiss_guard.dart` |
| Destructive button | `DestructiveButton(label:, onPressed:)` | `lib/shared/widgets/destructive_button.dart` |
| Confirm destructive action | `confirmDestructive(context, title:, message:)` | `lib/shared/widgets/destructive_button.dart` |
| Capability toggle | `CapSwitch(label:, value:, enabled:, onChanged:)` | `lib/shared/widgets/cap_switch.dart` |
| Date / time format | `dateKey(dt)` / `timeOfDay(dt)` / `todayKey()` | `lib/shared/format/date_keys.dart` |
| Relative-time label | `relativeTimeAgo(dt)` | `lib/shared/format/relative_time.dart` |

If you find yourself writing `Material(color:..., borderRadius:..., child: InkWell(...))` from scratch — stop, reach for `FeatureCard`. If you're writing `if (items.isEmpty) return SizedBox.shrink(); return Container(...)` — stop, reach for `SectionCard`. If you're writing your own `'Could not load X'` text — stop, reach for `ErrorState`. The convention IS the primitive.

### UX state primitives

Every list / data screen has four states, all designed:

1. **Loading** — skeleton or shimmer, not just a spinner. First load
   only; once data is local, this should never appear again.
2. **Empty** — illustration + one-sentence explanation + primary CTA
   ("No students yet. Add your first student."). Never an empty white
   screen.
3. **Data** — the happy path.
4. **Error** — recoverable banner with retry, not a wipe of the screen.
   Errors during sync go in a banner, not a dialog.

Forms:
- **Validate inline** (`onChanged` or `onFieldSubmitted`), not only on
  submit.
- **Persist drafts** to local state for any form > 3 fields. Losing
  typed-in observation notes because of a tab switch is a real bug.
- **Disable submit during submission**, show inline spinner in the
  button — never a full-screen overlay.

Navigation:
- **Every route is deep-linkable** (go_router patterns, no in-memory-only
  state for primary navigation).
- **Back stack consistent across platforms** — the system back gesture
  on Android, the swipe back on iOS, browser back on web must all do
  the same thing.

### Modals — a glance, never a task (2026-06-21, user: "maybe we shouldn't have any modals…")

**No modal is a destination or a task.** The app is a calm, host-present spine;
an overlay that floats over the room and traps focus fights that — and modals
are the app's #1 bug class (the whole "Interaction invariants" section exists
because of them: keyboard-vanishes, focus theft, the dismiss-guard dance, IME
traps). So:

- **A task** (fill / pick / multi-field form) → a **page (route)**, not a sheet.
  Deep-linkable, room to breathe, and the IME/focus/DismissGuard traps just
  evaporate (a page's back IS the "are you sure"). Don't reach for
  `showGlassSheet` for a form.
- **A destructive action** → **`deleteWithUndo(...)`** (`destructive_button.dart`),
  NOT a confirm dialog: delete now, offer Undo in a snackbar for a few seconds.
  The undo just re-inserts the row (stable client UUID → re-syncs); add a
  `restore(row)` to the DAO if it lacks one (see `entriesDao.restore`). Keep
  `confirmDestructive` ONLY for irreversible / **cascading** deletes (a cohort
  that owns children) where one re-insert can't restore the tree.
- **A glance you dismiss without acting** (the entity peek) → a light overlay is
  fine; that's the ONE place a modal earns its place (a page would lose your
  spot). It should be non-focus-trapping so it dodges the bug class.

Migration is staged (bucket 1: confirms→undo; bucket 2: forms→pages; peek
untouched). New code follows the law from the start.

### The half-second rule — instruments, not settings panels

**A staffer must be able to operate any live-room surface one-handed, while
talking, while walking, glancing at the screen for half a second.** This is the
operational form of the calm-host brand, and it is mostly SUBTRACTIVE — it tells
you what to remove. (Adapted from the Feature Lab's launcher rule, 2026-08-22.)

What it kills:

- **Simultaneous half-started tools.** A chip row holding four tools, all one
  tap away, none of them actually running, is a settings panel wearing the
  costume of an instrument. Nobody times four things at once. **Pick one, and it
  owns the screen until you close it.** The cost is one extra tap; the gain is
  that at any moment the screen is doing exactly one thing — the only way half a
  second is enough to read it.
- **Permanent instructions.** "Tap a face to mark them away" is true forever,
  which is exactly why it stops being read. *An instruction that is always on
  screen is a sign on a wall.* Instructions appear only while they are NEWS —
  "tap someone to link them" exists only during linking, then goes. (This
  sharpens the microcopy rule below; it does not replace it.)
- **Controls used once.** Adding children happens on day one and then almost
  never. It does not get to sit beside the register all term — it goes in the
  one housekeeping menu. Two identical `⋯` menus on one screen is worse than the
  button they replaced.

What it demands:

- **The thumb owns the bottom.** What you READ sits at the top; what you PRESS
  repeatedly sits at the bottom. Not symmetry — the top of a phone is out of
  reach one-handed, and a control you must look at is a control you cannot use
  while talking. (Note the standing tension: `EdgeScaffold`'s `actions:` pill is
  at the TOP. That is right for a page's save/edit; it is wrong for an
  instrument's repeated action. A live-room instrument puts its repeated control
  in the body's bottom, above the omnibox reservation.)
- **Live state on the launcher.** Because an instrument hides everything else,
  the launcher must answer "is anything running" WITHOUT being opened — the
  Timer row reads `2:14 left` in amber while the clock runs. This is what
  `NavDestination.countProvider` does for counts; live surfaces need the same
  for state.
- **Filled shapes mean events.** A filled, bordered container is the shape of
  something you press to CAUSE something. A control that only changes what you
  are LOOKING at is words and a rule, not a filled segmented control —
  segmented controls that promise action and deliver navigation are a lie the
  hand notices.
- **Motion instead of cuts.** After a re-arrangement the only question is *what
  moved*. A single-frame replacement makes that unanswerable, so a new
  arrangement settles in left to right rather than swapping.
- **Deliberate latency on a fairness reveal.** Instant results feel rigged;
  ~600–900 ms of reveal feels fair. The one place in the app where slower is
  better. Deal the result out rather than swapping a list — the reveal is the
  emotional peak.
- **Report the mix, not a warning.** "10 new pairings · 2 unavoidable repeats"
  beats "2 repeated", and marks WHICH — a count with no referent is an alarm,
  and this is not an alarm.

### Instruction & microcopy — make it obvious first

**The golden rule: the best instruction is the one the user never needs to
read.** Before writing a hint, a subtitle, or a footer, ask *can this be made
obvious instead of explained?* If you're stacking instructions on a screen,
that's a signal the design is asking the user to carry too much — fix the
design, don't add words. (Pairs with the `copy-tone` skill, which governs HOW
the words read once they're justified.)

When instruction genuinely IS needed, reach for the lightest touch that works,
in this order:

1. **Self-evident** — familiar pattern, clear label, sensible default. A
   "Brew another" button needs no caption.
2. **Inline microcopy** — a tiny hint right next to the thing (helper text under
   a field, a one-line note beside a button), never on a separate surface.
3. **Progressive disclosure** — show the basics; hide the advanced behind a
   tertiary affordance (the Do-It "Snap the proof or tag who led it" is this —
   the quick tap is primary, the rich path is opt-in).
4. **Just-in-time** — reveal the tip at the moment of need, then let it go.
5. **Empty states that teach** — an empty list is the right place to say "tap
   to add the first thought" (the Penny screen does this); never a blank.
6. **Onboarding / coach marks** — sparingly, short, SKIPPABLE; most people
   click through.
7. **A real help center** — last resort, for the deep stuff that doesn't belong
   in the UI.

Unifying principles: **just-in-time beats all-at-once** (reveal at the moment of
need, not upfront) · **chunk it** (small pieces near their context, never a wall
of text) · **people scan, they don't read** (design for scan-and-click) · **let
them dismiss and skip** (forced tutorials annoy more than they help).

**This app is unusually well-suited to "make it obvious"** — it's host-present
and calm: a staffer drives, the room watches, nobody's hunting a manual. A
subtitle that re-explains an obvious card, or a footer the host already knows
("make it for real"), is a candidate to cut, not keep. When a screen needs a
paragraph to make sense, the screen is wrong.

### Privacy & security

Children's data is sensitive PII. Assume regulators (state licensing,
COPPA in the US) will eventually audit.

- **No PII in logs.** Don't `print` student names, photos, parent
  contact info, or observation narratives. The PowerSync upload error
  logs and the deeplink-received log are exceptions — they're gated
  on `kDebugMode` so they never reach release-build logcat. New logs
  that could carry a path, exception payload, or URI MUST follow the
  same pattern: `if (kDebugMode) debugPrint(...)`.
- **Photos**: Supabase Storage **private** bucket + signed URLs
  (1-hour TTL, minted via `signedPersonPhotoUrlProvider`). Never use
  public buckets for student photos. The `person-photos` bucket is
  RLS-scoped to space membership (first path segment matches caller's
  members.space_id).
  - **Signed-URL broker (NOT `createSignedUrl`).** `signedPersonPhotoUrlProvider`
    now mints URLs through the `sign-photo` Edge Function
    (`supabase/functions/sign-photo`), which **authorizes server-side before
    signing**: STAFF = a member of the photo's space (path's first segment);
    GUARDIAN = (a) a subject-pathed object whose subject they guard, or (b) an
    attachment-pathed object whose row is tagged (`subject_id` / `captured_by`)
    to a subject they guard. The authorization is a pure function
    (`authorizePhotoAccess`) with a Deno test.
  - **DEFERRED — bucket lockdown written, not pushed.**
    `20260903000001_person_photos_broker_only.sql` drops the permissive
    `person_photos_read_own_space` policy so the broker is the only read path.
    Gated on an on-device "photos load" check, because pushing it over a broker
    that is broken for any path shape blanks every photo at once. Until it
    lands the hole is mitigated (the app signs through the broker) but **not
    closed**: the policy still lets ANY space member `createSignedUrl` any
    photo in that space directly — and a guardian IS a space member, which the
    policy cannot distinguish from staff.
- **Background screenshots** on iOS/Android are blocked in release
  builds — Android sets `FLAG_SECURE` in `MainActivity.onCreate`;
  iOS overlays a solid-colour `UIView` over the key window in
  `SceneDelegate.sceneWillResignActive` before the OS captures its
  task-switcher snapshot. Debug builds skip both so QA + dogfooding
  builds can capture screenshots normally.
- **No analytics events** that include child identifiers. If we add
  product analytics, it's event-level, never row-level.
- **Auth tokens never logged.** Supabase access/refresh tokens stay in
  `flutter_secure_storage`-backed channels only.
- **Vendor API keys.** **Deepgram (STT) + the TTS keys are already
  brokered** — they live as server-side secrets on Supabase Edge
  Functions, never in `.env` / the app bundle. The client calls the
  function, gets a short-lived token / result, and the master key never
  reaches the device. **The five Edge Functions** (`supabase/functions/`):
  `voice-token` (mints a ≤30 s Deepgram STT token), `tts-generate` +
  `tts-subtitles` (ElevenLabs TTS — the latter also returns char-level
  word timings for the `/speak` karaoke screen, cached globally in the
  `tts-cache` bucket), `sign-photo` (authorizes server-side, then signs
  private-bucket photo reads), and `send-export` (mints a signed URL +
  emails an export's recipients via Resend, stamps `export_recipients`).
  Any NEW vendor key should follow that same broker pattern, not ship in
  `.env`. Full
  pattern + tier table in `docs/SECRETS.md`. Public config (Supabase
  URL, anon key, PowerSync URL, Sentry DSN) stays in the binary — RLS
  is the real gate. (`.env` holds only that public config; if a key
  ever needs the device, bound it with vendor-side spend caps + rate
  limits + project-scoped keys.)
- **Data export & deletion** — a parent or program admin must be able to
  export all data for a child and request deletion. Plan endpoints when
  we get there.

### Accessibility

Built in from day one, not retrofitted.

- **Every interactive element has `Semantics(label: ...)` or `Tooltip`.**
- **Color contrast ≥ 4.5:1** on text. Use Material 3 color schemes;
  don't hand-pick colors.
- **Respect `MediaQuery.textScaleFactor`** — text must scale up to 200%
  without truncation. Avoid fixed-height containers around text.
- **Focus order** is logical (top-to-bottom, left-to-right).
- **Tap targets ≥ 48×48 dp.**
- **Screen reader test**: every primary flow should be navigable with
  VoiceOver/TalkBack with no dead ends.

### Internationalization

English-only at launch, but structured for translation from day one. The
cost of retrofitting i18n is much higher than building with it.

- **Use `flutter gen-l10n`** with `arb` files in `lib/l10n/`.
- **Never hard-code user-facing strings** in widgets. Even
  `'Continue with Google'` should resolve through `AppLocalizations.of(context).signInWithGoogle`.
- **Dates, numbers, currencies** through `intl`, not `toString()`.
- **Plurals** via `Intl.plural` — children's ages, attendance counts,
  etc. will need them.

### Testing standards

The testing pyramid for this app:

| Type | What it covers | Where |
|---|---|---|
| Unit | Pure functions, repositories, conversion logic | `test/unit/` |
| Widget | Single screen with mocked providers | `test/widget/` |
| Golden | Visual regression on key screens / layouts | `test/golden/` |
| Integration | End-to-end with real Supabase test project | `integration_test/` |

- **Every repository method** should have a unit test using a Drift
  in-memory database.
- **Every screen** with a non-trivial state machine (login, onboarding,
  attendance entry) should have widget tests covering loading / empty /
  error / data states.
- **Goldens for the breakpoint matrix** — phone portrait, iPad, desktop.
  Catches responsive regressions in CI.
- **No mocks for the sync layer in integration tests** — the whole point
  of those tests is that the real layers wire up. Use a dedicated test
  Supabase project.

Run before declaring any feature done:
```sh
flutter analyze     # zero issues
flutter test        # all passing
# Optionally: flutter test integration_test/  for the E2E suite
```

---

## Known gotchas

The ones we've already burned a turn on.

### "Not saving" / "cast not working" — check the CLOUD INFRA first, not the code

Two multi-week mysteries (2026-07/08) were both dead backend services, not
app bugs — and the app's offline-first design MASKED them (local writes
kept working, so nothing errored loudly):

- **"Things aren't saving properly"** = the PowerSync Cloud instance was
  GONE — its hostname (`POWERSYNC_URL` in `.env`) returned NXDOMAIN from
  every network. Local saves worked; nothing ever synced. Diagnose in one
  step: `host <instance>.powersync.journeyapps.com` from the Mac. Fix:
  PowerSync dashboard → revive/recreate the instance → update `.env` →
  **paste sync_rules.yaml into the dashboard and Deploy** (fresh instance
  has no rules) → rebuild.
- **"Cast to screen / use device as screen not working"** — Cast rides
  Realtime channels exclusively, so a wedged Realtime kills both directions
  with zero app-side errors worth grepping. **Probe it with a real WebSocket
  handshake over HTTP/1.1** — `101 Switching Protocols` means healthy:

  ```sh
  curl -s -i --http1.1 \
    -H "Connection: Upgrade" -H "Upgrade: websocket" \
    -H "Sec-WebSocket-Version: 13" \
    -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
    "$SUPABASE_URL/realtime/v1/websocket?apikey=$ANON&vsn=1.0.0" | head -1
  ```

  **A plain GET on that URL ALWAYS returns 500 — it is not a diagnosis.**
  This file used to document the plain probe with "500 = server-side", and it
  cost a wasted Supabase project restart on 2026-09-03: the plain form returns
  `500` + Cloudflare `error code: 1101` ("worker threw an exception") on a
  perfectly healthy instance, because a WebSocket endpoint is being asked to
  serve an ordinary HTTP/2 request. It reproduces 3/3 while the correct probe
  returns `101` 3/3. `curl` also negotiates HTTP/2 by default, which cannot
  carry a WS upgrade at all — `--http1.1` is required, not optional.

  If the handshake really does fail: Supabase dashboard → Settings → General →
  **Restart project**. Expect Postgres to be unreachable for ~30 s afterwards
  (PostgREST 503) and PowerSync to log `connection failed` / `postgres query
  failed` / `the database system is shutting down` — that is the restart, not
  a new fault, and it clears itself once Postgres accepts connections again.

Rule: before auditing app code for a "stopped working" report on any
sync/live feature, run the two probes above (plus `auth/v1/health`).
The sync-health sheet (tap the cloud pill) surfaces the PowerSync half
on-device; Realtime has no in-app surface yet.

### Sync rules reference publication tables — so the drop comes LAST

Removing a table from the `powersync` publication while the DEPLOYED sync
rules still reference it breaks the running instance immediately:

```
Table "public"."enrollments" is not part of publication 'powersync'.
```

The repo's `sync_rules.yaml` is only a source of truth; the **dashboard is
the runtime**. So editing the YAML to drop a table does nothing until it is
deployed — and the migration that drops the table from the publication takes
effect the moment it is pushed. Push first and the live instance references a
table that is no longer published.

**The order is one-way:**
1. Edit `sync_rules.yaml` to stop referencing the table.
2. **Deploy the rules on the PowerSync dashboard.**
3. *Then* `alter publication powersync drop table …`.

Restoring is free and safe (`alter publication powersync add table …`) — a
published table that no rule selects is simply never streamed — so when in
doubt, add it back and re-drop after the deploy. The same ordering applies to
dropping a COLUMN that a sync rule's `SELECT *` covers.

### A new table name can collide with one Dart never sees

`supabase db push` refused a migration because `enrollments` already
existed — it has meant **staff↔classroom** since the foundation migration
(`member_id` / `group_id` / `role`). A new table for a different
relationship (child↔room↔period) reused the word, and the collision ran
through every layer at once: `create table if not exists` silently
skipped, then an index on the new column failed; `power_sync_schema.dart`
declared `Table('enrollments')` **twice** (shadowing the legacy table in
the local schema); and `sync_rules.yaml` listed it twice in `by_space`.

**None of it was visible to `flutter analyze` or to the full test suite**,
because the legacy table is synced but has **no Drift class** — Dart never
sees it. Only the real database found it.

Rules:
- **Before naming a new synced table, grep `supabase/migrations/` for the
  name** (`grep -rn "create table.*<name>" supabase/migrations/`), not just
  `lib/`. A synced table with no Drift class is invisible from Dart.
- **After adding a `Table(...)` to `power_sync_schema.dart`, check the name
  appears exactly once** — a duplicate is accepted by the compiler and
  shadows silently.
- **Push migrations promptly rather than batching them.** Deferring is what
  let this sit undetected behind a green analyze + 1092 passing tests. The
  push IS the test for the layers Dart can't reach.

### QR deep links: vehicle = custom scheme, invite = https (don't flip them)

This choice flip-flopped across Waves 165→170 — settled in Wave 171.
The rule splits by **who scans the QR**:

- **Vehicle check-in/out QRs → `differentworld://v/<id>/<kind>`
  (custom scheme).** Scanned only by staff, who always have the app.
  A custom-scheme QR opens the app *directly* — no browser, no
  GitHub Pages hop, no DNS. Generated in
  [vehicle_qr_pdf.dart](lib/features/vehicles/vehicle_qr_pdf.dart)
  via `VehicleDeepLink.customSchemeUri(...)`.
- **Invite QRs → `https://…/invite/<code>` (apex or github.io).**
  The scanner may NOT have the app yet, so the genuine "app not
  installed" fallback (web landing page → store / explain) matters.
  Keep these on the HTTPS path
  ([invite_share_screen.dart](lib/features/invites/invite_share_screen.dart),
  `InviteCode.pagesLinkFor`).

**The trap (why this kept flip-flopping):** an `https://` QR ALWAYS
opens the browser first until Android App Links / iOS Universal Links
are *verified* (`autoVerify=true` + association files at the **domain
root** + iOS entitlement + real Team ID — none of which are live yet;
the files in `differentworld-web/.well-known/` sit at the project
sub-path, which app-link verification ignores). So every "make the QR
use https for a clean fallback" wave silently reintroduced a web-page
flash on scan. Custom scheme is the only thing that opens the app with
zero web hop *today*. Do NOT swap the vehicle generator back to
`httpsUri`/`pagesUri` without first standing up verified App Links.

`VehicleDeepLink.tryParse` + `InviteCode.extractFromUri` still accept
ALL forms (custom scheme, apex https, github.io project-page), so the
in-app scanner and QRs printed under older waves keep working — old
stickers route via the web page, new ones open directly. The proper
fix for invites (true App Links on a `jardinefaner.github.io` root
repo) is the deferred "Recommended split" second half.

### `matchedLocation` is shell-relative inside a ShellRoute builder — use `uri.path`

In AppShell (the `ShellRoute` builder),
`GoRouterState.of(context).matchedLocation` reflects the **shell's**
match, NOT the active child route. Verified on device (2026-06-01): on
`/activity/this-or-that` it stayed at `/breaks` (the last top-level
match), so `matchedLocation.startsWith('/activity/')` was always false
and the "hide the omnibox bar on immersive activity routes" gate never
fired. `atRoot` (matchedLocation == '/') happens to work only because
`/` is the shell's own base.

Rule: to detect the CURRENT route from inside the shell (hide chrome,
theme by section, etc.), read **`GoRouterState.of(context).uri.path`**
— that's the full active location (`/activity/this-or-that`).
`matchedLocation` is for per-segment matching, not "where am I."

### Flutter 3.24+ deep-linking-by-default fights app_links → custom-scheme 404

Symptom: scanning a `differentworld://v/<id>/checkout` (or
`…/invite/<code>`) QR opens the app but lands on the in-app "We can't
find that page" 404 ([router.dart](lib/app/router.dart) `errorBuilder`),
echoing the raw custom-scheme URL.

Cause: Flutter 3.24+ enables its OWN deep-link routing by default
(`flutter_deeplinking_enabled` defaults to true on Android/iOS). The
framework hands the RAW URI (`differentworld://v/<id>/checkout`) to
go_router as a location; go_router can't match the custom scheme to any
path and renders the 404. Meanwhile our `app_links` listener
([deep_link_listener.dart](lib/features/invites/deep_link_listener.dart))
ALSO receives the URI and correctly translates it to
`/vehicles/<id>/checkout` via the pending-link providers — but on a
cold launch the framework's 404 wins the initial route, so the consumer
(a `ref.listen` on TodayScreen) never mounts to fire.

Why it hid for so long: it only bites when the unmatched route ISN'T
masked by go_router's redirect. Invites are scanned signed-OUT → the
redirect-to-login swallows the bad route (and the login flow reads the
pending code) → looked fine. Vehicle QRs are scanned signed-IN by staff
→ no redirect mask → the 404 shows. Wave 171 (vehicle QR → custom
scheme) didn't cause this; it just made the scheme actually reach the
app, exposing a latent bug.

Fix (Wave 172), two parts — BOTH were needed:

1. **Disable the framework handler** so app_links is the single source
   of truth — `flutter_deeplinking_enabled=false` meta-data in
   AndroidManifest.xml + `FlutterDeepLinkingEnabled=false` in iOS
   Info.plist. Supabase's OAuth callback has its own URI listener and is
   unaffected. Native change → **full rebuild, not hot reload.**

2. **Drain the pending link on mount, not just `ref.listen`.** With the
   framework handler off, the cold-launch QR landed on Today but didn't
   navigate. Verified on-device: `app_links` delivered, `_ingest` set
   `pendingVehicleDeepLinkProvider` — but the consumer
   (`_SignedInHome`) used only `ref.listen`, which fires on CHANGE.
   On cold launch the value is set during boot, BEFORE the post-sync
   home mounts, so the listener registered too late and never saw it.
   (Warm — link arrives while already on Today — worked fine, which is
   why it was confusing.) Fix: `_SignedInHome` is now a
   `ConsumerStatefulWidget` that drains any already-pending vehicle /
   invite link in a post-frame callback from `initState`, in addition
   to the warm-path listeners. **Lesson: any "pending X set by a boot-
   time service, consumed by a screen" handoff needs an initState read
   of the current value — a `ref.listen` alone silently drops the
   cold-start case.**

### Google OAuth's `name` claim, not `display_name` or `full_name`
Supabase's docs / examples reference `raw_user_meta_data->>'display_name'`
when reading the user's name out of an OAuth sign-in. That field is a
Supabase convention; Google's OAuth response sends the user's name
under the **`name`** key (sometimes ALSO under `full_name`, but never
reliably under `display_name`). Coalescing in the order
`display_name → full_name → email-local-part` (as the original
`handle_new_user` trigger did) silently falls through to the email-
local-part for every Google sign-in. A "john.smith@gmail.com" sign-in
shows as "john.smith" in the drawer; a guardian whose director typed
their email when creating the invite shows up as their email forever.

Fix: try `name` FIRST when reading `raw_user_meta_data`. Pattern (from
migration `20260523000004_pull_google_name.sql`):
```sql
coalesce(
  nullif(trim(u.raw_user_meta_data->>'name'), ''),
  nullif(trim(u.raw_user_meta_data->>'display_name'), ''),
  nullif(trim(u.raw_user_meta_data->>'full_name'), ''),
  split_part(u.email, '@', 1)
)
```

The same migration backfills existing `members.display_name` +
`guardians.name` rows that look like placeholders (display_name
matches email local-part exactly; guardian.name contains "@") with
the real Google name from `auth.users.raw_user_meta_data`.

Dart side: the drawer renders `viewer.displayName`, not
`member.displayName` — so a GuardianViewer's name resolves through
`guardian.name` (the friendly identity) instead of the member-shell
row's email-local-part placeholder. Apply the same `viewer.displayName`
pattern to any new identity-rendering surface.

### Stack children without keys → IME closes when sibling is added (the "keyboard disappears on tap" bug)

If a `Stack` has multiple `Positioned` children of the same widget
type, Flutter's reconciliation matches them by **position-in-list +
type**, not by purpose. Inserting a new `Positioned` in the middle
shifts the matching of all later siblings — and the Elements those
siblings used to be attached to now belong to the wrong widgets. The
visible result: any child carrying state (an `EditableText`'s input
connection, a Hero, an AnimationController) **silently rebuilds**
when an unrelated sibling appears.

Symptom we hit (May 2026): AppShell's body Stack had `[route content,
chrome pills, omnibox bar]`. Tapping the bar set `_searchOverlayOpen
= true`, which inserted a new overlay Positioned at index 1. After
the rebuild Flutter matched the bar's Element to the chrome's slot,
the `BottomOmniboxBar` widget rebuilt, the inner `TextField`'s
`TextInputConnection` tore down, Android closed the soft keyboard.
The Flutter side still reported "focus on bar = true" — that's why
the bug was so hard to find from focus logs alone.

**Rule**: ANY `Stack` whose children list can grow/shrink at
runtime — feature toggles, overlays, conditional pills — must give
each child a stable `Key`. `ValueKey('shell-omnibox-bar')`,
`ValueKey('shell-omnibox-overlay')`, etc. Flutter then matches by
key + type, not position; siblings can come and go without
poisoning each other's Elements.

The same rule applies to `Column`, `Row`, `Wrap`, `ListView`,
`CustomScrollView` — any multi-child widget that doesn't already
key its children for you.

If you see "a widget unexpectedly rebuilds when an unrelated sibling
appears," check for missing keys first.

### "Modified provider while the widget tree was building" — the chrome publish trap
When `EdgeScaffold.initState` calls `routeChromeProvider.notifier.push(...)`
synchronously, Riverpod throws the full-screen red error frame
("Tried to modify a provider while the widget tree was building").
Cause: initState runs DURING the parent route's build phase, and
AppShell is watching `routeChromeProvider` — writing to a watched
notifier mid-build is forbidden.

Fix: defer the write through `Future.microtask`. Microtasks fire
AFTER the current build phase finishes but BEFORE the next frame's
render, so the new chrome still paints in the same visible frame as
the new page (no 1-frame stale-chrome flicker like
`addPostFrameCallback` would cause).

Same pattern applies to any provider write triggered from a
descendant's lifecycle when an ancestor is watching it (e.g.
`kidModeProvider.notifier.enter()` from a kid-surface's initState
goes through the same microtask defer).

**Guard the deferred enter on `mounted`, and keep paired OS side-effects
inside the same microtask.** A microtask scheduled from `initState` can
fire AFTER `dispose` if the screen pops in the same frame (fast back). For
an immersive screen that does `enter()` on mount and `exit()` on dispose,
an unguarded deferred `enter()` then runs post-dispose → the provider is
left `true` (chrome hidden) while dispose already restored the OS UI —
chrome stuck hidden. Fix: `Future.microtask(() { if (!mounted) return;
notifier.enter(); SystemChrome.setEnabledSystemUIMode(immersiveSticky); })`
— the `mounted` check and BOTH side-effects (provider + `SystemChrome`)
live together so they stay in lockstep. Reference:
`lib/features/action_words/world_present_screen.dart`. (Caught by the
lifecycle guard on the world-cast screen, Wave C.)

### `.value ?? const []` renders a FAILED read as an EMPTY one

The idiom is everywhere and it is right most of the time — but on any
surface that says something CONFIDENT about absence, it makes the app lie:

- Class memory said **"nothing kept yet"** about a history a teacher had
  spent weeks building.
- The room page showed an **empty roster** to someone standing in a full
  room, with "Add a child" underneath it — inviting duplicate enrolment,
  which is a far worse outcome than a visible error.

Both read as certainty. Neither was.

Rule: if a screen's empty state makes a CLAIM ("nobody yet", "nothing
kept"), it must first check `hasError` and say something different — and
where the empty state carries an ACTION, hide the action too. A person who
cannot see the current data must not be invited to add to it.

`test/unit/swallowed_error_test.dart` guards the pattern on the screens that
watch async data. It is deliberately crude — a screen can pass and still be
wrong — but the failure mode is silent by nature, so a coarse net beats
none. `docs/SCREEN_RUBRIC.md` B3 is the full rule and marks it a blocker.

### Dead links don't throw — go_router renders a fallback instead

`context.push('/a/route/that/does/not/exist')` does **not** crash. go_router
matches what it can and renders the 404 (`errorBuilder`) or, where the route
takes its args through `extra`, falls back to a DIFFERENT screen entirely.
So the tap "works", the user lands somewhere they did not ask for, and
nothing surfaces in logs or in `flutter analyze`.

Three shipped in one day, all in new code:
- `/schedule/block?id=…` — that route reads a `BlockEditArgs` from `extra`;
  a query id silently landed on the schedule screen.
- `/groups/:id/run/:blockId` — never declared at all.
- `/settings/locations` in a doc example — guessed from the screen's name.

**`test/unit/no_dead_links_test.dart` now checks every literal
`context.push('/…')` in `lib/` against the REAL router** via
`router.configuration.findMatch`, with `${…}` standing in as one segment.

Two things about it worth keeping:
- It **skips comment lines** — but only after the first run caught a wrong
  example in `feature_card`'s doc (`/family/:id`, which does not exist). A
  wrong example ships as a dead link the moment somebody copies it, so fix
  the comment rather than just excusing it.
- It has a **"the check can actually fail"** test. The first version of
  this checker was a regex whose prefix fallback silently passed a
  deliberately-broken route. A checker that cannot fail is worse than none,
  because it is believed.

Paths built by concatenation are out of scope and stay a human problem.

### `canManageSpace` is `isDirector` — structure has its own key now

`canManageSpace` was never a capability. It is literally
`bool get canManageSpace => isDirector;` and `can_manage_space` appears
**zero times** in `lib/` or `supabase/`. So there was no middle setting: a
director who wanted a Group Leader to add a location had exactly one option
— grant `can_act_as_director`, which also hands over billing, the audit log
and role editing.

**`CoreCaps.canManageStructure` is the grantable tier**: locations, rooms,
vehicles, terms, enrolment. It falls through to `isDirector`, so no existing
member loses anything and no migration was needed (caps are jsonb).

The tier is drawn on **what a bad row costs**, not entity type:
- **Declare** (`canManageStructure`) — locations / rooms / vehicles / terms.
  A duplicate location is not clutter: two cohorts booked into "Gym" and
  "Gym B" stop colliding, which silently disables the schedule's only
  contention warning.
- **Book** (`canManageSchedule`) — schedule blocks. Already seeded TRUE for
  Counselors; a "leads only" model would regress the shipped bundle.
- **Contribute** (ownership) — activities. Anyone may add one;
  `activities.owner_member_id` decides who may archive it.

**The deeper rule this exposed: the app hid buttons instead of guarding
actions.** Five structural screens had ZERO capability reads and were
reachable by deep link and by omnibox search — `location_edit`,
`room_create`, `day_templates`, `weekly_template`, `block_edit`. Hiding an
entry point is not gating an action. New structural screens get a
screen-level `NoAccess` guard (the pattern in `vehicle_edit_screen.dart`),
not just a hidden button.

**These gates are UI-honest, not a security boundary.** Every structural
table is still `using (true) with check (true)` because of the ES256
`auth.uid()`-null workaround above. Don't assume RLS is backing them.

### A parsed stored timestamp is UTC — reading `.hour` off it shows the wrong time

Every timestamp in this app is stored as a **UTC ISO string**
(`startAt.toUtc().toIso8601String()`). So `DateTime.tryParse(row.startAt)`
returns a DateTime with `isUtc == true`, and reading `.hour` / `.day` /
`.year` off it gives **UTC components** — a block at 16:30 local rendered as
whatever 16:30 is in UTC, and near midnight `dateKey` returned the wrong
calendar day.

Comparisons are **safe** — `isAfter` / `isBefore` / `difference` compare
absolute instants, so a UTC value and a local `DateTime.now()` compare
correctly. Only **component reads** are broken.

`dateKey()` and `timeOfDay()` now call `.toLocal()` internally, so anything
going through them is correct by construction. That was deliberate: the
correct-but-forgettable `DateTime.tryParse(x)?.toLocal()` dance was already
missing from several surfaces, and a formatter that is only right when every
caller remembers something will be wrong again.

Rules:
- **Format through `dateKey` / `timeOfDay`**, never hand-rolled `.hour`
  padding. Those are the only two places `.toLocal()` needs to live.
- If you must read a component directly off a parsed stored value, write
  `DateTime.tryParse(x)?.toLocal()` — and ask first whether a formatter
  should own it instead.
- A test fixture built with `DateTime(2026, 8, 26, 16, 30)` is **local** and
  passes either way. Pin timezone behaviour against a PARSED stored string
  (`test/unit/date_keys_timezone_test.dart` is the template) or the test
  proves nothing.

### Drift ↔ PowerSync ambiguous `Column` import
Both packages export a `Column` class. Importing
`package:powersync/powersync.dart` unqualified inside any file with Drift
table definitions makes drift_dev **silently fail to generate code** —
warnings like "Profiles is not understood by drift" and an empty
`allSchemaEntities` in the .g.dart.

Fix: scope the import.
```dart
import 'package:powersync/powersync.dart' show PowerSyncDatabase;
```

### No `riverpod_generator`
Dropped because it caps at riverpod 3.1.x but `flutter_riverpod 3.3+`
needs riverpod 3.2+. Use plain `Provider`, `StreamProvider`,
`FutureProvider`, `Notifier`. Re-evaluate when the ecosystem catches up.

### Drift schema is read-only
`MigrationStrategy` must be no-op in both `onCreate` and `onUpgrade` —
PowerSync owns the schema. Drift tables are purely for typed access.

### `.value` not `.valueOrNull`
Riverpod 3 renamed `AsyncValue.valueOrNull` → `AsyncValue.value` (still
nullable). `requireValue` throws on loading/error.

### Web wasm
PowerSync on web needs `web/powersync_db.worker.js` and `web/sqlite3.wasm`.
After every `powersync` version bump:
```sh
dart run powersync:setup_web
```
Symptom: `Failed to execute 'compile' on 'WebAssembly': Incorrect response
MIME type`.

### Widget test harness
Before `Supabase.initialize` in tests:
- `TestWidgetsFlutterBinding.ensureInitialized()`
- `SharedPreferences.setMockInitialValues({})`
- `MethodChannel('plugins.flutter.io/url_launcher')` stub
- `authOptions: FlutterAuthClientOptions(detectSessionInUri: false)`

### Hot reload + PowerSync
"Multiple instances for the same database" warning on web — the old DB
instance lingers in the JS heap. Harmless. Use `R` (full restart) if it
gets annoying.

### Mobile OAuth redirect
The custom scheme `com.jardine.differentworld://login-callback` must be
in Supabase's **Redirect URLs allowlist** (no wildcards for custom
schemes — exact match). Native config changes (Info.plist,
AndroidManifest.xml) require a full rebuild, not hot reload.

### Web dev: port collisions silently break OAuth
Android Studio's Flutter Run button calls `flutter run` **without
`--web-port`**, so Flutter picks a random port (e.g. 56847). Chrome
opens there, but Supabase's OAuth callback redirects to the Site URL
(`localhost:3000`) where nothing is running → blank page after sign-in.

Two fixes, both committed:
- `.idea/runConfigurations/main_dart.xml` passes `--web-port=3000` to
  AS-launched runs. Keep it un-gitignored (see `.gitignore`).
- When starting from a terminal, always include `-d chrome --web-port=3000`.

If `flutter run` reports an unexpected port, check for orphaned instances:
```sh
lsof -nP -iTCP:3000 -sTCP:LISTEN
pgrep -fl "flutter_tools.snapshot.*run"
```
Kill stragglers before re-running. Multiple concurrent `flutter run`
processes against the same project will fight for port 3000 and one
silently falls back.

### Stale browser IndexedDB after Drift schema changes
When new Drift tables are added (and `dart run build_runner build` runs),
the local PowerSync SQLite schema also evolves. Browser IndexedDB
persists across reloads, so the old schema may linger. Symptom: app
boots blank or stuck in loading after a fresh codegen run.

Fix: in DevTools → Application → Storage → "Clear site data" with the
IndexedDB box ticked, then hard-refresh. One-time per major schema bump.

### `auth.uid()` returns null in REST requests on new (ES256-keyed) projects
Supabase projects created in 2025/2026 default to **ES256 asymmetric JWT
signing** (publishable key looks like `sb_publishable_…` instead of the
older `eyJ…` anon key). On at least one such project we observed:

- The user signs in successfully (auth.users + the `handle_new_user`
  trigger both work).
- The DB role on real REST requests IS set to `authenticated` (otherwise
  we'd get GRANT-level "permission denied for table"; we don't).
- But `auth.uid()` returns **null** in policy evaluation, so any RLS
  policy gated on `auth.uid() is not null` rejects with
  `42501 / new row violates row-level security policy`.
- `request.jwt.claims` is empty in PostgreSQL settings during the
  request — i.e., PostgREST authenticated the JWT enough to pick the
  role, but didn't populate the JSON claims GUC that `auth.uid()` reads.

Verified by running, in the Supabase Dashboard SQL editor:
```sql
begin;
select set_config('request.jwt.claims', '{"sub":"…","role":"authenticated"}', true);
select auth.uid() as uid; -- ← returns the UUID, so the function itself works
rollback;
```

Workaround in place (see migration `20260517000002_relax_write_policies.sql`):
INSERT/UPDATE/DELETE policies now gate on `current_user = 'authenticated'`
(the DB role) instead of `auth.uid()`. The GRANT layer (migration 6 gave
only `authenticated` INSERT/UPDATE/DELETE — never `anon`) is the real
gate; per-user RLS is temporarily disabled for writes.

Proper fix (when we get to it): figure out why PostgREST isn't
populating `request.jwt.claims`. Likely candidates:
- The legacy HS256 secret in Supabase doesn't match the new ES256
  signing key — PostgREST validates with one but the other is active.
- A Supabase project setting that disables claim extraction in favor of
  pure-signature verification.

For now, single-user dev safety is fine.

**Side-effect on RLS tightening.** Anywhere we'd naturally want a
narrow policy like
`for delete using (space_id = app.current_space_id() and app.is_director())`
we have to leave the relaxed `to authenticated using (true)` form
instead, because the inner check evaluates `auth.uid()` (null) and
rejects all writes. The known gap: invites can be deleted by any
authenticated user that knows the row id (low-impact at our scale —
invites are not high-value targets — but list it among the things to
re-tighten once JWT claims work).

**Server-side `SECURITY DEFINER` functions hit the same trap.** Even
though a `security definer` function runs as the function owner and
bypasses RLS, any `auth.uid()` call INSIDE the function still resolves
against `request.jwt.claims` — which is empty. So a function that
reads `auth.uid()` to know which user is calling it will see NULL
and do the wrong thing silently.

The workaround pattern: the function takes the auth user id as an
explicit `caller_uid uuid` parameter; the Dart client reads
`session.user.id` and passes it. The function `coalesce`s the param
with `auth.uid()` as a fallback. See migration
`20260523000003_accept_invite_explicit_uid.sql` — the canonical
fix for `accept_invite` that closed two bugs at once (the auth.uid()
NULL plus a stale `0 → boolean` type mismatch on the
subject_guardians INSERT). Apply the same shape to any new RPC that
needs to know who called it.

### PowerSync `uploadData` must guard against null Supabase session
`PowerSyncBackendConnector.uploadData` runs **independently** of
`fetchCredentials`. PowerSync drains the local CRUD queue whenever
there's anything pending, even if there's no active Supabase session.

The trap: `_supabase.from('programs').upsert(...)` does not require a
session — when none is set, supabase_flutter silently sends the **anon
key** as the Authorization header. PostgREST runs the query as the
`anon` role, `auth.uid()` is null, every RLS policy gated on
`auth.uid() is not null` rejects with `42501 / new row violates
row-level security policy`. Logs show an infinite retry loop and no
data ever lands.

The connector ([lib/core/sync/supabase_connector.dart](lib/core/sync/supabase_connector.dart))
guards by:
- Checking `currentSession` at the top of `uploadData` and throwing
  (so PowerSync re-queues for retry) when it's null.
- Proactively refreshing the access token when it's within 60s of
  expiry, in both `fetchCredentials` and `uploadData`.

Distinguishing the two RLS-related errors:
- **`permission denied for table X`** → GRANT-level missing on the role
  (the table itself isn't accessible at all). Fix: see migration 6.
- **`new row violates row-level security policy for table X`** → GRANT
  fine, RLS policy rejected the row. With our policies that means
  `auth.uid()` was null at evaluation time — almost always because the
  upload ran without a valid session.

### `PdfGoogleFonts.*()` downloads at print time — breaks offline-first

`PdfGoogleFonts.interMedium()` (and every `PdfGoogleFonts.*` helper from
the `printing` package) **fetches the TTF from Google's Fonts CDN over the
network the first time it's called**, then caches it. In a PDF builder this
reads like innocuous local code, but it silently violates the
offline-first invariant: a teacher generating a PDF (poster, QR sticker,
report) on a device that's offline — or just behind a captive portal /
slow tower — gets a hung or thrown future, surfaced as a generic
"couldn't build" error with no recovery path. It hides in dev because
your machine is always online and the font caches after the first fetch.

Rule: **never call `PdfGoogleFonts.*` (or the `google_fonts` package's
runtime fetch) in code that must work offline.** For PDF text, use a
built-in standard font — `pw.Font.helvetica()` / `.helveticaBold()` /
`.times()` / `.courier()` — which is embedded in every PDF reader, needs
zero network and zero asset. If you genuinely need a branded typeface,
bundle the `.ttf` as a Flutter asset and load it via
`pw.Font.ttf(await rootBundle.load('assets/fonts/X.ttf'))`. The poster
engine (`lib/features/poster/poster_engine.dart`) uses Helvetica for this
reason. (`vehicle_qr_pdf.dart` still uses `PdfGoogleFonts` — lower-impact
since QR stickers are printed at online setup time, but it's the same
hole; fix when touched.)

### Offline attachment uploads: `uploadOnly`'s `entityId` MUST be the attachment row's `id`

`PhotoService.uploadOnly(entityKind: 'attachment', entityId: X, picked: …)`
returns the real Storage path when online, but a `pending:<id>` token when
offline (it enqueues the bytes for later). When that deferred upload lands,
`PhotoUploadQueue` patches the row via
`attachmentsDao.updateUrl(entityId, realPath)` — i.e. `UPDATE … WHERE
attachments.id == entityId`. So the `entityId` you pass to `uploadOnly`
**must be the SAME id the attachment row is created with**
(`AttachmentActions.add(id: …)`). Pass anything else (e.g. the parent
entry/log id) and the queue patches a non-existent row: the attachment keeps
`pending:` forever and the photo is **silently lost** — but ONLY offline
(online returns the real path immediately, which is why the bug hides).

Pattern: pre-generate `final attId = const Uuid().v4();` and pass it to BOTH
`uploadOnly(entityId: attId)` AND `attachments.add(id: attId, …)`. When the
upload and the row-create are decoupled in time (observation form: upload at
photo-pick, add at save), thread the id between them (a `url → attId` map),
or for `createObservation` pass `photoIds:` aligned with `photoUrls:`.
Reference impls: `vehicle_inspection_screen._submit`,
`observation_form_screen` + `EntryActions.createObservation`. This bit
observations (offline obs photos lost) until 2026-06-02.

### PowerSync join tables still need an explicit `id` column

PowerSync auto-adds `id TEXT PRIMARY KEY NOT NULL` to every replicated
table in the local SQLite. If your Postgres schema uses a composite
primary key (e.g. `(group_id, member_id)`) and no `id` column, the
local table has the implicit `id` BUT Drift doesn't know about it and
generates INSERTs without it. SQLite rejects with constraint code
**1811: "id is required"** and the upload retries forever:

```
[ERROR] SqliteException(1811): id is required, constraint failed
  Causing statement: INSERT INTO "group_members" ("group_id", ...)
```

Fix: every synced table — including join tables — gets an explicit
`id uuid` PK on the server. Demote the composite to `UNIQUE`. In the
Drift class, declare `TextColumn get id => text()();` and set
`primaryKey => {id}`. Generate the UUID client-side at insert time
(`const Uuid().v4()`).

This caught `group_members` and `subject_guardians`. Anywhere a future
join table is tempted to use `primary key (a, b)`, do `id` + UNIQUE
instead.

### `42501 permission denied` on PowerSync uploads
PostgreSQL's privilege check fires **before** RLS evaluation. If
`authenticated` doesn't hold table-level SELECT/INSERT/UPDATE/DELETE
grants, even a perfectly-correct RLS policy can't save the upload —
you get 42501 in PowerSync's `Caught exception when uploading` loop.

Symptoms: reads work fine (PowerSync replication uses a different role
and bypasses PostgREST), but every CRUD upload fails forever and the
sync queue piles up locally.

Fix: ensure `authenticated` has `select, insert, update, delete on all
tables in schema public` plus matching `alter default privileges`. See
migration `20260517000001_restore_role_grants.sql`. Any time you `drop
schema public cascade` for any reason in dev, re-run that GRANT block
or all subsequent CRUD breaks silently.

### Family lens — what reaches a guardian device, and what doesn't
The `by_space` stream gates every query on
`space_id IN (SELECT space_id FROM members WHERE id = auth.user_id())`.
A guardian has a `members` row (the `handle_new_user` trigger creates
one for every auth identity) but its `space_id` is null — they live
in `guardians`, keyed by `user_id`. So `by_space`'s membership
subquery evaluates to `IN (NULL)` and **no rows from `by_space` ever
reach a guardian's device.** Intentional for the heavy staff-only
data (vehicle logs, observation feed for every kid in the program),
but it leaves the family lens with an empty mirror.

The fix has two pieces:

**1. `by_guardian` PowerSync stream** (in `supabase/sync_rules.yaml`).
Mirrors the per-guardian rows the family lens reads, keyed on
`guardians.user_id = auth.user_id()`. Five single-level subqueries
— the same shape `by_space` uses — so we know the PowerSync SQL
subset accepts them:
- `guardians` — the guardian's own row (drives `currentGuardianProvider`)
- `spaces` — the guardian's program (drives `currentSpaceProvider`)
- `subject_guardians` — child links (drives `myChildSubjectIdsProvider`)
- `messages` — staff↔guardian threads (drives every messages provider)
- `export_recipients` — recipient rows (audit-side; the parent
  `exports` row still comes via PostgREST because it'd need a 2-level
  subquery)

These reads are **offline-first** for guardians — Drift watches keep
the UI live, mutations queue locally just like staff.

**2. PostgREST stopgap for per-subject reads.** Subjects, attendance
records, entries, attachments are keyed on `subject_id` and need a
2-level subquery (`subject_id → subject_guardians → guardian →
user_id`) which PowerSync's SQL subset hasn't been verified to
accept. Until we settle that, family-side reads of those tables go
through direct PostgREST in `lib/features/family/family_providers.dart`:
- `familyChildrenProvider` (replaces `myChildrenProvider` for the
  family path)
- `familySubjectByIdProvider`
- `familyAttendanceForSubjectProvider`
- `familyEntriesForSubjectProvider`
- `familyAttachmentsForEntityProvider`

RLS on these tables is `for select to authenticated using (true)`
so PostgREST returns rows for any authenticated caller; each
provider re-checks `viewer.canSeeSubject(id)` as a defensive layer.
Pedigree of the relax — the universal-rename migration narrowed
several of these to `space_id = app.current_space_id()`, which
silently broke guardian-side reads (the ES256 `auth.uid()`-null
gotcha makes `current_space_id()` return null). Two follow-up
migrations restored the broad SELECT so the family lens works:
`20260523000001_relax_exports_read.sql` (exports + export_recipients)
and `20260523000002_relax_family_reads.sql` (subjects +
subject_guardians + attendance_records). `entries` and
`attachments` were never narrowed by the rename and stayed broad
the whole time. Trade-off: these reads are NOT offline-first — a
cold launch without network shows empty until the round-trip
lands. Acceptable for the per-child timeline; messages stay
offline-first because they go through the new stream.

**When adding new family-facing data:**
- If the row is keyed directly on a single guardian id → add it to
  `by_guardian` with the existing 1-level-subquery pattern. Stays
  offline-first.
- If the row is per-subject → add a `familyXProvider` PostgREST
  fetcher next to the others. Document the same trade-off.
- A future improvement is to test whether PowerSync accepts the
  2-level subquery for `subjects` / per-subject rows. If yes, the
  family lens becomes fully offline-first. If not, denorm
  `guardian_user_ids jsonb` on each per-subject table (populated by
  triggers from `subject_guardians`).

**Adding to or changing `by_guardian` requires a PowerSync dashboard
deploy** — the YAML in the repo is the source of truth; the dashboard
is the runtime. After deploy, every signed-in guardian device needs a
local-storage wipe (uninstall on mobile; "Clear site data" on web)
to recreate the local SQLite with the new tables.

### A list stored in caps JSON needs a serialized read-modify-write

When you store a LIST inside a `capabilities` jsonb cell (the no-migration
trick: `day_templates`, future world-facet content, etc.) and edit it
through optimistic actions, every mutator is a **read-modify-write of the
SAME cell**: load the whole list → mutate → `setStringCap` the whole list
back. Two mutations racing (classic trigger: a drag-reorder's
`unawaited(...)` write overlapping a delete tap) both read the same
pre-write state and the second `_save` silently **clobbers** the first —
the reordered block snaps back after the delete lands. Single-cell sync
makes this worse: PowerSync resolves the whole `capabilities` cell, so
cross-field races exist too.

Fix: chain every mutator through a `Future<void> _pending` queue so they
apply in order, and make the tail never-rejecting so one failed write
can't block the rest:
```dart
Future<void> _pending = Future<void>.value();
Future<void> _mutate(String spaceId, Update update) {
  final op = _pending.then((_) async {
    final list = await _load(spaceId);          // read
    await _save(spaceId, update(List.of(list))); // modify + write
  });
  _pending = op.catchError((Object _) {});        // keep the queue alive
  return op;                                      // caller still sees errors
}
```
The actions object must be a stable singleton (a `Provider<XActions>`) so
`_pending` persists across calls. Reference impl:
`lib/features/schedule/day_template_providers.dart`. (A real table with
per-row PKs doesn't have this problem — it's specific to list-in-a-cell.)

### Any family-facing / exported artifact built from staff free-text must scrub other-child names

Staff free-text fields routinely NAME another child — an observation
`body` ("Sofia and Mateo built a fort"), the weekly-log `ally`
("worked with Sofia"), an incident narrative. That's fine **staff-side**
(canSeeSubject-gated). But the moment that text crosses into a
FAMILY-FACING or EXPORTED artifact for Child A — a sent-home PDF, a
family-lens screen, a future showcase video — another child's name in it
leaks Child B's identity into Child A's keepsake. This is a recurring
CLASS, not a one-off: the incident form already strips it server-side
(`app.family_incidents_for_subject`); the Summer Book PDF now scrubs it
client-side (`anonymizeSummerBook` + `scrubOtherNames` in
`summer_book.dart`, wired in the Book screen's export action).

Rule: **before ANY staff free-text renders into a family/export surface,
run it through a roster-name scrub** — replace any OTHER enrolled child's
first/last name (from `subjectsInSpaceProvider`, minus the subject the
artifact is FOR) with a generic token ("a friend"). The subject's own
name + all curriculum/structured content stay. Reach for
`scrubOtherNames(text, otherNames)` / `anonymizeSummerBook(...)` as the
reference shape; don't hand-roll a one-off.

Two deferred surfaces will hit this exact trap when built — the
family-facing Book (the "swap to the family entries provider" path) and
the showcase / growth-arc compilation — so they MUST anonymize before
they ship. The stronger fix (reference collaborators by `subject_id`,
resolve the display name staff-side only) removes the reliance on
name-matching, but the export-path scrub is the guarantee that holds
today. Acceptance bar for any such surface: a unit test that flattens
the rendered artifact for Child A and asserts no other child's name
appears (`test/unit/summer_book_privacy_test.dart` is the template).

### The block run sheet is ONE bento per block KIND — not a list (+ trip maps)

`block_run_sheet_screen.dart` gives every block KIND a single one-tray bento
(no scrolling list). The tray content is kind-specific:
- **activity** — Start/runner + how-it-runs + supplies + cast + capture.
- **photo / curriculum** — Run the session deck + photo turns + … . A scripted
  block's "how it runs" + "you'll need" derive from the **SCRIPT**
  (`scriptForSession`), **NOT** the stale `PhotoSession` summary.
- **field_trip** — the embedded OSM map (`flutter_map`, **no API key**) with
  destination + live "we're here" pin (`geolocator`) + Get-directions
  (`url_launcher`) + headcount + emergency (allergies + guardian `tel:` call) +
  notify + prep.
- **break / closed** — a calm note + capture.

**DEFERRED — trip-location migration not pushed.** `20260622000002_trip_location.sql`
(adds `trip_logistics` coords / pin columns) is written but **NOT pushed**
(Supabase pooler timeout, status 544 — retry when reachable). Until it lands the
pin writes won't sync; the local schema changed, so a device **clean-reinstall is
needed** to recreate the local SQLite.

---

## Mutations: write through Drift, sync through PowerSync

```dart
await db.transaction(() async {
  await into(programs).insert(ProgramsCompanion.insert(...));
  await (update(profiles)..where(...)).write(ProfilesCompanion(...));
});
```

Local writes commit immediately to SQLite. PowerSync's CRUD queue picks
them up and uploads via `SupabaseConnector.uploadData`. RLS on Supabase
is the actual gatekeeper — failed uploads retry on the next sync cycle.

Don't bypass Drift to write directly to Supabase unless the local view
should be stale until the next sync round-trip (it usually shouldn't).

---

## Branch workflow

**All feature work happens on branches, never directly on `main`.**

- Start a new session: `git checkout -b <feature>` (e.g. `feat/missions-phase3`,
  `feat/live-sessions`, `fix/review-council-bugs`). One branch per logical
  feature cluster — not per commit.
- Commit freely on the branch. Push with `git push -u origin <branch>`.
- When the cluster is done + reviewed + tests pass: open a PR or merge into
  `main` explicitly. Never `git push origin main` from an in-progress branch.
- `main` = releasable at all times. The branch is where the work lives.

**For migrations:** `supabase db push` can be run on a branch — the dashboard
is the runtime and doesn't care about git branches. Just don't forget to push
the migration file to the branch before merging.

## Tooling permissions granted

- `Bash(supabase db push:*)` — run migrations directly after writing
  them. The CLI's own y/N prompt is the user's checkpoint.

## Default run target — the Pixel 6 (wireless)

When testing changes, run on the user's Pixel 6 over wireless ADB:

```sh
flutter run -d adb-1A291FDF6002RQ-JYcM2v._adb-tls-connect._tcp 2>&1 | tee /tmp/dw-pixel.log
```

Background it via `tee /tmp/dw-pixel.log` so you can tail logs later.
Don't switch to Chrome / macOS as the default — phone is the primary
testing surface (the app is phone-first). Web is a secondary
verification, not the default. If the Pixel is disconnected, tell the
user; don't silently fall back to a different device.

**Redeploy after every commit.** The user has set the standing
preference: any wave that lands on `main` should be followed by a
Pixel redeploy in the background (so they can hot-restart / cold-
launch as soon as the APK lands). Don't ask before redeploying;
just kick it. Filter the log monitor to `Built build|Syncing
files|Hot reload|Exception CAUGHT|Lost connection|Build failed`
— routine PowerSync stream blips are noise, don't surface them.

## Dev flags — the in-app "flag this screen" button

The user can **flag a screen for review** by tapping the floating flag
(bottom-right; **debug builds only**, gated on `kDebugMode` in
`lib/shared/widgets/app_shell.dart` → `lib/features/dev_flags/dev_flags.dart`).
Each tap appends `{route, label, note, timestamp}` to a JSON file in the app's
sandboxed docs dir on the device; an optional note can be added from the toast.

**When the user references "the screens I flagged" / "my flags" — or at the
start of a session that follows on-device testing — run
`scripts/read_dev_flags.sh`** to pull them off the Pixel
(`adb run-as … cat app_flutter/dw_flags.json`). The output is the route +
note + timestamp for each flag — i.e. exactly which screens (and entities, since
the route carries ids) to open and address. This replaces "go back and find the
screen I meant." Flags persist on the device across sessions; there's no
auto-clear, so treat older timestamps as possibly-already-addressed.

---

## Commands

```sh
flutter analyze                    # must be clean before declaring done
flutter test                       # widget + unit
dart format lib test tool integration_test   # whole repo formatted 2026-07-04; keep it that way
flutter run -d chrome --web-port=3000   # web (port matches Supabase Site URL)
flutter run -d <device>            # mobile / desktop

dart run build_runner build        # after Drift table or freezed class changes
dart run powersync:setup_web       # web worker assets, once + after version bumps

supabase migration list --linked   # which migrations applied on server
supabase db push                   # apply new migrations
```

## When to run cleanup (the "flutter clean" decision tree)

These steps come up at predictable moments. Run them proactively when
the trigger appears — don't wait to be asked.

### `flutter clean && flutter pub get`
Run when:
- A **pubspec.yaml dependency was added/removed/upgraded**
- **`git pull` brought in pubspec.yaml changes** from another machine
- Mysterious **build errors** that don't match the source (cache rot)
- After **build_runner crashes or partial regens**
- Switching between branches with different Flutter / Dart versions

### `dart run build_runner build`
Run when:
- **Drift table classes changed** in `lib/core/db/app_database.dart`
- **Freezed classes** or **json_serializable** classes changed
- Any `.dart` file with codegen annotations was edited

If build_runner says **"wrote 0 outputs"** but you know the source
changed, run **`dart run build_runner clean && dart run build_runner build`**
to force a full regen. drift_dev's incremental cache can lie.

### `dart run powersync:setup_web`
Run when:
- **First time** setting up the project locally
- **`powersync` package version bumped**
- The `web/sqlite3.wasm` or `web/powersync_db.worker.js` files are
  missing (e.g., a `git clone` won't have them — they're gitignored).
- Browser console shows
  `Failed to execute 'compile' on 'WebAssembly': Incorrect response MIME type`.

### **Clear local device storage** (this is the one we keep forgetting)
Run when:
- A migration **renamed a table or column** that PowerSync syncs
- The **PowerSync `appSchema` declaration in Dart changed** (table
  added/removed/renamed, column added/removed/renamed)
- App boots and gets stuck on **"Syncing your profile…"** forever
- Logs show **`Validated and applied checkpoint`** but the UI shows
  empty data
- Symptoms of a **silent schema mismatch** between local SQLite and
  server.

How to clear:
- **Web (Chrome)**: DevTools → **Application** tab → **Storage** →
  "Clear site data" with all boxes ticked (especially IndexedDB and
  Cache Storage). Then hard refresh.
- **Android**: **uninstall the app** from the device, then
  `flutter run -d <device>` again. App data → gone → fresh local DB.
- **iOS**: same — delete the app from the simulator/device.
- **Desktop (macOS)**: delete the local DB file under
  `~/Library/Application Support/com.jardine.differentworld/`.

Why: PowerSync's local schema reconciliation is **additive but not
rename-aware**. If you rename `profiles` → `members` in the schema,
PowerSync may create `members` empty while leaving `profiles` with
the old data — Drift queries on `members` find nothing forever.
Wiping the local DB forces a clean schema + full re-sync.

### `supabase db push`
Run after **writing a new migration** to `supabase/migrations/`. The
Bash permission rule `Bash(supabase db push:*)` allows this directly —
don't hand it back.

### The full sequence after a Drift schema rename
For future-me's sanity, if a Drift schema rename is involved:

1. Write the SQL migration (`supabase/migrations/<ts>_<name>.sql`)
2. Update `lib/core/db/power_sync_schema.dart` to match
3. Update `lib/core/db/app_database.dart` (Drift classes) to match
4. Update every consumer in `lib/` to use the new names
5. **`supabase db push`** — apply server-side
6. Update `supabase/sync_rules.yaml` in the repo
7. **PASTE THE NEW SYNC RULES INTO THE POWERSYNC DASHBOARD AND HIT
   DEPLOY.** The repo file is just our source-of-truth; the
   dashboard is the runtime. Forgetting this leaves PowerSync's
   queries pointing at the old (now non-existent) tables. The sync
   "succeeds" with zero rows; local tables stay empty; the app sits
   on its loading spinner forever with no error in the logs.
8. **`dart run build_runner build`** — regenerate `.g.dart` files
9. **`flutter clean && flutter pub get`** — wipe build cache
10. **`flutter analyze`** — confirm zero issues
11. **`flutter test`** — confirm passing
12. **Tell the user to clear local storage on every active device**
    (uninstall on mobile, clear site data on web). Local SQLite needs
    to recreate itself with the new schema.

If symptoms are "Validated and applied checkpoint" but **no
`downloading: true (progress: X/Y)` line** and the local tables are
empty when you query them, step 7 is the culprit 99% of the time.

---

## Review pipeline — the council pattern

Single-reviewer agents have correlated blind spots. The review
pipeline runs parallel perspectives and a synthesizer that catches
what they all missed:

1. **Flutter Preflight** — code-correctness via 9 specialist
   guards (lifecycle, state, async, platform, performance,
   security, build, flame, sync). Pattern-based.
2. **Red Team** — adversarial review. SCENARIO-based: "what if a
   user spams this? what if they're offline mid-flow? what if a
   kid taps the gesture wrong?" Finds privilege drift, race
   conditions, edge data, kid-tap exploits, sync edge cases that
   pattern-matching alone misses.
3. **UX Critic** — fresh-user review: IA, copy, discoverability,
   flow, density. Finds buried features (vehicles-off-screen),
   confusing copy, friction.
4. **Screen Rubric** — structural per-screen gate against
   [docs/SCREEN_RUBRIC.md](docs/SCREEN_RUBRIC.md): chrome/viewport
   clearance, the four states (loading/empty/error/data),
   composition primitives, interaction integrity, a11y,
   offline-first. The mechanical "does this screen satisfy the
   checklist" pass — the layer that ends recurring layout/state
   defects (content under the chrome, a list with no empty state,
   a tap that does nothing). Spawned only when a change touches a
   screen. The rubric is the source of truth; the agent enforces it.

Above them: **Review Council** — orchestrator that spawns
the relevant tracks in parallel and synthesizes. The synthesizer looks for
CROSS-CUTTING findings — things no single reviewer flagged but
that emerge from combining perspectives (e.g. UX says "user can
re-tap fast" + Preflight finds no idempotency guard = real
double-fire bug). It also names coverage gaps when the diff
touches a domain none of the reviewers cover.

When to invoke:
- `/ship` runs the Council automatically (step 3 of the checklist)
- For substantive non-ship changes, run Council explicitly before
  committing the work that touches user-facing surface, sync, or
  permissions
- For small, pure-internal refactors, Preflight alone is fine —
  Red Team and UX Critic correctly report "nothing for me" on
  those

The agents live in `~/.claude/agents/`:
- `red-team.md`
- `ux-critic.md`
- `screen-rubric.md` (enforces [docs/SCREEN_RUBRIC.md](docs/SCREEN_RUBRIC.md))
- `review-council.md`
- `flutter-preflight.md` (plus 9 specialist guards)

Adding more reviewers later (e.g. a SQL-policy critic, a
performance-budget critic) — define them in the same dir, then
wire them into the Council orchestrator's parallel-spawn step.

### Closing the loop — every confirmed bug hardens the pipeline

A reviewer, guard, or on-device session that finds a bug has done
HALF the job. The other half: make sure that *class* of bug can't
recur silently. **Every confirmed bug gets a durable home so the next
session inherits the lesson** — pick the narrowest one that fits:

1. **A guard checklist item** (`~/.claude/agents/flutter-*-guard.md`,
   `interaction-guard.md`, …) — when the bug is a PATTERN a guard
   should pattern-match (a lifecycle / async / state / platform
   footgun). **This is the default**: it makes the pipeline catch the
   bug automatically on every future run, for every file. Add a
   `- [ ]` line to the right guard's checklist.
2. **A "Known gotcha"** (this file) — when the bug is PROJECT-SPECIFIC
   and non-obvious (a PowerSync / Drift / RLS / go_router / ES256 trap
   unique to this stack), not a generic pattern a guard could phrase.
3. **A regression test** — when the bug is concrete behavior a test
   can pin (a reducer case, a widget-state transition). The tightest
   net; add it AND consider 1 or 2 for the broader class.

Most bugs want #1. The bar: after you fix a bug, ask *"what would have
caught this before I wrote it?"* — then add exactly that. A guard's
checklist is cheap to extend and compounds; a bug fixed without
hardening the pipeline is a bug we'll write again.

**Worked precedent (Wave 0c, the live-game port).** Preflight found
three lifecycle/async bugs: (1) the live controller was disposed from
two paths (`_leave` AND `State.dispose`) with no idempotency guard;
(2) two of three Realtime stream sinks (`_peers`/`_status`) were
`.add()`-ed from late callbacks after `close()` with no `isClosed`
guard — the genuine add-after-close throw, because only `_states` was
guarded; (3) `setState` inside a `.listen` callback with no `mounted`
guard. Notable: the two reviewers disagreed on whether
`StreamController.close()` itself throws on a double-call — it does
NOT (it's idempotent), so verifying the Dart contract mattered before
writing the rule. The real throw was #2. All three were fixed AND
folded back as `- [ ]` items in `flutter-async-guard.md` +
`flutter-lifecycle-guard.md` — so the guards now flag the *class*, not
just that instance. That's the loop (and the fact-check is part of
it — don't codify a rule a reviewer asserted without confirming it).

## "Done" means

For substantive changes:
- `flutter analyze` — "No issues found"
- `flutter test` — all passing
- `dart format` on the files you touched — the whole repo was formatted in
  one mechanical pass (commit `1a877e6`, listed in `.git-blame-ignore-revs`);
  don't let new code drift back off the formatter
- UI changes: exercised in a browser, or stated as not yet exercised
- Sync / lifecycle changes: Flutter Preflight (stop-hook reminds once per
  session)
- Shipping: also Flutter QA Gate, or use `/ship`

For exploratory / scoping conversations: no gate, just answer.

---

## Pausing & handoff — the baton lives in the repo, never the chat

An unfinished task survives a session boundary only if its resume-state
is durable, discoverable, and co-located with the code. The conversation
is the WORST place to store it: transcripts are ephemeral, transcript
search is permission-gated, and a session rarely surfaces by an obvious
title. We retrieved a whole in-flight wave (Wave B) purely from repo
artifacts — the previous commit's `Next:` line, the diff, and a design
doc — because the repo, not the chat, was the system of record. Keep it
that way.

**When you pause mid-task (or sense a session may end), leave a baton:**

1. **The handoff IS a commit.** A wave that lands gets a body with a
   `Done / Next / Risks / Verify` block — not a one-line "what". The
   `Next:` line is the single most valuable breadcrumb; it's what lets
   the next session pick up cold. (See commit `da4c9cc` for the shape.)
   - **Done** — what changed, grouped by concern, with the *why*.
   - **Next** — the very next concrete step (the unstarted slice).
   - **Risks** — knowingly-deferred issues, each marked as deferred (not
     a regression), so a reviewer doesn't re-discover them as "bugs".
   - **Verify** — what you ran (analyze / tests / reviewers) and what's
     still unexercised (e.g. on-device tap-through).

2. **The safety net is automatic.** The `handoff-snapshot` Stop hook
   (`~/.claude/hooks/handoff-snapshot.sh`, wired in `~/.claude/settings.json`)
   writes `docs/handoff/<branch>.md` on every dirty turn and deletes it
   when the tree goes clean. It's gitignored (describes local uncommitted
   state, so it stays local) and scoped to this repo by pubspec name. It
   holds the last commit, the changed-file list, and the working diff —
   so even a hard crash before a clean exit leaves a snapshot on disk.
   **On resume, if `docs/handoff/<branch>.md` exists, the tree was dirty
   when the last session ended — read it first**, then the last commit's
   body. It is the net BELOW the commit, never a replacement: a snapshot
   has no "why" and no "Next". Commit the real baton when you can.

---

## What's intentionally deferred

- **App splits (Family / Room Screen / Games as separate SKUs)** — the
  strategy, triggers, and monorepo mechanics live in
  [docs/APP_SPLITS.md](docs/APP_SPLITS.md). Deliberately deferred: one
  app until real external families exist (the Family split fires first).
- **Native `google_sign_in`** for smoother mobile UX (current flow opens
  external browser — works, slightly clunky on iOS/Android)
- **Sentry / crash reporting** — env slot ready, wire near ship
- **Edge Function broker for vendor API keys** — Deepgram + OpenAI
  master keys currently live in `.env` → end up in the compiled
  binary, recoverable from the APK/IPA. For personal-dev that's
  acceptable risk (set vendor-side spend caps + rate limits); for
  EXTERNAL ROLLOUT, broker through Supabase Edge Functions so the
  master key never reaches the device. See `docs/SECRETS.md` for the
  full pattern (Deepgram supports short-lived `/v1/auth/grant`
  tokens; OpenAI uses a simple REST proxy).
- **Push notifications** (late pickup alerts, etc.) — separate concern
- **App icons + splash + store listings**
- **Release signing configs** (Android keystore, iOS certs)
- **Custom Supabase domain** (cosmetic — removes `*.supabase.co` from
  OAuth URL)
- **Background photo upload + thumbnail generation** — when we wire
  observations
- **`sign-photo` bucket lockdown** — `20260903000001_person_photos_broker_only.sql`.
  Until 2026-09-03 this entry said the migration was "written but not pushed";
  it had in fact never been written. It exists now, and is deliberately NOT
  pushed: the gate is a **signed-in on-device check** that photos still render
  on three path shapes (subject, attachment, family), which the file spells out.
  The failure mode is total rather than graceful — a broker that is broken for
  any shape blanks every photo the moment the fallback policy goes — so the
  check is the whole safety margin. Rollback is one statement.
- ~~`20260622000002_trip_location.sql`~~ — **APPLIED.** This entry claimed it
  was blocked on a pooler timeout; verified 2026-09-03 by probing the column
  (`GET /rest/v1/trip_logistics?select=destination_lat` → 200) and by
  `supabase migration list --linked`, which shows every migration on disk
  applied. The trip pin writes sync. Nothing is pending here.

## Interaction invariants — input surfaces

The omnibox, the observation form, and every TextField-bearing screen
have to honor a small set of rules to feel right on a real device.
We've broken these enough times to write them down. The
**`Interaction Guard` agent** enforces them by pattern; this section
documents them as testable assertions.

### The rules

1. **Bar focus survives route pushes triggered by typing.** If a
   keystroke causes a `context.push(...)` (e.g. `/search` pops up
   because the user typed), the originating TextField MUST still own
   primary focus after the push lands. Mechanism: the route push
   rotates the active FocusScope; the bar lives outside the pushed
   route's scope chain, so its focus drops; a focus listener
   reacting INSIDE the push window (~500ms) must re-request focus +
   call `SystemChannels.textInput.invokeMethod('TextInput.show')` to
   keep the Android IME up.
2. **Suggestion taps must dispatch.** Tapping a list item / chip /
   suggestion MUST result in either navigation, a visible UI
   response, or a snackbar. NO silent no-op `onTap` handlers. The
   classic break: `onTap: (ctx, _) { if (foo == null) return;
   ctx.push(...); }` — drop the entry from the catalog entirely if
   `foo` can be null, OR show a fallback.
3. **Post-pop dispatch needs a stable context.** Any handler that
   does `context.pop()` and then `addPostFrameCallback` to fire an
   action MUST capture a long-lived context (e.g.
   `Navigator.of(context, rootNavigator: true).context`) BEFORE the
   pop. The popped route's context deactivates the moment pop runs;
   `context.mounted` becomes false; the action silently never fires.
4. **`requestFocus` alone doesn't show the IME on Android.** Any
   programmatic focus restoration MUST be followed by an explicit
   `SystemChannels.textInput.invokeMethod('TextInput.show')`. Flutter's
   framework treats focus-restoration as a focus-already-held event
   and skips the implicit show.
5. **Modal sheets during active text input lose focus.** Avoid
   `showModalBottomSheet` / `showDialog` from a TextField's
   `onChanged` — defer to `onSubmitted` or pre-dismiss the keyboard
   with `_focus.unfocus()` first.
6. **No hardcoded delays for focus / keyboard timing.** No
   `Future.delayed(Duration(milliseconds: 100), ...)` to "let the
   keyboard finish." Use `addPostFrameCallback`, listen to the focus
   event, or use a completion signal.
7. **Multi-child layout widgets with conditional children require
   stable `Key`s.** `Stack`, `Column`, `Row`, `Wrap`, etc. — if any
   child is conditional (`if (...) widget`) or the children list
   grows / shrinks at runtime, every child MUST carry a stable
   `ValueKey`. Otherwise inserting a child shifts Flutter's
   position-based Element matching, and a `TextField` sibling will
   silently rebuild and lose its `TextInputConnection` → the soft
   keyboard closes mid-interaction. See "Stack children without
   keys" in Known gotchas.

### What to test

Every input-surface widget should have a widget test (or contribute
to one) that asserts:

- `tester.tap(find.byType(TextField))` → focus arrives within one
  pump.
- `tester.enterText(find.byType(TextField), 'a')` → if this triggers
  a route push, after `tester.pumpAndSettle()` the same TextField
  still holds primary focus.
- Tapping a suggestion / item that depends on optional data — when
  the data is null, the entry must NOT render (don't assert that the
  tap does nothing — assert the entry isn't in the tree).

`test/widget/omnibox_interaction_test.dart` is the canonical
example.

### When to run the Interaction Guard

Auto-invoke (via the `feature-registry-stop-gate.sh` sibling hook)
on any change to:
- `lib/shared/widgets/app_shell.dart`
- `lib/features/omnibox/**`
- Any file containing a `TextField`, `FocusNode`, `GestureDetector`,
  `onTap`, or that calls `showModalBottomSheet` / `context.push`
  from a UI-event callback.

You can also invoke it manually: `Agent interaction-guard` against
the diff or a file path.

---

## Composer / chrome architecture (the omnibox spine)

The bottom omnibox bar in AppShell is the canonical surface for find /
do / dictate. Some key invariants:

- **The suggestion overlay's CONTENT must clear the top chrome as a
  whole — inset the body, not just the list.** The overlay glass
  (`GlassPanelShape.overlay`, the full-bleed BackdropFilter in
  app_shell) intentionally fills `top: 0` so the blur covers everything
  with no seam; the floating chrome pills paint on top of it. But the
  *content* (`OmniboxSearchScreen`'s `body`) must start BELOW the
  chrome, or anything at the top of its column renders behind the
  pills. This has regressed more than once: the fix is a single top
  inset (`MediaQuery.paddingOf(context).top + ShellMetrics.topChromeHeight`)
  on the WHOLE overlay body — NOT on the inner suggestion `ListView`
  alone. Insetting only the list leaves the recent-captures strip + the
  capture-hero card (which sit ABOVE the list in the column) behind the
  chrome on first open. Route mode (pushed `/search`) clears chrome via
  `EdgeScaffold`; only overlay mode needs the explicit body inset.
- **Top-chrome clearance is AUTOMATIC for every EdgeScaffold route —
  don't add per-screen `topChromeHeight` math.** This used to regress
  constantly ("new screens overlap the chrome") because clearance was
  opt-in: a screen only cleared the floating pills if it remembered to
  put a `ContentHeader` first (which reserved `statusBar +
  topChromeHeight`). Grids, custom headers, and the host-run game
  screens floated underneath. **Fixed for good:** `EdgeScaffold`
  publishes the chrome band into the body's `MediaQuery.padding.top`
  (kid-mode-gated → reserves 0 when AppShell hides the chrome). So any
  `SafeArea` *or* `ContentHeader` in ANY body clears the pills with no
  per-screen code — the reservation lives in the scaffold, not each
  screen, so it can't be forgotten. Consequences for new code: (1)
  `ContentHeader` reads `MediaQuery.padding.top` and does NOT add
  `topChromeHeight` itself — re-adding it double-insets every screen by
  56 dp. (2) A non-scrolling / centered body just needs a `SafeArea`
  and it clears automatically. (3) A full-bleed body (the camera) opts
  out by using NO `SafeArea` — chrome floats over it by design. (4) The
  ONLY places that still add `topChromeHeight` by hand are the omnibox
  *overlay* (not an EdgeScaffold) and anything rendered outside the
  shell. Don't reintroduce the per-screen inset.
- **A raw `Scaffold` (NOT `EdgeScaffold`) used for a full-bleed surface
  INSIDE the shell gets the floating chrome painted OVER its content —
  this is a recurring trap.** The shell's top pills + bottom omnibox bar
  live in AppShell's Stack ABOVE the route, and a raw `Scaffold` neither
  reserves the top band (only `EdgeScaffold` publishes it into
  `MediaQuery.padding.top`) nor suppresses the bar. So the surface's
  header hides behind the top pills and its bottom controls hide behind
  the omnibox bar. Two correct fixes: (a) use `EdgeScaffold` (gets
  clearance) if you WANT the chrome; or (b) for a true full-bleed
  presentation/cockpit that wants NO chrome, set an **immersive
  provider** (`speakImmersiveProvider`, `castImmersiveProvider`, or
  kid-mode) so AppShell hides the pills + bar entirely. A bare
  `Scaffold` + `SafeArea` clears only the OS status bar, NOT the app
  chrome — that's the bug. The cast cockpit shipped this and had to be
  fixed with `castImmersiveProvider`. For true OS fullscreen on a
  presentation screen (hide the status/nav bars too), ALSO call
  `SystemChrome.setEnabledSystemUIMode(immersiveSticky)` on mount +
  restore `edgeToEdge` on dispose (see `cast_receiver.dart`,
  `game_fullscreen.dart`).
  - **The `Navigator.push` variant of the same trap (audited 2026-07-05):**
    a full-bleed `MaterialPageRoute` pushed with plain
    `Navigator.of(context)` lands on the SHELL navigator (the ShellRoute
    owns its own Navigator), so it renders INSIDE the shell — stale chrome
    pills float over its top controls and it inherits the 76 dp bottom
    reservation with the omnibox bar visible under it. Full-bleed pushes
    must use **`Navigator.of(context, rootNavigator: true)`** to escape
    the shell (pop/`maybePop` from inside the pushed route still works —
    it resolves to the same root navigator). Fixed on: `photo_viewer`,
    `multi_shot_camera`, `drawing_pad` (`showDrawingPad`), the vehicle
    guided-capture push; `role_capture` + `game_fullscreen` were already
    correct. Rubric item A1a enforces this.
- **The bar lives INSIDE the body Stack** at `Positioned(bottom: 0)`,
  not in `Scaffold.bottomNavigationBar`. The bottomNavigationBar slot
  does NOT ride the keyboard inset; the body does. Routes whose forms
  push the keyboard up still have the bar appear above the keyboard
  because `resizeToAvoidBottomInset: true` shrinks the body to fit.
  Route content gets `Padding(bottom: 76)` so the last save-button
  never renders behind the bar.
- **Chrome (back + hamburger + actions) is rendered by AppShell from
  a STACK in `routeChromeProvider`** (see
  `lib/shared/widgets/route_chrome.dart`). Each `EdgeScaffold`
  pushes its entry on `initState` and pops on `dispose`; AppShell
  paints the top of the stack. Writes are deferred through
  `Future.microtask` to dodge Riverpod's "modified provider while
  the widget tree was building" assertion (initState fires inside
  the parent's build phase). The stack is what makes back-pop
  restore the previous route's chrome — without it, B's
  actions linger on A after a pop. New screens get this for free
  through `EdgeScaffold`; don't write to the provider directly.
- **Hamburger / drawer**: owned by AppShell, NOT per-route. The
  drawer renders on the Scaffold when a signed-in viewer is
  active; the hamburger pill is the GROUND — it shows in the
  top-left on every signed-in route (NOT just home). On drill-in
  pages, the back arrow renders to the right of the hamburger as
  a second pill. The intent is "user is never more than one tap
  from the top-level destinations regardless of how deep they
  drilled in." Swipe-from-left-edge still works as a redundant
  drawer gesture. Don't pass `drawer:` to EdgeScaffold — the param
  is accepted for source compatibility but ignored.
- **Three chameleon modes** (`OmniboxMode`):
  - `search` — fuzzy matches the catalog (default)
  - `capture` — free text that doesn't match anything in the catalog;
    Enter saves a Capture
  - `slash` — query starts with `/`; matches the slash command list
    in `lib/features/omnibox/slash_commands.dart`. Commands are
    `/today`, `/captures`, `/tasks`, `/insights`, `/review`,
    `/attendance {group}`, `/log {kid}`, `/schedule`.
- **Voice dictation** via Deepgram. `lib/features/voice/
  deepgram_voice_service.dart` opens a WebSocket to
  `wss://api.deepgram.com/v1/listen`, streams 16 kHz PCM from the
  `record` plugin, and emits interim + final transcripts. The
  omnibox mic button toggles a session; the running transcript is
  appended to the composer's existing text (so dictation
  complements typing rather than replacing it).
  - **Setup**: the Deepgram master key is NOT in `.env` — it's a
    server-side secret on the `voice-token` Supabase Edge Function
    (`supabase secrets set DEEPGRAM_API_KEY=…`), which mints a ≤30 s
    token the client uses to open the WS (the master key never ships in
    the app; see `docs/SECRETS.md` + `supabase/functions/voice-token/`).
    So STT needs **all three**: the function deployed, that secret set,
    AND the user signed in. Failure surfaces are explicit: not-signed-in
    → "Voice dictation requires sign-in."; mic denied → "Microphone
    permission was declined."; broker/Deepgram failure → an error state
    with the message. (Verified 2026-06-15: function ACTIVE + secret set,
    so a live failure is mic-permission or the Deepgram account, not
    config.)
  - **Permissions**: Android `RECORD_AUDIO` + iOS
    `NSMicrophoneUsageDescription` are wired. `permission_handler`
    requests at the moment of first use.
  - **Privacy**: audio is streamed, not stored. We don't write the
    PCM to disk and we don't proxy through our own backend.
- **Kid mode** (`kidModeProvider` in
  `lib/features/kid_mode/kid_mode_provider.dart`): when on, AppShell
  hides the omnibox bar + zeroes the bottom padding so the route
  fills the surface with no staff-facing affordance. Survey-take
  enters in `initState`, exits in `dispose`. Future kid-launchable
  surfaces (kid-journal) will need a staff-only exit gesture before
  they can ship.
  - **Screen-pinning is the OS layer kid-mode can't reach.** `kidMode` hides
    the app's own chrome, but it can't block the OS Home / recents buttons —
    a kid can still swipe out. `MainActivity.kt` adds a MethodChannel
    `com.jardine.differentworld/screen_pinning`
    (`startLockTask` / `stopLockTask` / `isLockTaskActive`);
    `lib/features/kid_mode/screen_pinning.dart` wraps it, platform-gated
    (Android only; iOS shows a Guided-Access reminder via
    `needsManualLockHint`). Engage it at the **session** level
    (`PhotoTurnsScreen`: pin on `initState`, unpin on `dispose`) so the OS
    "Pin this app?" confirm fires **ONCE per session, not per kid**. A
    non-device-owner app's `startLockTask` always triggers that OS confirm —
    expected; the channel answers `success(false)` on Security/IllegalState,
    never `result.error`. Native change → **full rebuild, not hot reload.**
- **DONE — `person-photos` bucket is private with signed URLs.** Migration
  `20260519000005_person_photos_private.sql` flipped the bucket private
  and added the space-gated read policy. Dart side: every photo render
  mints a 1-hour signed URL via `signedPersonPhotoUrlProvider`
  (lib/features/photos/person_photo_url.dart); new uploads store the
  bucket-relative path (not a full URL) in the row's `photo_url` /
  `avatar_url`. `PersonAvatar` is a `ConsumerWidget` now; gallery /
  viewer sites use `PersonPhotoNetwork`. Legacy rows that still hold a
  full https URL keep working — `extractPersonPhotoPath` strips the
  prefix and re-signs.

### Persona-driven UI work intentionally deferred

These came out of the 10-persona audit. Smaller persona fixes (Marcus
summary sentence, Brianna lock chip, Coach Sam pre-block brief) have
shipped; what's below needs its own focused PR.

- **Maya — tablet-first schedule grid. DONE.** The cohorts × time matrix
  on iPad/desktop is built — `ScheduleTimeGrid`
  (`lib/features/schedule/widgets/schedule_time_grid.dart`): cohorts as
  rows, a shared time axis, blocks span + position by start/end, with the
  live signals + tap-to-edit + drag-to-reschedule the agenda rows have.
  It is now the **default** wide-screen (≥ 720dp) view —
  `scheduleTimeGridProvider` defaults ON; a director who prefers cohort
  columns opts out in Settings → Preferences. Phones keep the per-cohort
  tabs.
- **Jordan — PARTIAL: voice-to-text on observation + omnibox.**
  Deepgram-powered mic is wired in the omnibox composer bar
  (`bottom_omnibox_bar.dart`) AND the observation form body field
  (`observation_form_screen.dart`, suffix-icon). The observation form
  uses its own local `DeepgramVoiceController` instance (not the
  shared singleton) so AppShell + form can't double-listen. STILL
  TO DO: mic on the standalone capture screen (`capture_screen.dart`)
  and any future free-text fields that would benefit from dictation.
- **Jordan — DONE: high-contrast outdoor mode.** Settings →
  Preferences → "Outdoor mode" (System default / High contrast).
  `outdoorModeSettingProvider` (`outdoor_mode_setting.dart`)
  persists the pick; `app.dart` applies the theme override on top of
  the OS dark/light theme. The 200% audit for layout / truncation
  reflow per screen is still a manual pass to schedule (shared with
  Helen).
- **Lauren — Spanish localization.** ARB infrastructure isn't wired
  yet. Set up `flutter gen-l10n`, extract every user-facing string,
  write the Spanish translations + the language picker in Settings.
  Big lift; non-trivial PR.
- **Lauren — "photo of the moment" on Family Today.** Surface the
  most recent observation photo above the kid's card when there's
  unseen content from today. Needs an `attachments` provider keyed
  on (subject, last-N-hours).
- **Helen — DONE: per-account text-size override, staff + family.**
  Settings → Preferences → "Text size" (System default / Large /
  Extra large, 1.0x / 1.3x / 1.5x floor). `textScaleSettingProvider`
  stores the pick in SharedPreferences; `AppTextScaleApplier` wraps
  `MaterialApp.router`'s builder and clamps the active `TextScaler`
  to AT LEAST the chosen floor so users who already crank their OS
  setting up don't get downscaled. **Wave 38** lifted the picker out
  of the private `_TextSizeTile` into a public widget at
  `lib/features/settings/widgets/text_size_tile.dart` (exports
  `TextSizeTile` + `showTextSizePicker(context, ref)`); the Family
  Today header now carries a Display action that opens the same
  sheet, so guardian-side Helen accounts can set their floor
  without ever reaching the staff `/settings` screen. The 200%
  audit (truncation / reflow per screen) is still a manual pass
  to schedule.
- **Devon — co-parent read state on messages + reports.** Schema:
  add `read_by_member_ids jsonb[]` to messages, denote which
  guardian has seen a row. UI: small "seen by both / seen by you"
  badge.
- **Pat — substitute handoff.** Director-side "make X the lead for
  {Cohort} today" action that flips the LeadingTodayCard contents to
  the absent counselor's blocks + cabin notes. Needs a `substitutes`
  table or a `daily_assignments` row carrying the override.
- **Ava — PARTIAL: kid-mode mechanism + staff exit shipped.**
  `kidModeProvider` (Notifier<bool>) + AppShell honors it (omnibox
  bar + drawer + body padding strip when on). `survey_take_screen.dart`
  auto-enters in `initState`, exits in `dispose`, AND wires a
  5-tap-on-the-top-right-corner gesture that opens
  `showKidModeExitDialog` (numeric PIN against `SpaceCaps.staffPin`
  if set; the 5-tap alone unlocks when no PIN is configured). STILL
  TO DO: the kid-journal feature itself, route-pop hardening so a
  kid tapping system-back can't break out of the locked screen, and
  a wider audit of which kid-mode surfaces exist beyond
  survey-take.
- **Ava — Action Words of the Day (vision, undesigned).** A
  kid-mode surface where each kid picks (or is assigned) 3 verbs
  for the day — e.g. "explore", "share", "create" — with kid-
  friendly descriptions and voiceover for the pre-readers in the
  4-6 cohort. Surface their picks back to staff (today's cohort
  words) and to family (parent gets "today {Name} chose: …").
  Open design questions before coding: who picks (kid alone vs
  staff-curated menu vs assigned), when (morning intention / end-
  of-day reflection / ongoing tap-when-done), who sees (kid /
  staff / family / all), catalog source (program-fixed / per-
  cohort / director-authored), voiceover (TTS via `flutter_tts`
  vs pre-recorded narrator vs staff voice). Structural sketch:
  new `action_words` catalog table + `entries.kind = 'action_words'`
  per kid per day storing the picks + kid-mode card layout with
  generous tap targets. Picking should feel like play, not a quiz.
- **All — empty-state illustrations + wordmark-as-system.** Single
  illustrator pass: 4-5 SVGs for the most common empty states
  ("nothing in your inbox", "all done for today") + gradient
  squircle used consistently across login, onboarding, exports.
- **Showcase / growth arc (vision, undesigned).** Every artifact a
  kid makes (drawing photo, voice note, action-words pick,
  observation moment, survey answer) feeds a compilation that
  tells a growth story over time. Daily highlight → weekly wrap →
  term portfolio → year-end keepsake. The "drawing becomes a film"
  framing — metaphorical (compilation + voiceover + music), not
  literal (animating the drawing itself; that's months of ML).
  Most of the source data already exists: `attachments`
  (photos/audio), `entries` (observations + payload), 
  `survey_responses`, `schedule_blocks` (activity context).
  What's missing: a curation surface, a render pipeline, and a
  delivery channel. Structural sketch: a new `showcases` table
  (same shape as `exports` — author/subject/format/storage_path/
  status — but format='mp4' or 'web' instead of 'pdf') + a
  `showcase_items` join table (showcase_id, attachment_id OR
  entry_id, position, caption). Render via a backend job, NOT in
  the device — encoding is heavy. Open questions before coding:
  cadence (daily/weekly/term/year — pick 1 to start), curation
  (auto-pick from signals, staff-curated, kid-curated, hybrid),
  output format (mp4 file / in-app slideshow / web page with
  embedded media).

---

## Where to look

- Schema source of truth: [supabase/migrations/](supabase/migrations/)
- Sync rules: [supabase/sync_rules.yaml](supabase/sync_rules.yaml)
- Schema mirror in Dart: [lib/core/db/power_sync_schema.dart](lib/core/db/power_sync_schema.dart)
- Drift database + tables: [lib/core/db/app_database.dart](lib/core/db/app_database.dart)
- Auth providers: [lib/core/auth/auth_providers.dart](lib/core/auth/auth_providers.dart)
- Sync wiring: [lib/core/sync/](lib/core/sync/)
- Per-feature folders: [lib/features/](lib/features/)
