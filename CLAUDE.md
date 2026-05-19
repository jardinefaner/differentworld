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

The only place that talks to Supabase directly is
[lib/core/sync/supabase_connector.dart](lib/core/sync/supabase_connector.dart),
which is PowerSync's upload callback. Auth is the other exception
(`supabase.auth.signInWithOAuth`) because PowerSync doesn't manage it.

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
`db.capturesDao.watchOpen(spaceId)`, `db.entriesDao.create(...)`. Only
cross-table transactions (e.g. `createSpaceForMember` which writes
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

### Privacy & security

Children's data is sensitive PII. Assume regulators (state licensing,
COPPA in the US) will eventually audit.

- **No PII in logs.** Don't `print` student names, photos, parent
  contact info, or observation narratives. The PowerSync upload error
  logs are an exception; redact in production builds.
- **Photos**: Supabase Storage with **signed URLs** (short-lived). Never
  use public buckets for student photos. Bucket name + RLS scoped to
  program membership.
- **Background screenshots** on iOS/Android — hide sensitive UI from
  the app switcher. Use `secure_app_switcher` or similar when we ship.
- **No analytics events** that include child identifiers. If we add
  product analytics, it's event-level, never row-level.
- **Auth tokens never logged.** Supabase access/refresh tokens stay in
  `flutter_secure_storage`-backed channels only.
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

### Guardians don't sync space-scoped tables via `by_space`
The `by_space` stream gates every query on
`space_id IN (SELECT space_id FROM members WHERE id = auth.user_id())`.
A guardian doesn't have a `members` row (they're in `guardians`), so
the membership subquery is empty and **no rows from `by_space` reach
their device via the live stream.** This is intentional: most of
`by_space` is staff-only data (attendance, observations, vehicle
logs).

The exception is anything a guardian explicitly needs to see:
`messages` already has a per-thread RLS branch on
`guardian_id IN (SELECT id FROM guardians WHERE user_id = auth.uid())`
so the family lens reads via direct PostgREST queries rather than
the PowerSync mirror. Same for `exports` + `export_recipients` —
RLS gates by recipient, but the PowerSync mirror never populates
locally on the guardian side.

**If you build a guardian-facing list of *anything*** (My reports,
My captures, etc.), wire it to a dedicated stream or fall back to
direct Supabase reads — don't expect the local Drift mirror to
have the data.

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

## Tooling permissions granted

- `Bash(supabase db push:*)` — run migrations directly after writing
  them. The CLI's own y/N prompt is the user's checkpoint.

## Default run target — the Pixel 6 (wireless)

When testing changes, run on the user's Pixel 6 over wireless ADB:

```sh
flutter run -d adb-1A291FDF6002RQ-JYcM2v._adb-tls-connect._tcp
```

Background it via `tee /tmp/dw-pixel.log` so you can tail logs later.
Don't switch to Chrome / macOS as the default — phone is the primary
testing surface (the app is phone-first). Web is a secondary
verification, not the default. If the Pixel is disconnected, tell the
user; don't silently fall back to a different device.

---

## Commands

```sh
flutter analyze                    # must be clean before declaring done
flutter test                       # widget + unit
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

## "Done" means

For substantive changes:
- `flutter analyze` — "No issues found"
- `flutter test` — all passing
- UI changes: exercised in a browser, or stated as not yet exercised
- Sync / lifecycle changes: Flutter Preflight (stop-hook reminds once per
  session)
- Shipping: also Flutter QA Gate, or use `/ship`

For exploratory / scoping conversations: no gate, just answer.

---

## What's intentionally deferred

- **Native `google_sign_in`** for smoother mobile UX (current flow opens
  external browser — works, slightly clunky on iOS/Android)
- **Sentry / crash reporting** — env slot ready, wire near ship
- **Push notifications** (late pickup alerts, etc.) — separate concern
- **App icons + splash + store listings**
- **Release signing configs** (Android keystore, iOS certs)
- **Custom Supabase domain** (cosmetic — removes `*.supabase.co` from
  OAuth URL)
- **Background photo upload + thumbnail generation** — when we wire
  observations
- **Flip `person-photos` Storage bucket private + signed URLs** — currently
  public-with-obscurity (UUID paths inside `<space_id>/` prefix). CLAUDE.md
  binary-media contract requires private bucket + signed URLs for
  student photos. Migrations
  `20260518000003_person_photos_bucket.sql` /
  `20260518000004_person_photos_space_gate.sql` ship the v0.1
  compromise; flip before any external rollout.

---

## Where to look

- Schema source of truth: [supabase/migrations/](supabase/migrations/)
- Sync rules: [supabase/sync_rules.yaml](supabase/sync_rules.yaml)
- Schema mirror in Dart: [lib/core/db/power_sync_schema.dart](lib/core/db/power_sync_schema.dart)
- Drift database + tables: [lib/core/db/app_database.dart](lib/core/db/app_database.dart)
- Auth providers: [lib/core/auth/auth_providers.dart](lib/core/auth/auth_providers.dart)
- Sync wiring: [lib/core/sync/](lib/core/sync/)
- Per-feature folders: [lib/features/](lib/features/)
