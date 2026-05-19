import 'package:differentworld/core/db/app_database.dart';
import 'package:drift/drift.dart';

part 'groups_dao.g.dart';

/// Classrooms — the per-space grouping for kids and staff assignment.
@DriftAccessor(tables: [Groups])
class GroupsDao extends DatabaseAccessor<AppDatabase>
    with _$GroupsDaoMixin {
  GroupsDao(super.attachedDatabase);

  Stream<List<Group>> watchInSpace(String spaceId) {
    return (select(groups)
          ..where((g) => g.spaceId.equals(spaceId))
          ..orderBy([(g) => OrderingTerm(expression: g.name)]))
        .watch();
  }

  Stream<Group?> watchById(String id) {
    return (select(groups)..where((g) => g.id.equals(id)))
        .watchSingleOrNull();
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

  Future<void> deleteById(String id) async {
    await (delete(groups)..where((g) => g.id.equals(id))).go();
  }
}
