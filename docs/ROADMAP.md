# Different World — roadmap

The living list of "what's still on the table" plus the prioritized
order to ship things in. Updated as work lands and new work surfaces.
Companion to `docs/SCREEN_QA_MATRIX.md` (per-screen state contract)
and `docs/APP_GUIDE.md` (what the app IS).

**How to read this doc**: scan the "Recommended order" at the
bottom first. The category tables are the inventory; the
recommendation is what to actually do next.

---

## Vertical-readiness — finish what we started

The `VerticalLabels` infrastructure (Wave 1 of the council batch),
the `CoreCaps` / `ChildcareCaps` split (Wave 2), and the migrated
section headers / stats (Waves 5-6) are in. What's left:

| Item | Effort | Why |
|---|---|---|
| Migrate remaining ~30 hardcoded labels in lower-traffic screens (form labels, empty-state copy) | M | Mechanical per-screen, do in batches as touched. Major roster surfaces (group detail / group edit / subject edit / attendance / member detail / settings / drawer) shipped in Waves 14-15. |
| Per-vertical `ConstructionCaps`/`HealthcareCaps`/etc. classes | M | Needs concrete pilot to justify writing the verbs |
| `staff_role` Postgres enum overhaul (or drop to text + per-space role catalog) | M | Required for non-childcare role names; schema migration |
| Schema audit doc — catalog childcare-specific columns (`tracks_diapers`, `pickup_strict`, `student_guardians`, `age_band`) | S | Captures what's left for the actual multi-vertical migration design |

## Pre-ship infrastructure

The "before external rollout" checklist. Each is a defined unit of
work that doesn't need a feature decision.

| Item | Effort | Why |
|---|---|---|
| **Sentry / crash reporting wiring** | S | Env slot exists; just init + ErrorBoundary. ~30 min. |
| **Edge Function broker for vendor keys** (Deepgram + OpenAI) | M | Keys currently ship in the APK; before external rollout |
| Background photo upload queue (`pending:<local-path>` → resolved on connectivity) | M | Real offline-capture reliability |
| Native `google_sign_in` (vs external-browser OAuth) | S | Smoother mobile OAuth |
| Push notifications (late pickup alerts) | M | Needs FCM/APNs setup |
| App icons + splash + store listings | M | Needs design assets |
| Release signing configs (Android keystore, iOS certs) | S | User-driven |
| Custom Supabase domain | S | Cosmetic |

## Persona work

| Persona | Item | Effort |
|---|---|---|
| **Ava** | Staff PIN exit dialog (replaces/supplements the 5-tap gesture) | S |
| **Lauren** | "Photo of the moment" on Family Today | S |
| **Jordan** | Outdoor mode toggle (high-contrast, bigger glyphs) | S |
| **Lauren** | Spanish localization (`flutter gen-l10n` + ARB extraction) | L |
| **All** | Empty-state illustrations + wordmark system | L (needs illustrator) |

## QA / robustness

| Item | Effort | Why |
|---|---|---|
| **Goldens for top 8 screens** — Today, Insights, Captures, Tasks, Schedule, GroupDetail, SubjectDetail, ObservationsList | M | Visual regression net |
| **Screen walker integration test** (scaffolded; per-route assertions TODO) | M | Catches lifecycle / chrome / omnibox bugs goldens miss |
| DAO consolidation (5 small DAOs → MetaDao) | M | Council consolidation #5; needs `build_runner` cycle |
| Chrome-stack skill family merge (4 skills → 1) | S | Same pattern as offline-first wave |
| Doc overlap reduction (CLAUDE.md ↔ APP_GUIDE.md ↔ skills) | M | Maintainability |

## Real product features not yet built

| Item | Effort | Why |
|---|---|---|
| Field trip flow polish (permission slips + headcounts) | M | Schema shipped; UX end-to-end test needed |
| Schedule time-grid drag-to-move / drag-edge resize | M | The manipulation half of Maya's planner — the read-rich time grid shipped (b05b7c8); editing is still tap→block sheet. Optimistic write via `scheduleActionsProvider.update_`. |
| BentoGrid true 2-D masonry (vs the current 1-D Wrap) | M | Spans are tuned so each breakpoint packs clean; masonry only matters if odd widths go ragged. Defer until it bites. |
| Multi-program switcher in drawer | M (mis-classified as S earlier) | Single-program design today; needs schema migration to support a user belonging to multiple spaces (today `members.id = auth.uid()`, so one user = one member = one space). New table `user_spaces (user_id, space_id, role, caps)` would unblock it. Defer until a real multi-program use case lands. |
| Family-side UI polish (`FamilyTodayScreen` outlined but partial) | M | Family-login model is in; UI bare |
| Reports / exports depth (richer PDF templates) | M | Basic works |
| Menu planning (Kitchen *authors* menus, not just meal logging) | M | Meal-log entries exist (`EntryKind.meal`); the authoring/publish side doesn't. New `feature_*` Space cap + Kitchen CRUD. RBAC-matrix row "Meals/Menus". |
| Billing module | L | `feature_billing` flag reserved; build behind `can_view_billing`. Needs a payments-integration design first. |
| Games & live-sessions engine | L | The only RBAC-matrix row needing a *runtime* role layer (host / participant / observer) on top of CRUD. Surveys cover the live-session-lite case today. |
| General consent-forms module | M | Photo + field-trip consent exist as flags; this generalizes to signable forms with a pending→signed state. |
| Authenticated child account | decision | RECOMMENDATION: stay with kid-mode (device lock), not child logins — large privacy surface for little gain. Logged as a decision, not a build. |

