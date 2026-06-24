---
name: split-dao
description: Add a new domain DAO under lib/core/db/dao/ when a feature's mutators sprawl, OR consult this for the conventions every existing DAO already follows. The per-domain DAO split is done (~58 DAOs) — new domains slot in alongside.
---

# /split-dao — the established DAO pattern

## Status: refactor complete (May 2026)

The original DAO split (May 2026) extracted 15 domains out of
`app_database.dart` — it dropped from 1787 → 434 lines. This skill is
now the canonical *forward* reference: when you add a new domain (or
extend an existing one), follow this pattern.

## Where DAOs live

```
lib/core/db/dao/
  attachments_dao.dart
  attendance_dao.dart
  captures_dao.dart
  certifications_dao.dart
  dismissed_insights_dao.dart
  entries_dao.dart
  group_members_dao.dart
  groups_dao.dart
  guardians_dao.dart
  invites_dao.dart
  members_dao.dart
  spaces_dao.dart
  subjects_dao.dart
  surveys_dao.dart
  vehicles_dao.dart
```

One DAO per **feature domain** (not per table — `VehiclesDao` owns
both vehicles + vehicle_logs, `GuardiansDao` owns guardians +
subject_guardians + reads of subjects).

## DAO file template

```dart
import 'package:differentworld/core/db/app_database.dart';
import 'package:drift/drift.dart';

part 'foo_dao.g.dart';

/// Short doc on the domain and any cross-table concerns.
@DriftAccessor(tables: [Foos])
class FoosDao extends DatabaseAccessor<AppDatabase>
    with _$FoosDaoMixin {
  FoosDao(super.attachedDatabase);

  Stream<List<Foo>> watchInSpace(String spaceId) { ... }
  Future<Foo?> findById(String id) { ... }
  Future<void> create({...}) async { ... }
  Future<void> update_({...}) async { ... }       // ← note the `_`
  Future<void> deleteById(String id) async { ... }
}
```

### Method naming — drop redundant nouns

The noun lives in the accessor (`db.vehiclesDao.X`), so methods are
verb-only at the call site:

| Old (on AppDatabase) | New (on DAO) |
|---|---|
| `db.watchVehiclesInSpace(...)` | `db.vehiclesDao.watchInSpace(...)` |
| `db.findVehicleById(...)` | `db.vehiclesDao.findById(...)` |
| `db.createVehicle(...)` | `db.vehiclesDao.create(...)` |
| `db.updateVehicle(...)` | `db.vehiclesDao.update_(...)` |
| `db.deleteVehicle(...)` | `db.vehiclesDao.deleteById(...)` |

### The `update_` trailing-underscore convention

`DatabaseAccessor` already owns `update(table)` (the statement
builder) — declaring a method named `update` on the DAO would shadow
it and break calls like `update(foos)..where(...)`. The codebase uses
`update_` as the consistent rename when the verb is just "update".
Reads at the call site as `db.foosDao.update_(id: ...)` — slightly
ugly but unambiguous and consistent across all DAOs.

## Registering the DAO

`lib/core/db/app_database.dart`:

```dart
import 'package:differentworld/core/db/dao/foos_dao.dart';

@DriftDatabase(
  tables: [..., Foos],
  daos: [..., FoosDao],   // ← alphabetically sorted
)
class AppDatabase extends _$AppDatabase {
  // existing code
}
```

Drift auto-generates the `db.foosDao` accessor from this declaration.

## What stays on `AppDatabase` (the root)

- Drift Table classes (the schema source of truth for codegen).
- `@DriftDatabase` declaration.
- `schemaVersion` + the no-op `MigrationStrategy` (PowerSync owns the
  schema).
- **Cross-table transactions** — methods that write to tables owned
  by two different DAOs. Today the only one is
  `createSpaceForMember` (INSERTs a spaces row + UPDATEs a members
  row in one transaction). If you add one, document why it's
  cross-domain.

## Adding a new mutator

The standard flow:

1. Identify the right DAO (it should be the one whose primary table
   you're mutating).
2. Add the method to that DAO file.
3. If the method touches a SECOND table for read context (e.g.
   `promoteToObservation` reads from `subjectsDao.findById` before
   writing to `capturesDao.markPromoted`), that's fine — but the
   write itself goes on one DAO.
4. If the method writes to two tables in one transaction, it belongs
   on `AppDatabase` (cross-table). Document why.

## When to add a NEW DAO

You're adding a brand-new synced table (see `new-table`). Default to
its own DAO unless it's a join table whose entire purpose is to glue
two existing entities (e.g. a `subject_tags` table — that joins onto
the SubjectsDao or TagsDao depending on the read patterns).

## Don't

- Don't add new mutators to `AppDatabase` unless they're truly
  cross-table. The root is held under 500 lines on purpose.
- Don't redundant-noun your method names. `db.surveysDao.upsertSurveyResponse`
  reads worse than `db.surveysDao.upsert`.
- Don't try to make a single "GodDao" — one DAO per domain.
- Don't migrate multiple DAOs in one commit. One per commit, so
  bisect works if anything breaks.
