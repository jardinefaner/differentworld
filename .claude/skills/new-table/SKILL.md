---
name: new-table
description: The 6-place checklist for adding a new synced table. Triggered when adding a new entity that needs to live in Drift + sync to Supabase.
---

# /new-table — the 6-place sync checklist

Miss any and the table silently doesn't sync. Order matters.

## 1. Migration SQL

`supabase/migrations/YYYYMMDDHHMMSS_create_<name>.sql`:

```sql
create table if not exists public.foos (
  id          uuid primary key default gen_random_uuid(),  -- ALWAYS present
  space_id    uuid not null references public.spaces(id) on delete cascade,
  -- ... your columns
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
-- For JOIN tables: do NOT use a composite primary key. Always an `id`
-- PK + a UNIQUE on the natural pair, or PowerSync's implicit `id`
-- collides with Drift inserts and crashes with SQLite code 1811.
-- See CLAUDE.md "PowerSync join tables still need an explicit `id`".

-- Required for PowerSync to capture replica updates.
alter table public.foos replica identity full;

-- RLS — use the relaxed `to authenticated using (true) with check (true)`
-- pattern until auth.uid() works (see CLAUDE.md gotcha).
alter table public.foos enable row level security;
create policy "foos_authenticated_all" on public.foos
  for all to authenticated
  using (true) with check (true);

-- For PowerSync change capture.
alter publication powersync add table public.foos;
```

Push with `/push-db`.

## 2. Sync rules

`supabase/sync_rules.yaml` — add a line under `by_space.queries`:

```yaml
- SELECT * FROM foos WHERE space_id IN (SELECT space_id FROM members WHERE id = auth.user_id())
```

**Then PASTE the full file into the PowerSync dashboard and click
Deploy.** This is the step everyone forgets and the symptom is
"Validated and applied checkpoint with 0 rows downloaded forever."

## 3. PowerSync local schema

`lib/core/db/power_sync_schema.dart`:

```dart
Table('foos', [
  Column.text('space_id'),
  // ... your columns
  Column.text('created_at'),
  Column.text('updated_at'),
]),
```

Don't declare `id` — PowerSync adds it. All types are TEXT/INTEGER/REAL
(no jsonb, no timestamptz — those become text).

## 4. Drift class

`lib/core/db/app_database.dart` — add the Table class only (mutators
go in the DAO, step 5):

```dart
class Foos extends Table {
  TextColumn get id => text()();
  TextColumn get spaceId => text()();
  // ... your columns
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [..., Foos],          // add to the table list
  daos: [..., FoosDao],         // add to the DAO list (next step)
)
```

## 5. DAO (mutators + readers)

`lib/core/db/dao/foos_dao.dart` — see `split-dao` for the full
template. The bones:

```dart
import 'package:differentworld/core/db/app_database.dart';
import 'package:drift/drift.dart';

part 'foos_dao.g.dart';

@DriftAccessor(tables: [Foos])
class FoosDao extends DatabaseAccessor<AppDatabase>
    with _$FoosDaoMixin {
  FoosDao(super.attachedDatabase);

  Stream<List<Foo>> watchInSpace(String spaceId) {
    return (select(foos)
          ..where((f) => f.spaceId.equals(spaceId))
          ..orderBy([(f) => OrderingTerm(expression: f.createdAt)]))
        .watch();
  }

  Future<Foo?> findById(String id) {
    return (select(foos)..where((f) => f.id.equals(id))).getSingleOrNull();
  }

  Future<void> create({required String id, required String spaceId, …}) async {
    // …
  }
}
```

Run `/regen`.

## 6. Local DB wipe

Tell the user to **uninstall + reinstall on every active device**
(`/wipe-pixel`) so PowerSync recreates the local schema from scratch.

## After all 6

Add a Riverpod provider that wraps the DAO stream
(`StreamProvider.autoDispose.family<…>`). See `new-provider`. Reads go
through `db.foosDao.watchX`; writes through `ref.read(fooActionsProvider).…`.