> The RBAC **enforcement** gaps (row-level `°` scoping, soft-delete,
> capability-editing UI, specialist time-boxing, capture moderation,
> audited reads) are cross-cutting, not net-new features — they live in
> [SCALE_PUNCH_LIST.md](SCALE_PUNCH_LIST.md) under "Row-level `°`
> scoping". The capability framework stays; we're closing enforcement.

## Recommended order

What to actually ship next, in order. Each row is a focused commit
or short batch; don't lump them.

1. **Sentry wiring** (S, ~30 min) — pre-ship infrastructure with a known slot; we've been catching bugs by reading logcat. Sentry auto-collects.
2. **Goldens for the top 8 screens** (M, ~2 h) — Today, Insights, Captures, Tasks, Schedule, GroupDetail, SubjectDetail, ObservationsList. Locks the chrome + omnibox surface against regression.
3. **Ava staff PIN dialog** (S, ~45 min) — replaces the 5-tap-corner with a typed PIN check. Closes the partial persona item.
4. **Background photo upload queue** (M, ~90 min) — `pending:<local-path>` flow resolves when online. Highest user-visible benefit of the deferred infrastructure list.
5. **Schema audit doc for vertical-readiness** (S, ~30 min markdown) — catalog the SQL-level childcare assumptions for the actual multi-vertical migration design.

After that, the next 5 most likely:

6. **Chrome-stack skill family merge** (S)
7. **Lauren "photo of the moment"** (S)
8. **Jordan outdoor-mode toggle** (S)
9. **Multi-program switcher in drawer** (S)
10. **Edge Function broker for vendor keys** (M) — only when external rollout is actually committed to

---

## Maintenance

When you finish an item, MOVE it to the bottom of this doc under a
"Shipped" section with the commit hash. Don't just delete the row —
seeing what's been done is the antidote to "is X built yet?"
questions in future sessions.

When new work surfaces (Council audit, user request, bug), add it
to the relevant table here BEFORE working on it. The roadmap is
the inheritance file for future Claude sessions.

## Shipped

(Move done items here with their commit hash. Most-recent first.)

- **566109f / b05b7c8** — Grid-based navigation (user-driven, awwwards
  brief). New reusable `BentoGrid` primitive (docs/GRID.md): one modular
  2 / 4 / 6-column grid that re-packs across phone / tablet / desktop. Two
  toggleable consumers, each a default-off SharedPreferences switch with a
  settings tile: the **bento dashboard home** (`bentoHomeProvider`, 566109f)
  — Today's providers re-laid-out as modular tiles — and the **time-aligned
  schedule grid** (`scheduleTimeGridProvider`, b05b7c8) — cohorts × time on a
  shared axis. The schedule grid CLOSES the Maya "tablet schedule grid
  (cohorts × time matrix)" persona item (was effort L). Grid spec in
  docs/GRID.md (35eca4d); seeded golden plates for both (a6ace28); BentoGrid
  in the component bible (94981b0). Drag-to-move / resize on the schedule
  grid deferred (see "Real product features").
- **038dbf6** — Curated game content bank ~4×. Riddles 16→79, fact-or-fib
  16→80, charades 24→91, rhyme 16→56, as-if 12→51, line 10→35, story-twist
  8→48; This-or-That generator pools 6→16 themes. Generated + adversarially
  fact-checked + deduped by an 18-agent workflow.
- **938bf14** — Roster screens routed through `VerticalLabels`.
  Group detail (empty state, primary action tooltip, content header
  title, attendance secondary), group edit (header title, name
  field label, form chrome), subject edit (header title + subtitle),
  attendance screen (empty roster state) all now consume
  `verticalLabelsProvider` and render `labels.group` /
  `labels.subject` / `labels.subjectPlural` / `labels.space` /
  `labels.attendanceNoun` instead of hardcoded "Classroom" /
  "Student" / "Students" / "Program" / "attendance". A
  hospitality-vertical space sees "Add a Guest" / "No Sections yet";
  construction sees "Add a Project" / "New Crew"; etc. Lower-
  traffic screens (omnibox catalog tooltips, exports templates,
  insights copy) still hardcoded — left for a future incremental
  pass per the SCHEMA_AUDIT-style approach of "route as touched."
