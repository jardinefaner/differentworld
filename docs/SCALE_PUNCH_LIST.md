# Scale punch list

What we'd do *before* this app went from one program to many, with
honest effort estimates and the prerequisite each item needs to be
safe to land. The items below were named during the scaling audit
(2026-05-18) and triaged into "ship now" / "verify-then-ship" / "real
engineering session."

This doc is the audit trail. When you actually do one of these
items, move it into the changelog at the bottom and drop the entry.

---

## Done

- **Insights — dismiss / snooze.** Per-member snooze (until tomorrow,
  until next week, until manually unhidden). Insight rows are
  on-device only; `dismissed_insights` table holds the snooze state.
  Snoozed-out insights re-surface automatically when `dismissed_until`
  passes. Migration `20260518000013`, providers in
  `lib/features/insights/insights_providers.dart`. Shipped
  2026-05-18.

---

## Verify-then-ship — needs a non-prod environment

### RLS re-tighten (security)

**Why.** CLAUDE.md notes that INSERT/UPDATE/DELETE policies are gated
on `current_user = 'authenticated'` (the DB role) rather than
`auth.uid() IS NOT NULL` (the per-user check), because on this
ES256-keyed Supabase project `auth.uid()` was returning null in RLS
evaluation. That's fine for single-program dev but is real exposure
once multiple programs share the project — any authenticated row id
could be written by any authenticated user.

**What's blocking.** Can't safely flip the policies without verifying
`auth.uid()` actually populates on the live JWT. Flipping blindly
breaks every write if it's still null.

**Verification plan (in a staging Supabase project, or a fresh dev
project).**
1. Run, in the Dashboard SQL editor, a one-row write as the
   `authenticated` role with a real session header. Easiest path:
   open the app on a device, take an action, then look at the
   Supabase request logs for the `Authorization: Bearer …` header.
2. From a psql session with that JWT as the `request.jwt.claims`
   GUC, evaluate `SELECT auth.uid()`. Should return the user's id.
3. If it does: write a migration that drops the relaxed policies and
   adds the right ones (per-table, gating writes on `auth.uid() IS
   NOT NULL` AND a space-membership check). Test every CRUD path on
   staging. Then push to prod.
4. If it still returns null: file a Supabase support ticket. The
   diagnostics in CLAUDE.md ("Side-effect on RLS tightening")
   capture the symptoms.

**Effort.** 2-4 hours including staging verify. Migration itself is
~50 lines per affected table.

---

### Row-level `°` scoping — staff see only assigned kids

**Why.** The capability model already *intends* per-assignment scoping
(`MemberViewer.seesAllClassrooms => isDirector`,
[viewer.dart](../lib/core/viewer/viewer.dart)), and the data model
supports it: `group_members` (staff↔room) + `subjects.group_id`
(enrollment). But today non-director staff effectively see the whole
program — reads gate on `space_id`, not assignment, and the relaxed
write-RLS ("RLS re-tighten" above) means writes aren't per-user either.
This is the `°` column in the RBAC permission matrix and the single
most security-sensitive gap before a real multi-staff rollout. **Stays
on the capability framework — this is enforcement, not a new model.**

**Three layers, sequenced by what's blocked:**

1. **Provider/UI scoping (UNBLOCKED — ship now, P0.1).** Add
   `MemberViewer.assignedGroupIds` + `MemberViewer.canSeeSubject(id)`
   (mirror the GuardianViewer method) driven by `group_members`; filter
   the subject / roster / entry read providers for non-directors. This
   is the "UI hides, backend re-checks" first half — defense, not yet a
   boundary. **Watch-out:** it HIDES kids if `group_members` isn't
   populated, so default non-directors to all-visible when they have
   zero assignments (and ship a staff→room assignment UI before
   flipping that default). Effort: M.
2. **RLS enforcement (BLOCKED on "RLS re-tighten" above, P0.2).** Once
   `auth.uid()` populates, tighten read policies to the
   `subject → group → group_members` subquery so scoping is a real
   boundary. Same 2-level-subquery concern as the family lens for the
   PowerSync sync rule — verify the subset accepts it, else denorm
   `assigned_member_ids` onto `subjects` via trigger. Effort: M/table.
