---
name: no-bottom-nav
description: Don't add a traditional BottomNavigationBar or NavigationBar with 3-5 tab destinations. Use the PageView + omnibox pattern this app already has.
---

# No bottom nav bar

Bottom tab bars waste 56–80 dp of vertical real estate on every screen and
force a fixed N-destination IA. This app has more than N first-class
surfaces and they don't all deserve permanent chrome.

## Forbidden

- `Scaffold(bottomNavigationBar: ...)`
- `NavigationBar(destinations: [...])`
- `CupertinoTabScaffold`
- "App rail" widgets that pretend they're nav bars on the side

## Instead

- **Today** is the single landing page. Everything else is reached via
  drill-in (`context.push`) or the **omnibox** (swipe-right from Today
  or tap the floating search icon in the top-right pill).
- For sibling views, use a horizontal `PageView` — that's how
  `_SignedInHome` puts Omnibox on page 0 and Today on page 1.
- If you genuinely have 3+ peer destinations a user toggles dozens of
  times per session, propose a `SegmentedButton` at the top of content
  before reaching for a nav bar.
