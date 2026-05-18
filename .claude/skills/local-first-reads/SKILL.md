---
name: local-first-reads
description: Never query Supabase directly from UI / providers / repositories. UI always reads from Drift streams. Triggered when proposing a supabase.from(...).select() call.
---

# Local-first reads, always

Local SQLite is the source of truth for the UI. Drift streams are the
read path. PowerSync handles the round-trip in the background.

## Right

```dart
// In a provider:
final groupsProvider = StreamProvider<List<Group>>((ref) async* {
  final db = await ref.watch(appDatabaseProvider.future);
  yield* db.watchGroupsInSpace(spaceId);
});

// In a widget:
final groups = ref.watch(groupsProvider).value;
```

## Wrong

```dart
// Bypasses PowerSync, blocks the UI on network, fails offline.
final rows = await Supabase.instance.client
    .from('groups')
    .select()
    .eq('space_id', spaceId);
```

## Legitimate exceptions

There are exactly **three** places we go direct to Supabase, and they're
all documented in CLAUDE.md's architecture invariants:

1. **Auth** — `supabase.auth.signInWithOAuth(...)` (PowerSync doesn't
   manage auth)
2. **The PowerSync upload connector** — `lib/core/sync/supabase_connector.dart`
3. **Server-side RPC that must be atomic** — `supabase.rpc('accept_invite', ...)`
   in `lib/features/invites/invites_providers.dart`. Documented at the
   call site.

If you need to add a fourth, justify it in the commit message and add
the carve-out to CLAUDE.md.