3. **Soft-delete + director-only delete (P0.3).** Extend the existing
   `archived_at` pattern (activities, exports) to attendance / entries
   / incidents so history survives; gate hard-delete behind
   `isDirector`. Effort: S/M.

**Related P1 — capability-surface completeness (model exists, UI/enforcement partial):**
- **Capability-editing UI** — the "Abilities" checklist on member
  invite/edit (model in [CAPABILITIES.md](CAPABILITIES.md); per-key
  toggle UI is the deferred piece). Reuse `CapSwitch`. Effort: M.
- **Specialist time-boxing** — session-date window on specialist caps;
  `canSeeSubject` returns false outside it. Effort: S/M.
- **Capture moderation** — formalize the `pending → approved` status
  captures already carry + an `approve°` action gated by a cap. M.
- **Audited medical/contact reads** — `can_view_audit_log` cap exists;
  add an `audit_log` table + read hooks on health / contact surfaces. M.

---

### Time-windowed sync via client parameters

**Why.** `attendance_records`, `entries`, and `vehicle_logs` grow
linearly. At 50 kids × 5 obs/week × 40 weeks = 10k observations per
year per program. Cold launch downloads everything in `by_space`.
Fine today; not fine at year 3. **The 2026-06 features made `entries`
the dominant grower:** the daily parent recap writes ONE row per child
per send (≈ N_kids/day), and `daily_response` + `mood` are similar
per-child-per-day kinds — so a 100-child program now generates 100k+
`entries` rows/year, all in `by_space`. This is the single
highest-leverage scale lever, and it's blocked only on the
dashboard-side `by_space_recent` stream + the SDK `parameters:` arg
below.

**Status (May 2026).** Client side built; dashboard YAML pending.

**Client side (DONE).** `lib/core/sync/sync_window.dart` computes
`cutoff_at` (ISO timestamp) and `cutoff_date` (YYYY-MM-DD).
`powerSyncLifecycleProvider` calls
`db.syncStream('by_space_recent').subscribe(parameters: …)` on every
auth state change and reschedules at the next local midnight so the
window slides. The call is wrapped in a forward-compat try/catch —
if the stream isn't deployed (today), PowerSync logs a warning and
the rest of the auto-subscribed `by_space` keeps working unchanged.

**Dashboard YAML to paste once staging exists.** Adds a manual stream
for the three growing tables; the existing `by_space` stops carrying
them.

```yaml
streams:
  current_member:
    auto_subscribe: true
    query: SELECT * FROM members WHERE id = auth.user_id()

  by_space:
    auto_subscribe: true
    queries:
      # Permanent / small tables stay fully synced.
      - SELECT * FROM spaces             WHERE id        IN (SELECT space_id FROM members WHERE id = auth.user_id())
      - SELECT * FROM members            WHERE space_id  IN (SELECT space_id FROM members WHERE id = auth.user_id())
      - SELECT * FROM groups             WHERE space_id  IN (SELECT space_id FROM members WHERE id = auth.user_id())
      - SELECT * FROM enrollments        WHERE space_id  IN (SELECT space_id FROM members WHERE id = auth.user_id())
      - SELECT * FROM subjects           WHERE space_id  IN (SELECT space_id FROM members WHERE id = auth.user_id())
      - SELECT * FROM guardians          WHERE space_id  IN (SELECT space_id FROM members WHERE id = auth.user_id())
      - SELECT * FROM subject_guardians  WHERE space_id  IN (SELECT space_id FROM members WHERE id = auth.user_id())
      - SELECT * FROM group_members      WHERE space_id  IN (SELECT space_id FROM members WHERE id = auth.user_id())
      - SELECT * FROM vehicles           WHERE space_id  IN (SELECT space_id FROM members WHERE id = auth.user_id())
      - SELECT * FROM member_certifications WHERE space_id IN (SELECT space_id FROM members WHERE id = auth.user_id())
      - SELECT * FROM attachments        WHERE space_id  IN (SELECT space_id FROM members WHERE id = auth.user_id())
      - SELECT * FROM survey_responses   WHERE space_id  IN (SELECT space_id FROM members WHERE id = auth.user_id())
      - SELECT * FROM dismissed_insights WHERE space_id  IN (SELECT space_id FROM members WHERE id = auth.user_id())
      - SELECT * FROM captures           WHERE space_id  IN (SELECT space_id FROM members WHERE id = auth.user_id())
      - SELECT * FROM invites            WHERE space_id  IN (SELECT space_id FROM members WHERE id = auth.user_id()) AND accepted_at IS NULL

  by_space_recent:
    auto_subscribe: false
    queries:
      - SELECT * FROM entries            WHERE space_id IN (SELECT space_id FROM members WHERE id = auth.user_id()) AND recorded_at >= request.parameters.cutoff_at
      - SELECT * FROM attendance_records WHERE space_id IN (SELECT space_id FROM members WHERE id = auth.user_id()) AND date         >= request.parameters.cutoff_date
      - SELECT * FROM vehicle_logs       WHERE space_id IN (SELECT space_id FROM members WHERE id = auth.user_id()) AND created_at   >= request.parameters.cutoff_at
```

