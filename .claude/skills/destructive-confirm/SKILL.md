---
name: destructive-confirm
description: Every destructive action (delete / revoke / remove) routes through confirmDestructive() and uses DestructiveButton for the trigger. Triggered when adding delete / archive / remove handlers.
---

# Destructive actions confirm, no exceptions

Shared helpers in `lib/shared/widgets/destructive_button.dart`.

## confirmDestructive

```dart
import 'package:differentworld/shared/widgets/destructive_button.dart';

final confirmed = await confirmDestructive(
  context,
  title: 'Delete this classroom?',
  message: '${group.name} and its assignments will be removed for '
      'everyone on your team.',
  confirmLabel: 'Delete classroom',  // verb + noun, never just "Delete"
);
if (!confirmed || !mounted) return;
```

## DestructiveButton

Use inside form sheets at the bottom-left of the action row:

```dart
Row(
  children: [
    if (_isEdit)
      DestructiveButton(
        label: 'Remove',
        onPressed: _saving ? null : _delete,
      ),
    const Spacer(),
    TextButton(onPressed: ..., child: const Text('Cancel')),
    const SizedBox(width: 8),
    FilledButton.icon(onPressed: _save, ...),
  ],
)
```

## In list items

Use `Dismissible` with `confirmDismiss: (_) => confirmDestructive(...)`
— see the `_InviteTile` in `team_screen.dart` for the canonical example.

## Don't

- Don't ship a destructive action without confirmation
- Don't write generic copy like "Are you sure?" — be specific
- Don't put the destructive button on the same axis as Save (separate
  it visually with a `Spacer()`)
