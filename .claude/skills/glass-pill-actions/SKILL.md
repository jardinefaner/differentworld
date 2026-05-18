---
name: glass-pill-actions
description: Top-right screen actions go in a FloatingActions glass pill — search, sync indicator, save, edit, etc. Triggered when adding a screen action / icon.
---

# Glass-pill actions in the top-right

`EdgeScaffold(actions: [...])` renders a `FloatingActions` glass pill in
the top-right. Up to ~3 icons before it gets crowded.

## Common pattern

```dart
EdgeScaffold(
  actions: [
    if (canSearch) IconButton(
      tooltip: 'Search',
      icon: const Icon(Icons.search),
      onPressed: onOpenOmnibox,
    ),
    const SyncStatusIndicator(),
    IconButton(
      tooltip: 'Settings',
      icon: const Icon(Icons.settings_outlined),
      onPressed: () => context.push('/settings'),
    ),
  ],
  body: ...,
)
```

## What goes here

| Action | Icon |
|---|---|
| Open omnibox | `Icons.search` |
| Sync status | `SyncStatusIndicator()` (no IconButton wrapper) |
| Settings (Today only) | `Icons.settings_outlined` |
| Save (form / detail with edits) | `Icons.check` (or spinner during save) |
| Edit (detail → form sheet) | `Icons.edit_outlined` |
| Filter (Morning Checklist) | `Icons.filter_list` / `Icons.filter_alt` |

## Don't

- Don't put more than 3 actions in the pill — promote one to a FAB or
  drop it
- Don't use `PopupMenuButton` for primary actions — secondary filters
  (like the Morning Checklist filter) are fine
- Don't put primary CTAs (Save, Submit, Create) here — those belong as
  FABs in the thumb zone or as in-content buttons
- Don't reach for a hamburger / overflow menu — see `no-hamburger`

## Save action timing

Only show the save icon when there ARE unsaved changes. From the
program-settings + member-detail pattern:

```dart
actions: [
  if (_draft != null || _draftRole != null)
    IconButton(
      tooltip: 'Save',
      icon: _saving
          ? const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.check),
      onPressed: _saving ? null : _save,
    ),
],
```
