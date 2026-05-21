---
name: offline-first
description: The four-rule contract that makes the app's offline behavior work — local reads, optimistic writes, no direct Supabase calls from UI / providers / repositories, no awaits on network round-trips in user-facing handlers. Triggered whenever proposing a `supabase.from(...)` call or an async handler that could touch the network.
---

# Offline-first — four rules, one contract

The app's offline-first model rests on four interlocking rules. They
used to be four separate skills (`local-first-reads` +
`no-direct-supabase` + `optimistic-writes` +
`never-await-network-handler`); they're consolidated here because
they're all enforcing the same architectural decision from
different angles. If you only learn one of them, you'll violate the
others by accident.

## Rule 1 — Reads come from Drift streams

The UI never queries Supabase for reads. Drift watches local SQLite;
PowerSync syncs in the background; the UI subscribes to Drift.

```dart
// Right — provider watches a Drift stream
final groupsProvider = StreamProvider<List<Group>>((ref) async* {
  final db = await ref.watch(appDatabaseProvider.future);
  yield* db.groupsDao.watchInSpace(spaceId);
});

// Right — widget watches the provider
final groups = ref.watch(groupsProvider).value ?? const <Group>[];
```

```dart
// Wrong — bypasses PowerSync, blocks on network, fails offline
final rows = await Supabase.instance.client.from('groups').select();
```

## Rule 2 — Writes happen locally; PowerSync uploads later

A user tap commits to local SQLite in one frame. PowerSync queues
the row for upload. The UI shows the change immediately. If the
upload fails (RLS rejection, schema mismatch), surface via a
non-blocking banner — the local write stays put.

```dart
// Right — Drift mutation; PowerSync's CRUD queue picks it up
await db.groupsDao.update_(id: id, name: name);
```

```dart
// Wrong — calls Supabase directly; not offline-tolerant; PowerSync
// has no knowledge of this row
await Supabase.instance.client
    .from('groups').update({'name': name}).eq('id', id);
```

## Rule 3 — Never `Supabase.instance.client.from(...)` from UI / providers / repositories

This is rule 1 + rule 2 stated as a hard rule. The ONLY places that
talk to Supabase tables are the documented exceptions below.

### The three legit exceptions

1. **Auth** — `Supabase.instance.client.auth.signInWithOAuth(...)`.
   PowerSync doesn't manage auth; sign-in HAS to talk to Supabase
   directly.
2. **The PowerSync upload connector** —
   `lib/core/sync/supabase_connector.dart` is the ONE place that
   does `supabase.from(...).upsert(...)`. PowerSync's CRUD queue
   calls into here when it drains queued writes.
3. **Specific RPCs** — `supabase.rpc('accept_invite', ...)` and
   similar transactional server functions that wouldn't make sense
   to mirror locally. Document these one by one.

Storage uploads/downloads are also exceptions (see `photo-via-storage`
skill) — Storage is not a synced data-row path; bytes go to / from
private buckets directly.

## Rule 4 — Never `await` a network round-trip in a user-facing handler

`onPressed`, `onTap`, `onSubmitted`, form `_save` methods — these
should resolve in one frame. The `await` you write should be on a
LOCAL SQLite write or a microtask, not a network call.

```dart
// Right — single local await; UI updates next frame
void onTapSave() async {
  await db.entriesDao.create(...);
  if (!mounted) return;
  Navigator.of(context).pop();
}
```

```dart
// Wrong — UI blocks on Supabase's round-trip; offline kills the flow
void onTapSave() async {
  await Supabase.instance.client.from('entries').insert(...);
  if (!mounted) return;
  Navigator.of(context).pop();
}
```

The exception: photo uploads through `PhotoService` ARE awaited (the
flow needs the storage path back before the row commits), but the
mic-permission / WebSocket / etc. flows defer to the background.

## Why these rules together

Each rule reinforces the others. Drop any one:

- Drop rule 1 → UI fetches from Supabase → blocks on network →
  offline experience breaks
- Drop rule 2 → writes go straight to Supabase → PowerSync's local
  cache doesn't see them → other devices stay out of sync
- Drop rule 3 → some screens query directly, others go through
  Drift → inconsistent offline behavior, weird state
- Drop rule 4 → handlers await network → UI feels slow, fails
  offline mid-tap

The four together give you: every screen works offline, every
write looks instant, every device converges via PowerSync.

## Common violations + how to spot them

- A `Supabase.instance.client.from(...)` call OUTSIDE
  `supabase_connector.dart`, `auth_providers.dart`, or the few
  `.rpc(...)` callers — `rg "supabase.from\("` should be a tight
  list.
- A provider that does `await supabase.from(...).select()` instead
  of `yield* db.someDao.watch...()`.
- An `onPressed` that does `await api.uploadSomething()` instead of
  Drift mutator + return.

## Implementation pointers

- Drift streams + DAOs: `lib/core/db/dao/*.dart` — one DAO per
  feature, mutators live there
- Supabase exceptions: `lib/core/sync/supabase_connector.dart`,
  `lib/core/auth/auth_providers.dart`, `lib/features/invites/invites_providers.dart`
  (the `accept_invite` RPC)
- Sync architecture: CLAUDE.md → "Architecture invariants" (rules
  1 + 2 are load-bearing); `architecture` skill
