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

### Time-windowed sync via client parameters

**Why.** `attendance_records`, `entries`, and `vehicle_logs` grow
linearly. At 50 kids × 5 obs/week × 40 weeks = 10k observations per
year per program. Cold launch downloads everything in `by_space`.
Fine today; not fine at year 3.

**What's blocking.** PowerSync's sync-rule SQL doesn't support
`now()` / `date()` / `INTERVAL` (the user hit this on 2026-05-18).
The supported pattern is `request.parameters.<name>` populated by
the client at subscribe time. To use it we need to:

1. Switch `by_space` from `auto_subscribe: true` to manual
   subscription, OR find a way to inject the cutoff through the JWT
   (Supabase Auth doesn't easily let us add custom claims, so this
   is the harder path).
2. Compute `cutoff_at` client-side at boot.
3. Re-subscribe on day-rollover so the window slides.

**Verification plan.**
1. In a staging environment, paste a parameterized sync rule with
   `request.parameters.cutoff_at`. Confirm dashboard accepts it.
2. From a test client, call `db.syncStream('by_space').subscribe(
   parameters: {'cutoff_at': '…'})`. Confirm the older rows drop
   from the local DB on the next checkpoint.
3. Time-jump the device clock, force a re-subscribe, confirm the
   window slides.

**Effort.** Real day of work. ~80 lines of Dart in the sync layer
+ a sync-rules deployment + a day-rollover scheduler.

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
