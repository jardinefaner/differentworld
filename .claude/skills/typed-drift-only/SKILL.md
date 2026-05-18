---
name: typed-drift-only
description: Never use db.customStatement for mutations. Always typed Drift APIs so PowerSync's CRUD queue picks up the write. Triggered when writing database mutations.
---

# Typed Drift, not customStatement

PowerSync's CRUD queue captures writes via WAL triggers. Those triggers
fire on the typed query builders (`update(table)...write(...)`,
`into(table).insert(...)`, `delete(table)...go()`). They do **not**
reliably fire on `db.customStatement('UPDATE ...', [...])`.

Symptoms of using `customStatement` for a mutation:
- Local SQLite reflects the change immediately ✓
- PowerSync never uploads to Supabase ✗
- Other devices never see it ✗

This bit us on `members.role` updates in the member detail screen —
we fixed it by adding a typed `updateMemberRole`. Same pattern for
every mutation.

## Right

```dart
await (update(members)..where((m) => m.id.equals(id))).write(
  MembersCompanion(role: Value(role), updatedAt: Value(now)),
);
```

## Wrong

```dart
await db.customStatement(
  'UPDATE members SET role = ?, updated_at = ? WHERE id = ?',
  [role, now, id],
);
```

## When you need a one-off

Add a typed method to `AppDatabase` (`lib/core/db/app_database.dart`)
and call it from your actions provider. The 5 minutes of boilerplate
is the difference between "the write syncs" and "the write silently
disappears."
