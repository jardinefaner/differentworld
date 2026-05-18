---
name: uuid-clientside
description: Generate row IDs in Dart via const Uuid().v4() before insert. Never let Postgres assign IDs after the fact. Triggered when inserting new rows.
---

# IDs are uuid server-side, text client-side, generated in Dart

Offline writes need stable PKs that survive the eventual sync. Letting
Postgres assign IDs means PowerSync has to rewrite them on upload — and
that's not how PowerSync works.

## Right

```dart
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

await db.createFoo(
  id: _uuid.v4(),
  spaceId: spaceId,
  // ...
);
```

The local row is inserted with its final id. PowerSync uploads the row
with that id. The Supabase migration's `default gen_random_uuid()` is a
fallback for direct inserts that don't pass an id (rare; only via the
SQL editor).

## Wrong

```dart
// Returns the auto-generated id from Postgres — but the local row
// won't have it. Sync confusion.
final response = await Supabase.instance.client
    .from('foos')
    .insert({...}).select().single();
```

## In the Drift mutator

```dart
Future<void> createFoo({
  required String id,
  required String spaceId,
  // ...
}) async {
  await into(foos).insert(FoosCompanion.insert(
    id: id,
    spaceId: spaceId,
    // ...
  ));
}
```

## In the Actions

```dart
Future<void> create({required String name}) async {
  final db = await _ref.read(appDatabaseProvider.future);
  await db.createFoo(
    id: _uuid.v4(),
    spaceId: spaceId,
    name: name,
  );
}
```

## Types

Server-side: `uuid` (with `gen_random_uuid()` as default).
Client-side: `TextColumn get id => text()();` — PowerSync's local
SQLite has only TEXT/INTEGER/REAL.
