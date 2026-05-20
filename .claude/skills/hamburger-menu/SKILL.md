---
name: hamburger-menu
description: The hamburger / drawer is owned by AppShell now, not per-screen. New screens don't pass `drawer:` — it appears automatically in the top-left whenever the route doesn't show a back button. Triggered when discussing nav chrome or adding new top-level destinations.
---

# Hamburger lives in AppShell

As of the persistent-chrome refactor, the drawer is OWNED BY APPSHELL
and the hamburger pill is part of the persistent top chrome layer.
Individual screens no longer pass `drawer:` to EdgeScaffold.

## What renders where

The hamburger is the GROUND for the app — visible on every signed-in
route except kid mode, so a user is never more than one tap from the
top-level destinations.

- **Top-left, home pages** (chrome.showBack == false): **FloatingHamburger**
  alone in the corner.
- **Top-left, drill-in pages** (chrome.showBack == true):
  **FloatingHamburger + FloatingBack in a Row**, hamburger left,
  back to its right. Both visible, both tappable. The drawer is
  also accessible via swipe-from-left-edge as a redundant gesture.
- **Login surface** (viewer.isSignedIn == false): no hamburger, no
  drawer.
- **Kid mode** (kidModeProvider == true): no hamburger, no drawer, no
  chrome at all.

## How a screen opts into "home" vs "drill-in"

Set `showBack` on `EdgeScaffold`:

```dart
// Home — hamburger in top-left (rendered by AppShell)
EdgeScaffold(
  showBack: false,
  // NOTE: drawer: const MainDrawer() is no longer needed; AppShell
  // owns it. The `drawer` param is still accepted for source
  // compatibility but does nothing.
  actions: const [SyncStatusIndicator()],
  body: ...,
)

// Drill-in — back arrow in top-left
EdgeScaffold(
  // showBack defaults to true
  backFallbackRoute: '/parent-if-deep-linkable',
  actions: const [/* ... */],
  body: ...,
)
```

## What goes in the Drawer

`lib/shared/widgets/main_drawer.dart` — trimmed to 5 destinations
(Today, Schedule, Captures, Tasks, Settings). Everything else
lives in the omnibox. The drawer also has a hero "Search anything"
tile that opens the omnibox.

When you add a new top-level destination:
1. **Don't** automatically add it to the drawer.
2. **Do** add an `OmniboxEntry` for it (see `omnibox-modes` skill).
3. Add a drawer tile ONLY if it's a destination the user will hit
   dozens of times per session.

## Don't

- Don't pass `drawer:` to `EdgeScaffold` — it's ignored.
- Don't add a hamburger to a drill-in screen; the back arrow takes
  that slot.
- Don't put primary CTAs in the Drawer — they belong in the top-right
  action pill via `EdgeScaffold.actions`.
- Don't bloat the drawer past 5 destinations.

## Implementation pointer

- `lib/shared/widgets/app_shell.dart` — owns the Scaffold's drawer,
  renders FloatingHamburger when `!chrome.showBack && showDrawer`
- `lib/shared/widgets/main_drawer.dart` — the drawer content
- `lib/shared/widgets/floating_hamburger.dart` — the pill itself
- `lib/shared/widgets/route_chrome.dart` — the chrome stack (see
  `route-chrome` skill)
