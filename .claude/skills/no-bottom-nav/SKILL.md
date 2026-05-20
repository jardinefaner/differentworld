---
name: no-bottom-nav
description: No traditional BottomNavigationBar with 3-5 fixed tabs. The omnibox composer bar at the bottom is a COMMAND surface, not a nav tab bar. Triggered when proposing a bottom-tab-bar style widget.
---

# No bottom nav bar (but yes to the omnibox composer)

Bottom tab bars waste 56–80 dp of vertical real estate on every screen
and force a fixed N-destination IA. This app has more than N first-class
surfaces and they don't all deserve permanent chrome.

## Forbidden

- `Scaffold(bottomNavigationBar: ...)` (the AppShell's body holds the
  omnibox composer via Stack + Positioned; do not add another bar)
- `NavigationBar(destinations: [...])`
- `CupertinoTabScaffold`
- "App rail" widgets that pretend they're nav bars on the side

## What's at the bottom of every screen

The **omnibox composer bar** lives at `Positioned(bottom: 0)` inside
the AppShell's body Stack. It's NOT a nav bar — it's a COMMAND surface
(find / capture / dictate / slash command). All routes get it for
free; you don't add it per-screen.

- AppShell handles its layout, keyboard inset, kid-mode suppression
- Route content gets an automatic 76 dp bottom inset so the last
  save-button doesn't render behind the bar
- The bar morphs visually between three modes — see `omnibox-modes`

## Where navigation actually lives

- **The omnibox** — type anything to find it
- **The drawer** — hamburger in top-left (when no back arrow);
  5 top-level destinations (Today / Schedule / Captures / Tasks /
  Settings)
- **`context.push`** — drill-in navigation from cards / list items

## If you genuinely have 3+ peer destinations

Before reaching for a nav bar, try:
- `SegmentedButton` at the top of body content (for filter / view
  toggles)
- Tabs on the screen itself (TabBar inside the body, not in chrome)
- Multiple omnibox catalog entries that route to the different views

## Implementation pointer

- `lib/shared/widgets/app_shell.dart` — owns the bottom composer
- `lib/features/omnibox/bottom_omnibox_bar.dart` — the bar itself
- `lib/features/omnibox/omnibox_mode.dart` — search/capture/slash
  detection
