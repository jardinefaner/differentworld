---
name: shared-helpers
description: Pointer to lib/shared/ helpers that replace recurring boilerplate. Check here before re-implementing time formatting, space-id guards, subject pickers, or loading spinners.
---

# Shared helpers — use these, don't reinvent

Anything in `lib/shared/` is the canonical implementation. If a
feature reaches for one of these patterns, it imports from `shared/`
instead of copying.

## `relativeTimeAgo(when, {precision})`

`lib/shared/format/relative_time.dart`

```dart
import 'package:differentworld/shared/format/relative_time.dart';

Text(relativeTimeAgo(capture.createdAt));   // "5 min ago"
Text(relativeTimeAgo(sync.lastSyncedAt,
     precision: TimePrecision.seconds));    // "12s ago"
```

Output cuts: `just now` → `5 min ago` → `3 h ago` → `yesterday` →
`4 days ago` → `6 wk ago` → `2 y ago`.

## `viewer.requireSpaceId() / requireMemberId() / requireSpaceAndMember()`

`lib/shared/viewer_x.dart` — extension on `Viewer`.

```dart
import 'package:differentworld/shared/viewer_x.dart';

// One-liner replacing the if-null-throw block
final spaceId = ref.read(viewerProvider).requireSpaceId(action: 'capture');

// Get both in one shot (record destructuring)
final (:spaceId, :memberId) =
    viewer.requireSpaceAndMember(action: 'promote a capture');
```

The `action:` parameter is decoration for the error message. Pass it
when the call site is ambiguous.

## `pickSubject(context, title:, hintText:)`

`lib/shared/widgets/subject_picker_sheet.dart`

```dart
import 'package:differentworld/shared/widgets/subject_picker_sheet.dart';

final picked = await pickSubject(
  context,
  title: 'Whose observation is this?',
);
if (picked == null) return; // user dismissed
```

Returns `Subject?`. Includes search-as-you-type. Use anywhere the
user needs to attach an action to a specific child.

## `const LoadingSlot()`

`lib/shared/widgets/async_loading.dart`

```dart
import 'package:differentworld/shared/widgets/async_loading.dart';

fooAsync.when(
  loading: () => const LoadingSlot(),
  error: (_, _) => const EmptyState(icon: Icons.error_outline, title: '…'),
  data: (rows) => …,
);
```

Named `LoadingSlot` (not `AsyncLoading`) because Riverpod owns
`AsyncLoading` as a sealed-type marker.

## Existing shared widgets — already-canonical

| Widget | Purpose |
|---|---|
| `EdgeScaffold` | Every route's scaffold — edge-to-edge, frosted-glass pills |
| `ContentHeader` | In-content title + subtitle (replaces AppBar — see `in-content-titles`) |
| `EmptyState` | Empty / error / loading-illustration body |
| `DismissGuard` | Confirm-before-discard wrapper for unsaved form state |
| `DestructiveButton` | Red filled button with confirm |
| `PersonAvatar` | Member / subject avatar with initial fallback |
| `CapSwitch` | Capability toggle row (consolidates 3 earlier duplicates) |
| `FloatingActions` / `FloatingBack` / `FloatingHamburger` | edge-to-edge nav chrome |
| `GlassPill` / `SearchBarPill` | Frosted-glass action pills |

## Don't

- Don't reach for `intl`'s `DateFormat` for a relative-time string —
  use `relativeTimeAgo`. (Reserve `intl` for absolute dates: "May 18,
  2026" etc.)
- Don't roll a new "pick a child" sheet — use `pickSubject`. If you
  need a different entity picker (vehicles / members / etc.), add it
  as a sibling in `lib/shared/widgets/`.
- Don't write `Center(child: CircularProgressIndicator())` inline —
  use `const LoadingSlot()`.
- Don't write `if (spaceId == null) throw StateError(...)` — use
  `viewer.requireSpaceId(action: '…')`.

## Adding a new shared helper

Threshold: **3rd duplicate**. If you're typing the same 5-line block
in a third file, stop and extract it to `lib/shared/`.

Naming: prefer names that read at the call site (`pickSubject(ctx)`
better than `SubjectPickerSheet.show(ctx)`).
