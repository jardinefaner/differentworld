---
name: no-hamburger
description: Refuse to add a hamburger menu (☰) anywhere. Triggered when navigation chrome, side menus, or Drawer widgets are being discussed or added.
---

# No hamburger menus

The 2010s pattern of stuffing nav into a hidden side drawer is dead in this
app. Hamburger menus hide discoverable functionality behind an opaque icon
and force a navigation step before the user can see their options.

## Forbidden

- `Scaffold(drawer: ...)`
- `Scaffold(endDrawer: ...)`
- `IconButton(icon: Icon(Icons.menu), ...)` opening any side panel
- "More" overflow menus that hide primary actions
- `PopupMenuButton` for primary navigation (it's OK for *secondary* filtering
  like the Morning Checklist filter chip)

## Instead

| You want | Use |
|---|---|
| Quick jump to any screen | The **omnibox** (swipe right from Today, or the search icon in the top-right glass pill). It's the command palette — already wired. |
| Per-screen actions | The **floating actions pill** in the top-right of `EdgeScaffold` |
| Primary CTA | A `FloatingActionButton.extended` in the thumb zone |
| Switching between sibling views | A horizontal `PageView` (like Today ↔ Omnibox) or a TabBar at the top of content (not chrome) |

If you find yourself reaching for a Drawer, you've identified a real need
for either (a) more discoverable surface in the AppBar pill, or (b) a new
top-level destination — promote it instead of hiding it.
