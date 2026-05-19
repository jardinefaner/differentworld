---
name: split-dao
description: Extract a domain's Drift mutators into a `@DriftAccessor` DAO file. Use when app_database.dart crosses 800 lines, or when a feature's mutators sprawl across the database root.
---

# /split-dao — pull a domain into its own DAO

`app_database.dart` is the codegen root — it owns the `@DriftDatabase`
annotation and is the single class consumers `ref.read(appDatabaseProvider)`
into. As the app grows, its line count balloons because every
feature's mutators live in that one class.

Drift solves this with `@DriftAccessor` — a per-domain class that
holds mutators for a subset of tables, generated alongside the root.

## When to do it

Trigger: `app_database.dart` is over **800 lines** OR a single
domain's mutators are ≥ 150 lines AND the feature has its own folder.

Good candidates (current scale audit, May 2026):
- `subjects` — watch/find/upsert/delete subjects + watchSubjectsInSpace
- `entries` — observation CRUD
- `attendance` — attendance + bulk insert
- `captures` — newest tenant, clean lines
- `vehicles` — vehicles + vehicle_logs
- `surveys` — survey_responses
- `attachments` — attachments
- `certifications` — member_certifications

## Recipe

### 1. Create the DAO file

`lib/core/db/dao/<feature>_dao.dart`:

```dart
import 'package:differentworld/core/db/app_database.dart';
import 'package:drift/drift.dart';

part '<feature>_dao.g.dart';

@DriftAccessor(tables: [Captures])
class CapturesDao extends DatabaseAccessor<AppDatabase>
    with _$CapturesDaoMixin {
  CapturesDao(super.db);

  Stream<List<Capture>> watchOpenCaptures(String spaceId) {
    return (select(captures)
          ..where((c) => c.spaceId.equals(spaceId) & c.status.equals('open'))
          ..orderBy([
            (c) => OrderingTerm.desc(c.createdAt),
          ]))
        .watch();
  }

  // … remaining mutators, copied verbatim from app_database.dart
}
```

### 2. Register on the database

`lib/core/db/app_database.dart`:

```dart
@DriftDatabase(
  tables: [Spaces, Members, /* … */ Captures],
  daos: [CapturesDao],          // ← add here
)
class AppDatabase extends _$AppDatabase {
  // existing code
}
```

### 3. Run codegen

```bash
dart run build_runner build
```

### 4. Remove the methods from `app_database.dart`

Cut every `watchOpenCaptures`, `insertCapture`, etc. from
`app_database.dart` — they now live on the DAO.

### 5. Update callers

Old:
```dart
final db = await ref.read(appDatabaseProvider.future);
await db.insertCapture(...);
```

New:
```dart
final db = await ref.read(appDatabaseProvider.future);
await db.capturesDao.insertCapture(...);   // ← .<dao> accessor
```

Drift auto-generates the `capturesDao` getter on `AppDatabase`.

### 6. Verify

```bash
flutter analyze
flutter test
```

## What stays on `AppDatabase`

- `@DriftDatabase` declaration
- `schemaVersion`
- `MigrationStrategy` (no-op for PowerSync, keep it)
- Constructor
- **Cross-domain mutators** — anything that touches tables from two
  DAOs in one transaction. Leave those on the root.

## Don't

- Don't move the Drift table CLASSES into the DAO file — they stay
  in `app_database.dart` so the codegen can see them. Only the
  **mutator methods** move.
- Don't make a DAO per table — make one per **feature domain**. A
  vehicles DAO owns both `vehicles` and `vehicle_logs`.
- Don't forget the `part '<file>.g.dart'` directive — codegen needs it.
- Don't migrate all DAOs in one commit. One feature at a time, each
  with its own commit, so you can bisect if anything breaks.
