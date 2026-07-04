import 'package:differentworld/core/db/app_database.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

part 'missions_dao.g.dart';

/// Missions catalog (docs/MISSIONS.md) — real jobs with manuals + evidence,
/// per-program + editable. `actions` is stored as a JSON array string;
/// encode/decode lives in the feature layer (mission_templates.dart).
@DriftAccessor(tables: [Missions])
class MissionsDao extends DatabaseAccessor<AppDatabase>
    with _$MissionsDaoMixin {
  MissionsDao(super.attachedDatabase);

  static const _uuid = Uuid();

  /// Active missions in [spaceId], ordered by sort then name.
  Stream<List<Mission>> watchInSpace(String spaceId) {
    return (select(missions)
          ..where((m) => m.spaceId.equals(spaceId) & m.isActive.equals(1))
          ..orderBy([
            (m) => OrderingTerm(expression: m.sort),
            (m) => OrderingTerm(expression: m.name),
          ]))
        .watch();
  }

  Stream<Mission?> watchById(String id) {
    return (select(
      missions,
    )..where((m) => m.id.equals(id))).watchSingleOrNull();
  }

  /// Count for [spaceId] — used to decide whether to offer the starter set.
  Future<int> countInSpace(String spaceId) async {
    final q = selectOnly(missions)
      ..addColumns([missions.id.count()])
      ..where(missions.spaceId.equals(spaceId));
    final row = await q.getSingle();
    return row.read(missions.id.count()) ?? 0;
  }

  Future<String> create({
    required String spaceId,
    required String name,
    String? icon,
    String? tagline,
    String? why,
    String? builds,
    String? rules,
    String? actions,
    String evidenceKind = 'check',
    int? minAge,
    int? maxAge,
    int sort = 0,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await into(missions).insert(
      MissionsCompanion.insert(
        id: id,
        spaceId: spaceId,
        name: name,
        icon: Value(icon),
        tagline: Value(tagline),
        why: Value(why),
        builds: Value(builds),
        rules: Value(rules),
        actions: Value(actions),
        evidenceKind: evidenceKind,
        minAge: Value(minAge),
        maxAge: Value(maxAge),
        isActive: 1,
        sort: sort,
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  /// Insert many at once (the starter-template seed), in a single
  /// transaction. Each row is `(values, sort)` already prepared by the
  /// caller; returns nothing.
  Future<void> createAll(List<MissionsCompanion> rows) async {
    await batch((b) => b.insertAll(missions, rows));
  }

  Future<void> update_({
    required String id,
    String? name,
    String? icon,
    String? tagline,
    String? why,
    String? builds,
    String? rules,
    String? actions,
    String? evidenceKind,
    int? minAge,
    int? maxAge,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(missions)..where((m) => m.id.equals(id))).write(
      MissionsCompanion(
        name: name == null ? const Value.absent() : Value(name),
        icon: icon == null ? const Value.absent() : Value(icon),
        tagline: tagline == null ? const Value.absent() : Value(tagline),
        why: why == null ? const Value.absent() : Value(why),
        builds: builds == null ? const Value.absent() : Value(builds),
        rules: rules == null ? const Value.absent() : Value(rules),
        actions: actions == null ? const Value.absent() : Value(actions),
        evidenceKind: evidenceKind == null
            ? const Value.absent()
            : Value(evidenceKind),
        minAge: minAge == null ? const Value.absent() : Value(minAge),
        maxAge: maxAge == null ? const Value.absent() : Value(maxAge),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> delete_(String id) async {
    await (delete(missions)..where((m) => m.id.equals(id))).go();
  }

  /// Re-insert a previously-deleted mission VERBATIM — the undo path for
  /// `deleteWithUndo`. The mission's checklist rides in its `actions` JSON
  /// column, so a single row carries the whole thing; the stable client UUID
  /// means insert-or-replace re-creates the exact row and PowerSync re-syncs it.
  Future<void> restore(Mission mission) async {
    await into(missions).insertOnConflictUpdate(mission);
  }
}