**Verification plan (staging).**
1. Paste the YAML, click Deploy. Confirm the dashboard accepts the
   `request.parameters.cutoff_at` syntax — PowerSync rejected
   `date()`/`now()` earlier; if it rejects this too, the path forward
   shifts to JWT claims (harder).
2. Open the app on a clean device. Confirm logs show
   `[sync] by_space_recent subscribe` succeeding (no
   "skipped" warning).
3. Confirm the local DB only has rows newer than `cutoff_at`
   (90 days back by default) — older rows dropped.
4. Time-jump the device clock past midnight, force a re-subscribe.
   Confirm the window slides — a row that was at day `T-90` is now
   at day `T-91` and should drop.

**Effort remaining.** Just the dashboard paste + verify. Client is
ready.

---

## Real engineering session

These are not 1-evening items. Each needs design + staging + ops.

### Background insights via Supabase Edge Function

Today Insights compute *when the user opens the app*. The framework's
"scheduled, low frequency" surfacing means a director who hasn't
opened in a week sees no alerts. Fix: a daily Edge Function that
computes insights server-side, writes them to a new
`insight_events` table (or pushes via FCM/APNs). On-device insights
stay; the server adds notification delivery.

**Prerequisites.** Edge Function deploy pipeline, FCM/APNs setup
(currently deferred per CLAUDE.md), a way to dedupe between
server-side and client-side derivations.

### Photo throughput — on-device thumbnail-first

Current path: pick → compress in isolate (~600ms) → upload full-res.
For a 30-shot burst the user waits ~3-5s. If burst capture becomes
common, switch to: thumbnail-only first (instant), then lazy
full-res upload in the background.

**Prerequisites.** Real workflow data showing burst >5 photos is
common. No measured pain yet.

### Insights memoization

`insightsProvider` recomputes on every Today rebuild. Cheap at our
row counts (a few hundred records to scan), but at ~10k entries +
30 vehicles + 100 certs the per-rebuild scan starts to matter.

**Prerequisites.** Profiler showing this on the critical path.

### 2026-06-19 audit — code-side scale follow-ups

From the scaling audit after the 2026-06 feature wave (recap / per-child
world / role deck / story showcase), run through the sync + performance +
hotspot guards. Pure-code, no dashboard:

- **Local SQLite indexes — DONE.** The single biggest *landable* win (the
  bigger lever, time-windowed sync, is externally blocked). The PowerSync
  local schema declared **zero** indexes, so every `watchInSpace` /
  `watchForSubject` / windowed-attendance query **full-scanned + sorted**
  its table on every stream emission — and `entries` / `attendance_records`
  grow unbounded with history. Added 5 indexes on `entries` (one per
  query shape: space, space+kind, subject, group+kind, block — each with
  `recorded_at DESC` as the trailing column so the `ORDER BY … LIMIT` is a
  direct index prefix) and 3 on `attendance_records` (subject+date,
  space+date, group+date). PowerSync builds these locally on the next
  launch over existing rows — **no re-sync, no local wipe** (non-destructive
  schema change). Mechanism: PowerSync creates expression indexes on the
  `ps_data__*` storage matching the view's `json_extract` columns, so
  SQLite's planner uses them for the Drift-issued queries.