- **b77a48b** — Vertical-aware capability editor. The Member detail
  Permissions tab now splits "Core abilities" (CoreCaps — vertical-
  agnostic verbs every vertical uses: Observe, Take attendance,
  Drive, Open/Close building, Manage schedule, Invite staff, View
  billing, Act as director) from "Childcare verbs" (gated by
  `verticalLabelsProvider.vertical == 'childcare'`). When a
  director flips the space to construction / healthcare / etc.,
  the childcare block hides automatically and only the agnostic
  switches remain — no nonsense "Record diaper changes" toggle on
  a construction crew member.
  `_RoleSelector` reads role keys from `RoleBundles.rolesFor
  (vertical)` instead of hardcoding childcare's four roles, so a
  construction-vertical space shows pm/foreman/journeyman/
  apprentice/subcontractor chips; healthcare shows
  physician/np/rn/tech/admin; etc.
  `RoleLabels.of(roleKey, {vertical: 'childcare'})` is the new
  per-vertical label lookup. Threaded through four prominent
  surfaces (member_detail header + role picker, settings_screen
  current-user tile, main_drawer current-user role, team_screen
  member tiles). Other callers (omnibox_catalog, invite_share_sheet,
  viewer.roleLabel getter) keep the childcare default — they
  haven't been threaded yet but degrade gracefully.
