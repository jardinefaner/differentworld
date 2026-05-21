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
| Add `vertical text` column to `public.spaces` + read it in `verticalLabelsProvider` | M | Today the provider returns childcare default unconditionally; this completes the story so a multi-vertical install actually swaps labels |
| Per-vertical `RoleBundles.defaultsFor(vertical, role)` | M | Construction's `foreman/PM/apprentice` needs different cap seeds |
| Migrate remaining ~50 hardcoded labels in lower-traffic screens (form labels, empty-state copy) | L | Mechanical per-screen, do in batches as touched |
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
| **Maya** | Tablet schedule grid (cohorts × time matrix) | L |
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
| Capability editor UI (per-Member overrides) | M | Schema exists; UI partial |
| Subject medical fields form (allergies, meds, IEP) | M | Schema exists; form may be incomplete |
| Field trip flow polish (permission slips + headcounts) | M | Schema shipped; UX end-to-end test needed |
| Multi-program switcher in drawer | M (mis-classified as S earlier) | Single-program design today; needs schema migration to support a user belonging to multiple spaces (today `members.id = auth.uid()`, so one user = one member = one space). New table `user_spaces (user_id, space_id, role, caps)` would unblock it. Defer until a real multi-program use case lands. |
| Family-side UI polish (`FamilyTodayScreen` outlined but partial) | M | Family-login model is in; UI bare |
| Reports / exports depth (richer PDF templates) | M | Basic works |

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

- **Wave 10** — Pat substitute handoff. New nullable
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
