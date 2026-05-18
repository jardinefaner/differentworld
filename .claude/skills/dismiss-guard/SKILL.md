---
name: dismiss-guard
description: Any modal bottom sheet form with >3 fields wraps in DismissGuard so drag-to-dismiss / scrim-tap doesn't silently throw away unsaved input. Triggered when building or modifying form sheets.
---

# Wrap form sheets in DismissGuard

`lib/shared/widgets/dismiss_guard.dart` intercepts the drag-down / scrim-tap
dismiss and shows a "Discard changes?" dialog when the form is dirty.

CLAUDE.md spec says any form with >3 fields persists drafts. Until we
build offline draft persistence, the dismiss guard is the minimum bar.

## Pattern

Each sheet implements its own `_isDirty()`:

```dart
bool _isDirty() {
  final original = widget.subject;
  if (original == null) {
    // New: dirty if anything is typed.
    return _firstName.text.trim().isNotEmpty || /* etc */;
  }
  // Edit: dirty if anything diverges from the loaded row.
  return _firstName.text.trim() != original.firstName || /* etc */;
}
```

Then wrap the body:

```dart
return DismissGuard(
  isDirty: _isDirty,
  child: Padding(
    padding: EdgeInsets.only(bottom: keyboardInset),
    child: /* ... existing body ... */,
  ),
);
```

## When to skip

- Sheets with 1-3 trivial fields (e.g. a simple confirm dialog)
- Sheets that only display info with no form (invite share sheet)
- Status pickers, where the tap IS the commit

When in doubt, wrap it.