- **5dc98c4** — Per-vertical RoleBundles. `RoleBundles.defaultsFor`
  now takes a `vertical:` named param and looks up the bundle from
  per-vertical maps (`_childcare`, `_construction`, `_healthcare`,
  `_hospitality`, `_manufacturing`). Each vertical's bundles use
  `CoreCaps` (vertical-agnostic verbs) — only childcare uses
  `ChildcareCaps` keys today. Default is `'childcare'` so
  unupdated call sites still work. New `RoleBundles.rolesFor
  (vertical)` returns the role-key list per vertical, ready for a
  vertical-scoped role picker. `settings_actions.setRole` reads
  the active vertical from `verticalLabelsProvider` and threads it
  through. Construction's `pm/foreman/journeyman/apprentice/
  subcontractor`, healthcare's `physician/np/rn/tech/admin`,
  hospitality's `gm/manager/server/cook/host`, manufacturing's
  `production_manager/line_lead/operator/qa/maintenance` all have
  hand-written cap defaults. ZERO schema (no `role_catalog` table)
  — the SCHEMA_AUDIT doc suggested one, but the agnostic engine
  principle says "don't add tables for what code constants
  express." Per-Member overrides on `members.capabilities` stay the
  escape hatch for customer customization.
- **63fc829** — Subject health profile (childcare). Structured
  fields for medications, medical conditions, IEP/504 summary,
  primary physician (name + phone), and emergency instructions —
  stored agnostically. ZERO schema migration: all new keys ride
  the existing `subjects.capabilities` JSONB under a
  `ChildcareSubjectCaps` namespace. New `SubjectCapActions
  .setStringCap(subjectId, key, value)` is the read-merge-write
  setter (mirrors `SpaceCapActions.setStringCap`); empty / null
  values clear the key so the JSONB bag stays tidy. UI: new
  `HealthProfileCard` on subject detail (gated by
  `verticalLabelsProvider.vertical == 'childcare'`) renders a
  warm-tinted allergies + emergency row plus list-flavored
  medications & conditions; tapping opens `HealthProfileSheet`
  with all fields in one form. Lists use comma-separated text
  input + JSON-encoded `List<String>` storage. Other verticals
  add their own intake namespace + card without touching this
  one. Demonstrates the "agnostic storage, vertical-shaped JSON
  payload" pattern the SCHEMA_AUDIT doc recommended.
- **29b870e** — Vertical picker on program settings. New `vertical`
  string capability on `SpaceCaps` (no schema migration — rides
  the existing `spaces.capabilities` jsonb). `verticalLabelsProvider`
  now reads `currentSpaceProvider.value.caps.getString('vertical')`
  and routes through `_VerticalLabelPresets.forKey`, with childcare
  as the fallback. New `_VerticalPickerTile` + `_VerticalPickerSheet`
  on Program settings render the 5 presets (Childcare / Construction
  / Healthcare / Hospitality / Manufacturing) with a preview line
  showing the Space / Group / Subject / Entry mapping for each.
  Director taps a row → auto-save → every consuming widget re-labels
  on the next rebuild. `SpaceCapActions.setStringCap` is the new
  read-merge-write generic setter for non-boolean cap keys
  (childcare maps to `null` so a fresh space without the cap stays
  on the implicit default). Closes the vertical-readiness blocker
  noted in Council audit.
- **e837441** — Pat substitute handoff. New nullable
  `lead_substitute_member_id` column on `public.schedule_blocks`
  (migration `20260520000002_lead_substitutes.sql`); Drift +
  PowerSync schema mirror; `ScheduleDao.watchDayForLead` now
  matches `COALESCE(substitute, lead) = me` so an absent person's
  blocks vanish from their own LeadingTodayCard and surface in the
  cover's instead. New `ScheduleDao.assignDailySubstitute` does a
  bulk update across one cohort's blocks for a single date. New
  `SubstituteLeadSheet` (`lib/features/schedule/widgets/`) lists
  each planned lead with a block count + Cover/Restore action;
  picker shows every other member in the space with their role
  label. `_CoverLeadStrip` on today's per-cohort tab is the entry
  point; appears only when today and at least one block has a
  planned lead. `_CoveringBadge` on `LeadingTodayCard` rows labels
  blocks the viewer is on only because they're covering for
  someone, with the original lead's name.
- **49d4e18** — Devon co-parent read-state badges. New
  `read_by_guardian_ids jsonb` column on `public.messages`
  (migration `20260520000001_message_read_by.sql`); Drift mirror +
  PowerSync schema bumped; `MessagesDao.markThreadReadByGuardian`
  appends the viewing guardian's id idempotently; `MessageActions
  .markThreadRead` calls it on guardian-side opens; new
  `_ReadReceipt` widget on staff-side bubbles renders "Seen by
  Mom" / "Seen by Mom & Dad" / "Seen by 2 of 3" / "Seen by all"
  using the per-guardian list when the thread has multiple
  guardians, falling back to legacy `read_at` semantics on
  single-guardian threads + guardian-side bubbles.
- **7170cc0** — Lauren "photo of the moment" on Family Today.
  New `_PhotoOfTheMomentPeek` widget in the child card surfaces
  today's most recent observation photo at 16:9 with caption + +N
  badge. Renders nothing when there's nothing to show.
- **37f664a** — Auto-retry photo queue on connectivity. Added
  `connectivity_plus: ^7.0.0`; `PhotoUploadQueue.startConnectivityListener()`
  drains the queue on any transition to wifi / cellular / ethernet
  / vpn. Cancels on provider dispose.
- **019ff05** — Jordan outdoor mode. High-contrast theme variant
  (black background, safety-yellow primary) for bright-sun /
  outdoor use. New `outdoorModeProvider` + `outdoorTheme()` +
  Preferences tile.
- **afd7f51** — Schema audit doc (`docs/SCHEMA_AUDIT.md`).
  Catalogs the childcare-specific bits at the Postgres layer
  (member_role enum, guardians + subject_guardians tables, JSONB
  capability vocabulary) and writes the migration design for
  multi-vertical readiness. Recommendation: drop the enum to text +
  per-Space role catalog; add `vertical` column to `public.spaces`;
  gate childcare-specific feature folders. Roadmap item #5 closed.
- **76bbf5f** — Background photo upload queue. `PhotoUploadQueue`
  service: bytes-to-disk + SharedPreferences-backed pending list +
  `processQueue()` on app boot. Both `PhotoService.uploadAndPersist`
  and `uploadOnly` fall back to the queue on Storage failure.
  Entity row gets `pending:<id>` token; PowerSync syncs it so other
  devices show a placeholder; worker rewrites the row on success.
  Auto-retry-on-connectivity deferred. Roadmap item #4 closed.
- **7a4f052** — Ava staff PIN dialog. `SpaceCaps.staffPin` + new
  `kid_mode_exit_dialog.dart` + `survey_take_screen` uses it after
  the 5-tap-corner gesture. PIN-less spaces fall back to gesture-
  alone. Persona Ava promoted from PARTIAL to shipped. Roadmap
  item #3 closed.
- **bb951ec** — Goldens for Insights, Captures, Tasks (empty
  states, 4 breakpoints each). 16 golden tests now passing across
  4 screens. Top-8 batch first half. Roadmap item #2 half-done;
  remaining 5 (Today, Schedule, GroupDetail, SubjectDetail,
  ObservationsList) are larger provider-mock surface.
- **7d9f6d1** — Sentry wiring. `sentry_flutter: ^9.6.0` added,
  `main.dart` initializes when `Env.hasSentry` is true (else
  no-ops). `sendDefaultPii = false`, crash-only sampling,
  debug/release environment tags. Pre-existing
  `FlutterError.reportError` calls now route through Sentry
  automatically. Roadmap item #1 closed.
