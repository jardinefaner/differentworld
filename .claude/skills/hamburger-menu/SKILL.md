---
name: hamburger-menu
description: The home page (Today) hosts a hamburger menu in the top-left that opens a Drawer with every primary destination. Drill-in screens keep the back arrow. Triggered when discussing navigation or adding new top-level destinations.
---

# Hamburger menu on home, back arrow on drill-ins

The hamburger is the discoverable nav surface. The omnibox is the
power-user nav surface. Both live in this app — they don't compete.

## Where it lives

- **Top-left of Today** (and any future home-equivalent screen) — a
  small glass-pill with `Icons.menu` that opens a left Drawer
- The same Drawer is also reachable via swipe-from-left-edge on any
  screen, since `EdgeScaffold.drawer` is forwarded to the underlying
  `Scaffold`
- Drill-in screens keep their `FloatingBack` glass-pill in the top-left
  (which is what users expect — back, not menu, when there's a parent)

## What goes in the Drawer

`lib/shared/widgets/main_drawer.dart` already implements this. Top to
bottom:

1. **Header** — program name + signed-in user avatar / name / role
2. **Primary destinations** — Today, Morning checklist
3. **Classrooms section** — every classroom the user can see (live
   from `groupsProvider`)
4. **Settings section** — Program settings (director-only), Team, All
   settings
5. **Footer** — Sign out (destructive button styling)

When you add a top-level destination, add a `_DrawerTile` for it in
the right section.

## Wire it up

```dart
import 'package:differentworld/shared/widgets/main_drawer.dart';

return EdgeScaffold(
  showBack: false,            // home page
  drawer: const MainDrawer(), // hosts the menu
  actions: [/* search, sync */],
  body: ...,
);
```

Drill-in screens DON'T need to pass a drawer — they keep the back
button. If you want the drawer reachable via swipe even from a deep
detail screen, pass `drawer: const MainDrawer()` on those too; the
hamburger pill won't render (because `showBack: true`) but the swipe
gesture still works.

## Don't

- Don't add a hamburger to every screen — back-arrow-and-hamburger-on-
  the-same-side is confusing
- Don't put primary CTAs in the Drawer — CTAs belong as FABs in the
  thumb zone
- Don't hide the omnibox just because the Drawer exists — they serve
  different intents (browse vs. command-line)
- Don't add a Drawer with 12+ tiles — promote the heavy hitters; the
  rest live in `/settings`
