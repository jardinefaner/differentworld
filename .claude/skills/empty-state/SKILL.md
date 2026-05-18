---
name: empty-state
description: Every list / data screen has a designed empty state with icon, title, message, and a primary CTA. Triggered when adding a new screen with a list or scaffolding an empty path.
---

# Empty states are designed, never blank

The shared widget is `lib/shared/widgets/empty_state.dart`. Every
non-trivial list path should route through it for the empty case.

## Use

```dart
import 'package:differentworld/shared/widgets/empty_state.dart';

if (items.isEmpty) {
  return EmptyState(
    icon: Icons.child_care_outlined,
    title: 'No students yet',
    message: 'Add your first student to start taking attendance '
        'and logging observations.',
    action: FilledButton.icon(
      onPressed: () => SubjectFormSheet.show(context, groupId: groupId),
      icon: const Icon(Icons.add),
      label: const Text('Add student'),
    ),
  );
}
```

## Copy rules

- **Title**: a single sentence, factual, not a question
- **Message**: one or two sentences explaining what would normally be
  here AND what to do next
- **Action**: imperative verb-noun ("Add student", "Invite teammate",
  "Create classroom")

## Four UX states

CLAUDE.md spec says every list/data screen has all four:

1. **Loading** — `CircularProgressIndicator`. Shows once; after first
   sync, this should never appear again.
2. **Empty** — `EmptyState` with CTA. ← this skill.
3. **Data** — happy path.
4. **Error** — `EmptyState` with `Icons.error_outline` for non-recoverable;
   inline banner for recoverable. Never a wipe-the-screen dialog.

If your screen only has data + loading, add the empty + error before you
ship.
