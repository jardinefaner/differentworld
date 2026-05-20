import 'package:differentworld/core/db/app_database.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

part 'locations_dao.g.dart';

/// Physical places activities happen — pool, art barn, archery range.
/// Camps build their own location catalog.
@DriftAccessor(tables: [Locations])
class LocationsDao extends DatabaseAccessor<AppDatabase>
    with _$LocationsDaoMixin {
  LocationsDao(super.attachedDatabase);

  static const _uuid = Uuid();

  Stream<List<Location>> watchInSpace(String spaceId) {
    return (select(locations)
          ..where((l) => l.spaceId.equals(spaceId))
          ..orderBy([(l) => OrderingTerm(expression: l.name)]))
        .watch();
  }

  Stream<Location?> watchById(String id) {
    return (select(locations)..where((l) => l.id.equals(id)))
        .watchSingleOrNull();
  }

  Future<String> create({
    required String spaceId,
    required String name,
    String? notes,
    int? capacity,
    bool isOutdoor = false,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await into(locations).insert(
      LocationsCompanion.insert(
        id: id,
        spaceId: spaceId,
        name: name,
        notes: Value(notes),
        capacity: Value(capacity),
        isOutdoor: isOutdoor ? 1 : 0,
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  Future<void> update_({
    required String id,
    String? name,
    String? notes,
    int? capacity,
    bool? isOutdoor,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(locations)..where((l) => l.id.equals(id))).write(
      LocationsCompanion(
        name: name == null ? const Value.absent() : Value(name),
        notes: notes == null ? const Value.absent() : Value(notes),
        capacity: capacity == null ? const Value.absent() : Value(capacity),
        isOutdoor:
            isOutdoor == null ? const Value.absent() : Value(isOutdoor ? 1 : 0),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> delete_(String id) async {
    await (delete(locations)..where((l) => l.id.equals(id))).go();
  }
}
