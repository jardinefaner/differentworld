import 'package:differentworld/core/db/app_database.dart';
import 'package:drift/drift.dart';

part 'groups_dao.g.dart';

/// Classrooms — the per-space grouping for kids and staff assignment.
@DriftAccessor(tables: [Groups])
class GroupsDao extends DatabaseAccessor<AppDatabase> with _$GroupsDaoMixin {
  GroupsDao(super.attachedDatabase);

  Stream<List<Group>> watchInSpace(String spaceId) {
    return (select(groups)
          ..where(
            (g) =>
                g.spaceId.equals(spaceId) &
                (g.status.equals('active') | g.status.isNull()),
          )
          ..orderBy([(g) => OrderingTerm(expression: g.name)]))
        .watch();
  }

  Stream<Group?> watchById(String id) {
    return (select(groups)..where((g) => g.id.equals(id))).watchSingleOrNull();
  }

  Future<void> create({
    required String id,
    required String spaceId,
    required String name,
    String? ageRange,
    String? color,
    String capabilitiesJson = '{}',
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await into(groups).insert(
      GroupsCompanion.insert(
        id: id,
        spaceId: spaceId,
        name: name,
        ageRange: Value(ageRange),
        color: Value(color),
        capabilities: capabilitiesJson,
        // Explicit — the server column is NOT NULL and a default only
        // applies to an OMITTED column, so a local null would fail the
        // insert forever (see SubjectsDao.create for the same trap).
        status: const Value('active'),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> update_({
    required String id,
    String? name,
    String? ageRange,
    String? color,
    String? capabilitiesJson,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(groups)..where((g) => g.id.equals(id))).write(
      GroupsCompanion(
        name: name == null ? const Value.absent() : Value(name),
        ageRange: ageRange == null ? const Value.absent() : Value(ageRange),
        color: color == null ? const Value.absent() : Value(color),
        capabilities: capabilitiesJson == null
            ? const Value.absent()
            : Value(capabilitiesJson),
        updatedAt: Value(now),
      ),
    );
  }

  /// Rooms that have been closed. Reached deliberately, never by accident.
  Stream<List<Group>> watchClosedInSpace(String spaceId) {
    return (select(groups)
          ..where((g) => g.spaceId.equals(spaceId) & g.status.equals('closed'))
          ..orderBy([(g) => OrderingTerm(expression: g.name)]))
        .watch();
  }

  /// Close a room. It keeps its schedule, its arrangements, its staff
  /// assignments and its history — it simply stops appearing in the
  /// surfaces that describe today (docs/ROOMS.md).
  ///
  /// NOT `close()`: that is Drift's own DatabaseConnectionUser.close.
  Future<void> closeRoom(String id, String nowIso) =>
      (update(groups)..where((g) => g.id.equals(id))).write(
        GroupsCompanion(
          status: const Value('closed'),
          updatedAt: Value(nowIso),
        ),
      );

  Future<void> reopenRoom(String id, String nowIso) =>
      (update(groups)..where((g) => g.id.equals(id))).write(
        GroupsCompanion(
          status: const Value('active'),
          updatedAt: Value(nowIso),
        ),
      );

  Future<void> deleteById(String id) async {
    await (delete(groups)..where((g) => g.id.equals(id))).go();
  }
}
