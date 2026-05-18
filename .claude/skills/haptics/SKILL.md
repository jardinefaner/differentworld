---
name: haptics
description: Wire HapticFeedback on every primary tap, FAB press, and successful save. Triggered when adding interactive widgets that trigger a state change.
---

# Haptics on every meaningful tap

Cheap, compounds into "this app feels cared-for." On iOS and Android both
plug into the system haptic engine — no extra deps.

## Add to

| Site | Feedback |
|---|---|
| Tap a list row (drill-in) | `HapticFeedback.selectionClick()` |
| Tap a status chip / cycle a state | `HapticFeedback.selectionClick()` |
| Press a primary FAB (commits state) | `HapticFeedback.mediumImpact()` |
| Confirm a destructive action | `HapticFeedback.heavyImpact()` |
| Save success | `HapticFeedback.lightImpact()` |
| Long-press → context menu open | `HapticFeedback.mediumImpact()` |

## Don't

- Don't trigger on every keystroke
- Don't trigger on hover (mouse-only)
- Don't trigger inside a scroll gesture (Flutter handles those)

## Boilerplate

```dart
import 'package:flutter/services.dart';

onTap: () {
  unawaited(HapticFeedback.selectionClick());
  // ... the actual action
},
```

`HapticFeedback.*` returns `Future<void>`; wrap with `unawaited(...)` to
silence the `discarded_futures` lint.