- **Per-child N+1 watches — DONE.** A roster screen that watched a family
  provider PER child opened N live streams — at a 100-child program, 100
  subscriptions. Fixed everywhere it mattered: `role_deck_screen` +
  `heroes_hub_screen` (one `heroesInSpaceProvider` stream + a
  `subjectId → card` map), the Action Words program hub (new
  `actionWordsCollectionsBySubjectProvider` off the existing space stream),
  and the Insights late-streak rule (new windowed
  `recentAttendanceBySubjectProvider` replacing a per-subject attendance
  stream per child). Single-child screens keep the family (one stream —
  correct). Rule going forward: resolve per-child data from ONE space-wide
  stream + a map, not a per-row watch.
- **Hot-path JSON decode — mostly DONE.** `momentsFrom` (which
  `jsonDecode`s each entry's `details`) ran inside `build()` on the live
  Story screens, so every incidental rebuild re-decoded the whole list —
  the "no computation in build()" rule. Hoisted into memoizing providers
  (`momentsForSubjectProvider` for the per-child timeline + showcase,
  `roomMomentsProvider` for the room story); the decode now runs once per
  data change. **Residuals, lower-cost, left as-is:** the character-sheet
  `_Milestones` strip (a bounded observation subset, `.take(4)`, inside a
  StatelessWidget on the file already slated for a split) and the
  PDF/book builders (`summer_book`, `book_screen` — one-shot at export, not
  a rebuild path). The deeper option (denormalize title/emoji/date onto
  columns to kill the decode entirely) still wants a profiler trace.
- **Oversized single-purpose files** (soft caps: 400 screen / 300
  provider / 200 widget): `entries_providers.dart` (~1060),
  `character_sheet_screen.dart` (~1200), `family_today_screen.dart`
  (~1120). Split `EntryActions` per kind; extract the inline widgets to
  their own files. Maintainability, not runtime.

**Prerequisites.** None for the indexes or the N+1 (both done); the rest
want a profiler trace or a refactor session.

### Search backend

Omnibox scoring runs in-memory over the visible-entities list. Fine
at a few hundred items, drags at thousands. Move to PowerSync `query`
subscriptions with `LIKE` filters, or a Supabase Edge Function for
full-text.

**Prerequisites.** A program with enough rosters / entries to feel
the drag. Not today.

### Multi-region

Supabase is one region per project. Latency to APAC / EMEA from a
US-region project hurts. Federate when geography demands it.

**Prerequisites.** A customer outside the project's region asking.

---

## Changelog

- **2026-05-18** — Doc created during the scaling audit. Items
  inventoried; dismiss / snooze shipped.
- **2026-06-19** — Re-audit after the 2026-06 feature wave (sync /
  performance / hotspot guards). Fixed the role-deck per-child N+1 (one
  `heroesInSpaceProvider` stream, not N). Confirmed the recap upsert is
  safe (newest-first ordering keeps today's row in range) and the
  showcase/story loads are bounded (limit 50/300). Recorded the recap's
  per-child-per-day growth against the time-windowed-sync item, plus the
  remaining code-side follow-ups (heroes-hub N+1, hot-path JSON decode,
  oversized files).
- **2026-06-19 (cont.)** — Landed the code-side scale wins. **Added the
  first local SQLite indexes** (5 on `entries`, 3 on `attendance_records`)
  — every hot watch was full-scanning an unbounded table; non-destructive,
  builds on next launch. **Closed the per-child N+1 everywhere** (heroes
  hub, role deck, Action Words hub, Insights late-streak). Remaining:
  hot-path JSON-decode memoization (wants a profiler trace) and the
  oversized-file splits (maintainability).
- **2026-06-19 (cont. 2)** — Hoisted the `momentsFrom` decode out of
  `build()` on all three live Story screens into memoizing providers
  (`momentsForSubjectProvider`, `roomMomentsProvider`). Hot-path JSON
  decode now mostly closed; residuals are one bounded subset + the
  one-shot PDF builders. Remaining scale item: oversized-file splits
  (maintainability, not runtime).
