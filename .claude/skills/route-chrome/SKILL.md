---
name: route-chrome
description: The persistent top chrome (back / hamburger / actions / topOverlay) is rendered by AppShell from a STACK in routeChromeProvider. Each EdgeScaffold pushes its entry on mount and pops on dispose. Triggered when discussing screen actions, the back button, or chrome that "leaks" across routes.
---

# Persistent route chrome (the stack pattern)

The top chrome (back arrow / hamburger + actions + optional topOverlay)
lives in **AppShell**, not in each route. EdgeScaffold publishes its
chrome into a stack-backed Riverpod notifier; AppShell paints the
top of the stack as floating Positioned widgets above the page.

Result: navigating A → B animates only the page content; the back /
actions stay anchored. Popping B back to A restores A's chrome
automatically because B's dispose pops its own entry off the stack.

## Setting chrome from a screen

You don't talk to `routeChromeProvider` directly. Just pass props to
EdgeScaffold:

```dart
EdgeScaffold(
  showBack: true,                          // → FloatingBack in top-left
  backFallbackRoute: '/parent',            // → for cold-launch deep links
  actions: const [SyncStatusIndicator()],  // → top-right pill
  topOverlay: null,                        // → for full-width search bar etc.
  body: ...,
);
```

EdgeScaffold's `initState` schedules a microtask that calls
`routeChromeProvider.notifier.push(this, chrome)`. Its `dispose`
calls `.pop(this)`. The microtask defer is required — initState
runs DURING the parent route's build phase, so a synchronous write
to a Riverpod notifier that AppShell is watching trips the
"modified provider while the widget tree was building" assertion.

## Why a stack and not a single slot

Without the stack, this happens:

1. Today mounts → publishes Today's chrome
2. Settings push → publishes Settings's chrome (overwrites)
3. Vehicles push → publishes Vehicles's chrome (overwrites)
4. Back to Settings → Vehicles disposes → no republish from Settings →
   Vehicles's chrome lingers ← **bug**

With the stack:

1. Today push → stack `[Today]`. State = Today.
2. Settings push → stack `[Today, Settings]`. State = Settings.
3. Vehicles push → stack `[Today, Settings, Vehicles]`. State = Vehicles.
4. Vehicles pop → stack `[Today, Settings]`. State = Settings.
5. Settings pop → stack `[Today]`. State = Today.

## When a chrome change INSIDE the same route doesn't show up

`didUpdateWidget` only republishes when one of (showBack, actions,
backFallbackRoute, topOverlay) compares unequal. The actions list
compares by `identical` — pass the SAME list instance across builds
(use `const` or store in a field) if you want stable identity, or
build a new list each time if you want to force republish.

## Top-left slot logic in AppShell

```
chrome.topOverlay != null   → topOverlay covers left + right
chrome.showBack == true     → FloatingBack
chrome.showBack == false &&
  viewer.isSignedIn &&
  !inKidMode                → FloatingHamburger
otherwise                   → nothing
```

The hamburger opens AppShell's `Scaffold.drawer` (which is
`MainDrawer` when signed in). See `hamburger-menu` skill.

## Kid mode

When `kidModeProvider == true`, AppShell suppresses the chrome layer
entirely. The route content fills the whole body. See `kid-mode`
skill.

## Implementation pointers

- `lib/shared/widgets/route_chrome.dart` — RouteChrome + Notifier
- `lib/shared/widgets/edge_scaffold.dart` — publishes via init/update,
  pops on dispose
- `lib/shared/widgets/app_shell.dart` — renders the chrome via
  `_buildTopChrome`

## Don't

- Don't write to `routeChromeProvider` directly — go through
  EdgeScaffold.
- Don't put a back arrow or hamburger INSIDE your route's body —
  AppShell already renders one in the persistent layer.
- Don't try to make chrome animate WITH the page transition — the
  whole point is that it stays anchored.
