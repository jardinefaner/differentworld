# Navigation fix — the reliable single-navigator back model

**Status:** implemented on `feat/reliable-nav`.

## The bugs (user-reported, on-device)

- "I go back, and it exits the app."
- "I go somewhere, I go back, and it goes somewhere else / to a screen I
  never visited."
- "Swiping left exits at some screens instead of going back."

## Root cause

Two compounding problems in the old AppShell back model:

1. **It decided off `matchedLocation`.** Inside a `ShellRoute` builder
   `GoRouterState.of(context).matchedLocation` is *shell-relative* and
   unreliable (documented gotcha — it stays at `/breaks` while the real
   location is a child route). So `atRoot = matchedLocation == '/'` was
   frequently wrong, and `canPop = !atRoot` with it.
2. **Top-level routes reached via `context.go` replace the shell stack.**
   Most top-level routes (`/schedule`, `/activity/*`, `/vehicles`, …) are
   direct children of the `ShellRoute`, NOT nested under `/`. Reaching one
   via `go` leaves the shell navigator holding a **single** route. A back
   gesture then has nothing to pop → the OS pops the lone route → the
   **app exits**. And a `go` to a *nested* route imputes an unvisited
   parent → "back goes to a screen I never visited."

## Why NOT StatefulShellRoute (rejected — don't re-attempt without reading this)

The first instinct was `StatefulShellRoute.indexedStack` with branches
(Today / Settings / Vehicles) for per-tab back stacks. **Rejected after
proving it would *reintroduce* the user's bug.** This app is a
**single-stack, omnibox-driven** app: the global omnibox + Today screens
`push` into `/settings/*` and `/vehicles/*` **~30+ times** from
shell/branch-0 contexts (audited). With branches, every one of those is a
*cross-branch push*. go_router derives the active branch from the matched
location's navigator (`route.dart` `_indexOfBranchNavigatorKey`), so a
cross-branch `push('/settings/team')` from Today either switches to the
Settings tab and builds the stack `[/settings, /settings/team]` — so
**back lands on `/settings`, a screen the user never visited** — or pushes
onto the wrong (invisible) navigator. Both are wrong. Tabs with
independent stacks break the "push anything, back returns to where I
pushed from" contract this app lives by. The 161 free-cross-linking push
sites are the tell: it's one stack, not tabs.

## The fix (single reliable navigator)

Keep the ONE `ShellRoute` navigator. Decide back/swipe off the navigator's
**real `canPop()`** (a fact about the actual stack), never
`matchedLocation`. And when there's nothing to pop, return **HOME** rather
than letting the app exit.

The decision table is a pure function in
`lib/shared/widgets/shell_back_action.dart` (`decideShellBack`), unit-tested
in `test/unit/shell_back_action_test.dart`:

| state | action |
|---|---|
| overlay open | close the omnibox overlay |
| shell can pop | system pop (normal back) |
| can't pop · kid mode | no-op (router redirect owns the lock) |
| can't pop · not home | **go home** ← the fix for "back exits" / "wrong back" |
| can't pop · at `/` or `/login` | confirm app exit |

`AppShell` feeds it `context.canPop()` (which go_router's delegate resolves
to the shell navigator's `canPop()`) + `uri.path` (reliable, unlike
`matchedLocation`).

### The stale-by-one gotcha (important)

`context.canPop()` / `navigatorKey.currentState.canPop()` both read the
shell navigator's stack — and that read is **stale-by-one during
`AppShell.build`**, because AppShell (the ShellRoute builder) builds
*before* its child navigator processes the just-pushed page. So the
build-time read is used **only as a conservative `PopScope.canPop` gate**;
the `onPopInvokedWithResult` handler **re-reads `canPop` at gesture time**
(when the stack has settled) to make the real decision. This is what makes
a first-level push (home → detail) **pop** back to home properly instead
of falling through to go-home. Consequence: deep routes (built with the
stack already ≥2) get the interactive predictive-back animation; routes
pushed onto a 1-deep stack pop via go_router in the handler (no interactive
follow, but correct destination + animation). Acceptable asymmetry.

## Files

- `lib/shared/widgets/shell_back_action.dart` — pure decision table +
  `shellShouldAllowSystemPop` gate. The single source of truth; tested.
- `lib/shared/widgets/app_shell.dart` — `build()` computes the gate;
  `onPopInvokedWithResult` re-reads at gesture time and dispatches.
- `lib/shared/widgets/floating_back.dart` — the visual back pill now reads
  `canPop` at TAP time (was build time → stale; Interaction Guard) and
  falls back to the home route.
- `test/unit/shell_back_action_test.dart` — pins all five rows + the
  gate/decision invariant. The regression net for this bug class.

## Verify on-device (Pixel 6)

- From Today, omnibox-push into a detail (e.g. a kid, a vehicle) → back →
  returns to Today (not exit, not a screen you never saw).
- Drawer → Schedule (a top-level `go`) → back → returns HOME (not exit).
- Drill two deep (e.g. group → member) → back → member's parent → back →
  home.
- Open the omnibox overlay → back/swipe → closes the overlay (route
  unchanged).
- At Today (`/`) → back → "Close Different World?" confirm.
- Edge-swipe (iOS-style) behaves the same as system back everywhere — no
  surprise app-exit.
- Kid mode (survey-take) → back → no-op (can't escape); staff 5-tap exit
  still works.
