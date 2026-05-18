---
name: sync-status-indicator
description: The only place online/offline state is exposed to the user. Include in the actions pill on every primary screen. Triggered when adding a top-of-screen action set.
---

# SyncStatusIndicator in the actions pill

`lib/core/sync/sync_status_indicator.dart`. The only place the user sees
online/offline state. Everywhere else, the app behaves the same online
or offline (per CLAUDE.md offline-first contract).

## Use

```dart
import 'package:differentworld/core/sync/sync_status_indicator.dart';

EdgeScaffold(
  actions: const [
    SyncStatusIndicator(),
    // ... other actions
  ],
  body: ...,
)
```

It's a small icon that adapts:
- Cloud-checkmark when synced
- Spinning indicator during a cycle
- Cloud-off when offline / no session
- Error icon when uploads are failing

## Where to put it

Screens that show synced data:
- Today
- Group detail
- Attendance
- Morning checklist
- Team
- Member detail

Skip on:
- Login (no session yet)
- JoinOrCreateScreen (boundary state)
- Form sheets (transient)

## Don't

- Don't surface offline state inline ("You're offline, can't save")
  — the app SHOULD save and queue. CLAUDE.md spec.
- Don't add per-screen sync banners ("Syncing 5 rows…") — the
  indicator's job
- Don't gate user actions on the sync state. All writes are optimistic.
