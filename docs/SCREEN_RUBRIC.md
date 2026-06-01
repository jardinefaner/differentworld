# Screen rubric — the per-screen quality gate

The standard every screen is held to, in one place, so it's **enforced,
not rediscovered.** This is the source of truth the `Screen Rubric`
reviewer agent checks against (see `~/.claude/agents/screen-rubric.md`),
wired into the review pipeline (the Council, and the stop-gate hook).

Why this exists: layout/state defects (content under the chrome, a list
with no empty state, a tap that does nothing) kept recurring because the
standard lived in people's heads and in scattered CLAUDE.md sections. This
consolidates them into one checklist a reviewer can run mechanically.

## How it's used

- **Per screen.** Point the `Screen Rubric` agent at a screen file (or a
  diff). It returns a verdict per item: ✅ pass / ⚠️ warn / ⛔ blocker /
  — n/a, with `file:line` evidence and a concrete fix.
- **In the pipeline.** The Council spawns it alongside Preflight / Red
  Team / UX Critic for any change that touches a screen. `/ship` runs the
  Council.
- **Severity → gate.** Any ⛔ blocks ship. ⚠️ should be fixed or
  explicitly deferred with a reason. The four-states items (B) and the
  chrome/viewport items (A) are blockers for any data screen.

## Scope

Applies to any widget that is a **screen** (something pushed as a route /
rendered by `EdgeScaffold`). Not every item applies to every screen — a
full-bleed camera has no "empty state," a static info page has no "form."
Mark inapplicable items **n/a**; don't force them.

---

## A. Chrome & viewport (the recurring offender)

- **A1 — Uses `EdgeScaffold`, not a raw `Scaffold`/`AppBar`.** The whole
  chrome system (floating pills, glass, chrome-inset injection) rides on
  it. Verify: the screen returns `EdgeScaffold(...)`. *Blocker.*
- **A2 — Top content clears the floating chrome.** Either the first
  scrollable child is a `ContentHeader`, **or** the body is wrapped in a
  `SafeArea`. EdgeScaffold injects the chrome band into
  `MediaQuery.padding.top`, so either clears it automatically. **Do NOT
  add `+ ShellMetrics.topChromeHeight` by hand** — that double-insets.
  Verify: no manual `topChromeHeight` in the screen; a `ContentHeader` or
  `SafeArea` is present (or the body is intentionally full-bleed). *Blocker.*
- **A3 — Bottom content clears the omnibox bar.** The bottom ~76 dp is the
  floating composer. A scroll view needs bottom padding (`fromLTRB(.., 96)`
  is the convention) so the last row/button isn't hidden; a fixed bottom
  control needs to sit above the bar. Verify: scroll padding bottom ≥ ~76,
  or content is short enough never to reach the bar. *Blocker for screens
  with bottom-anchored controls; warn otherwise.*
- **A4 — Uses the full viewport; long text is constrained for reading.**
  Content fills the width (no accidental narrow column, no large dead
  gutters), but long-form text / forms are wrapped in
  `ConstrainedBox(maxWidth: ~600)` centered so lines don't stretch on
  desktop. Verify: no hardcoded small `width:`; forms/prose constrained. *Warn.*
- **A5 — Responsive across the breakpoint matrix.** Phone / tablet /
  desktop look intentional. Master-detail screens use a `LayoutBuilder` or
  the shared `Breakpoints`; nothing assumes phone width. Verify: no
  `MediaQuery.sizeOf` math in `build` that only works at one size. *Warn.*

## B. The four states (every data / list screen)

- **B1 — Loading is a skeleton, not a bare spinner**, and only on first
  load (`LoadingSlot.list/.cards`). Verify: `AsyncValue.when`/stream
  loading branch renders `LoadingSlot`, not `CircularProgressIndicator`
  alone. *Warn.*
- **B2 — Empty state is designed.** `EmptyState(icon:, title:, message:,
  action:)` — never a blank screen or a bare `SizedBox.shrink()`. Verify:
  the empty branch renders `EmptyState`. *Blocker.*
- **B3 — Error is a recoverable banner, not a wipe.** `ErrorState(...,
  onRetry:)` or a non-blocking banner. **Offline is NOT an error** — show
  a "syncing…" affordance, never an error. Verify: error branch renders
  `ErrorState`/banner; no "offline" error copy. *Blocker.*
