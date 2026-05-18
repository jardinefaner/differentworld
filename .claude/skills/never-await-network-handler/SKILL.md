---
name: never-await-network-handler
description: User-facing handlers never await a network round-trip. Local commit + return; network happens in the background. Triggered when writing onTap / onPressed handlers that touch the network.
---

# Never await a network round-trip in a user handler

A user tap should resolve in one frame. Network latency is invisible to
the local-first model — until you accidentally `await` it in the
handler.

## Right

```dart
Future<void> _save() async {
  // Drift mutation: writes to local SQLite, PowerSync queues for upload.
  await db.updateGroup(id: id, name: name);
  if (!mounted) return;
  Navigator.of(context).pop();
}
```

The `await` here is on a local SQLite write — sub-millisecond.

## Wrong

```dart
Future<void> _save() async {
  // Round-trip to Supabase before we can show the next frame.
  await Supabase.instance.client.from('groups').update(...).eq('id', id);
  if (!mounted) return;
  Navigator.of(context).pop();
}
```

Slow online, broken offline.

## Legit awaited Futures in a handler

- Drift writes (`db.foo()`)
- Riverpod `.future` reads of FutureProviders
- Image picker (`ImagePicker().pickImage`)
- Compress (offload to `Isolate.run`)
- Supabase Storage upload (this one IS network-bound; users expect a
  spinner — but show it BEFORE you `await`)

The dividing line: anything tagged "user-facing" in the call site. The
inner sync layer (`SupabaseConnector.uploadData`) awaits network
constantly; that's fine because it doesn't block a user tap.

## Pair with

- `optimistic-writes` (the broader rule)
- `mounted-after-await` (every await is still a disposal risk)
