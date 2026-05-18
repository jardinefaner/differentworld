---
name: viewer-lens
description: Read viewerProvider for capability checks in UI. Never compare member.role to a string literal — the role seeds capabilities; the cap is the gate. Triggered when gating UI by who's looking.
---

# Viewer lens — one app, many views

`lib/core/viewer/viewer.dart` exposes a typed `Viewer` over the
signed-in member + current space. Every UI gate goes through it.

The same app shows different surfaces to:
- **Director** — full program management, billing, team, settings
- **Lead teacher** — invite staff, manage their classrooms, all daily
  logs
- **Teacher** — daily logs, view team, no admin
- **Assistant** — narrower daily-log set, no admin
- **Family / guardian** *(future)* — child-scoped view, no staff data
- **Custom** — any combination via capability flags

Roles are presets. Capabilities are the truth. A lead-teacher with
`canActAsDirector = true` gets the director's lens.

## Read it in widgets

```dart
import 'package:differentworld/core/viewer/viewer.dart';

@override
Widget build(BuildContext context, WidgetRef ref) {
  final viewer = ref.watch(viewerProvider);

  return EdgeScaffold(
    actions: [
      if (viewer.canTakeAttendance) IconButton(...),
      if (viewer.canInviteStaff) IconButton(...),
    ],
    floatingActionButton: viewer.canManageProgram ? FAB(...) : null,
    body: ...,
  );
}
```

## Common helpers

| Viewer helper | What it gates |
|---|---|
| `viewer.isDirector` | Composite — role == 'director' OR `canActAsDirector` |
| `viewer.canManageProgram` | Alias for `isDirector` — read intent in screen code |
| `viewer.canInviteStaff` | Team-screen Invite FAB, invite-tile interactivity |
| `viewer.canTakeAttendance` | Attendance icon, Morning Checklist CTA |
| `viewer.canObserve` | Future observations feature |
| `viewer.canViewBilling` | Billing tile in drawer |
| `viewer.isDailyLogger` | OR of attendance / meals / naps / diapers / observations |
| `viewer.canEditMember(other)` | Director can edit anyone; everyone can edit themselves |
| `viewer.featureObservations` | Space-level feature toggle |

For any cap not specifically named, use `viewer.can('cap_string')` or
`viewer.feature('feature_string')`.

## Replace these patterns

```dart
// Wrong
final isDirector = member?.role == 'director';
if (isDirector) ...

// Right
final viewer = ref.watch(viewerProvider);
if (viewer.canManageProgram) ...
```

```dart
// Wrong
if (me?.role != 'director') return;  // defence-in-depth save guard

// Right
if (!ref.read(viewerProvider).canManageProgram) return;
```

## Defence in depth

UI gates are convenience, not security. Every mutation in a provider
also re-checks the viewer:

```dart
Future<void> _save(Member member) async {
  if (!ref.read(viewerProvider).canManageProgram) return;
  // ... actual save
}
```

The real security boundary is server-side RLS (currently relaxed due
to the `auth.uid()` gotcha — see `gotchas`).

## Future extension: family / guardian view

When `feature_family_login` ships, add a `GuardianViewer` subclass and
the same widgets render a child-scoped view. The Drawer becomes
"My child today / Pickup / Messages." The same Today screen filters
to the guardian's children. No fork; same app.

## Don't

- Don't read `member.role` directly in widgets — it's an implementation
  detail of the cap-seeding bundles
- Don't gate by role for things that have a more specific cap
  (e.g. "show Invite FAB if director" → wrong; show if `canInviteStaff`)
- Don't bypass the viewer for a "quick check" — it's free, it's typed,
  it composes
