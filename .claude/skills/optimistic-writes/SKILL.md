---
name: optimistic-writes
description: User-facing handlers commit locally and return; never await network round-trips. Triggered when writing onTap / onPressed / save handlers.
---

# Optimistic writes only

A user tap should commit to local SQLite in one frame. PowerSync uploads
in the background. The UI reflects the change immediately.

## Right

```dart
Future<void> save() async {
  // Local commit — fast, offline-tolerant.
  await db.updateGroup(id: id, name: name);
  if (!mounted) return;
  Navigator.of(context).pop();
}
```

The user sees the result in the next frame. Sync happens whenever.

## Wrong

```dart
Future<void> save() async {
  // Blocking on Supabase round-trip — slow online, breaks offline.
  await Supabase.instance.client.from('groups').update(...).eq('id', id);
  if (!mounted) return;
  Navigator.of(context).pop();
}
```

## Handling failures

If PowerSync's upload eventually fails (RLS rejection, schema mismatch),
that's the place to surface a non-blocking banner — *not* the user
handler. The local write stays put. See CLAUDE.md "Offline-first
behavior" for the full pattern.
