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
| **Devon** | Co-parent read-state badges on messages + reports | M |
| **Jordan** | Outdoor mode toggle (high-contrast, bigger glyphs) | S |
| **Pat** | Substitute handoff (director flips an absent counselor's cohort lead) | M |
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
| Multi-program switcher in drawer | S | Single-program design today |
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

- **7d9f6d1** — Sentry wiring. `sentry_flutter: ^9.6.0` added,
  `main.dart` initializes when `Env.hasSentry` is true (else
  no-ops). `sendDefaultPii = false`, crash-only sampling,
  debug/release environment tags. Pre-existing
  `FlutterError.reportError` calls now route through Sentry
  automatically.