- **B4 — Data (happy path) renders from a Drift stream**, list-virtualized
  (`ListView.builder`/`SliverList`, never `ListView(children: [huge])`). *Warn.*

## C. Composition & visual consistency

- **C1 — Built from the composition primitives**, not hand-rolled chrome.
  Tappable rows → `FeatureCard`; aggregator sections → `SectionCard`;
  identity → `PersonAvatar`. **A raw `Material(...InkWell...)` for a row is
  a smell.** Verify: grep the screen for `Material(`/`InkWell(` that
  duplicate a primitive. *Warn.*
- **C2 — Glass for chrome surfaces.** Sheets via `showGlassSheet`;
  overlays/pills via `GlassPanel`. No ad-hoc opaque `Material` sheet. *Warn.*
- **C3 — Destructive actions** use `DestructiveButton` +
  `confirmDestructive(...)`. *Blocker for anything that deletes.*

## D. Interaction integrity

- **D1 — Multi-child layout widgets with conditional/dynamic children
  carry stable `Key`s** (`Stack`/`Column`/`Row`/`Wrap`/`ListView`). Missing
  keys → siblings rebuild → `TextField` drops its IME. Verify: any
  `if (...) widget` child or runtime-growing list has `ValueKey`. *Blocker
  if a `TextField` is among the siblings; warn otherwise.*
- **D2 — No dead taps.** Every `onTap`/`onPressed` navigates, mutates, or
  shows visible feedback. A handler that can early-return to nothing
  (`if (x == null) return;`) is a defect — drop the affordance instead. *Blocker.*
- **D3 — Input surfaces honor the IME rules.** Focus survives a route push
  triggered by typing; `requestFocus` is followed by
  `TextInput.show`; no `showModalBottomSheet`/`showDialog` from
  `onChanged`; no hardcoded focus delays. (See Interaction invariants in
  CLAUDE.md / the Interaction Guard.) *Blocker.*
- **D4 — Forms:** inline validation (`onChanged`/`onFieldSubmitted`), draft
  persistence for > 3 fields, submit disabled during submission with an
  inline spinner (never a full-screen overlay). `DismissGuard` when dirty. *Warn.*

## E. Accessibility & i18n

- **E1 — Touch targets ≥ 48×48 dp**, even on desktop. *Blocker.*
- **E2 — Interactive elements have `Semantics(label:)` or `Tooltip`.** Icon
  buttons especially. *Warn.*
- **E3 — Text scales to 200% without truncation.** No fixed-height
  containers wrapping text; respects `textScaler`. *Warn.*
- **E4 — User-facing strings are localizable** (no hardcoded copy bound for
  translation). i18n infra is deferred app-wide, so this is **note-level**
  until `gen-l10n` lands — but flag new hardcoded strings.

## F. Offline-first & privacy

- **F1 — Reads come from Drift streams**, never a direct
  `Supabase.instance...from(...)` in the widget/provider (except the
  documented family/photo/export fallbacks). *Blocker.*
- **F2 — Writes are optimistic** — commit to Drift, queue upload, no
  awaited network round-trip in a user handler. *Blocker.*
- **F3 — No PII in logs.** Any `debugPrint`/`print` that could carry a
  name, photo path, contact, or narrative is `kDebugMode`-gated. *Blocker.*

---

## Verdict format (what the agent returns)

```
## Screen Rubric — <file>

⛔ BLOCKERS (must fix before ship)
- [A2] lib/features/x/x_screen.dart:48 — body starts at SafeArea top but
  adds `+ ShellMetrics.topChromeHeight` in ContentHeader call → double
  inset (56 dp gap). Fix: drop the manual add; the injection covers it.

⚠️ WARN (fix or defer-with-reason)
- [B1] :72 — loading branch is a bare CircularProgressIndicator. Use
  LoadingSlot.list.

✅ PASS: A1 A3 A4 A5 B2 B3 B4 C1 C2 D1 D2 F1 F2 F3
— N/A: C3 (no destructive action) · D3 D4 (no input) · E4 (no new copy)

Verdict: 1 blocker, 1 warn → NOT shippable until A2 fixed.
```

Be specific: cite `file:line`, name the rubric id, give the one-line fix.
No vague "consider improving." Every finding is actionable or it's noise.
