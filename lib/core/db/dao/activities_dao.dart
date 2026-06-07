import 'package:differentworld/core/db/app_database.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

part 'activities_dao.g.dart';

/// Activities — what kids do during scheduled blocks. Owned by the
/// staff member who created them. Active by default; soft-archived
/// (not deleted) when discontinued so historical schedule rows still
/// resolve their activity name.
@DriftAccessor(tables: [Activities])
class ActivitiesDao extends DatabaseAccessor<AppDatabase>
    with _$ActivitiesDaoMixin {
  ActivitiesDao(super.attachedDatabase);

  static const _uuid = Uuid();

  Stream<List<Activity>> watchActiveInSpace(String spaceId) {
    return (select(activities)
          ..where((a) =>
              a.spaceId.equals(spaceId) & a.archivedAt.isNull())
          ..orderBy([(a) => OrderingTerm(expression: a.name)]))
        .watch();
  }

  /// All activities, including archived. The scheduler uses this when
  /// editing a historical block (so it can still show the archived
  /// activity's name).
  Stream<List<Activity>> watchAllInSpace(String spaceId) {
    return (select(activities)
          ..where((a) => a.spaceId.equals(spaceId))
          ..orderBy([(a) => OrderingTerm(expression: a.name)]))
        .watch();
  }

  Stream<Activity?> watchById(String id) {
    return (select(activities)..where((a) => a.id.equals(id)))
        .watchSingleOrNull();
  }

  Future<String> create({
    required String spaceId,
    required String name,
    String? ownerMemberId,
    String? description,
    String? defaultLocationId,
    int? defaultDurationMinutes,
    String? supplies,
    int? ageMin,
    int? ageMax,
    int? maxCapacity,
    bool isOutdoor = false,
    String? indoorAltActivityId,
    String capabilitiesJson = '{}',
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await into(activities).insert(
      ActivitiesCompanion.insert(
        id: id,
        spaceId: spaceId,
        ownerMemberId: Value(ownerMemberId),
        name: name,
        description: Value(description),
        defaultLocationId: Value(defaultLocationId),
        defaultDurationMinutes: Value(defaultDurationMinutes),
        supplies: Value(supplies),
        ageMin: Value(ageMin),
        ageMax: Value(ageMax),
        maxCapacity: Value(maxCapacity),
        isOutdoor: isOutdoor ? 1 : 0,
        indoorAltActivityId: Value(indoorAltActivityId),
        capabilities: capabilitiesJson,
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  Future<void> update_({
    required String id,
    String? name,
    String? description,
    String? ownerMemberId,
    String? defaultLocationId,
    int? defaultDurationMinutes,
    String? supplies,
    int? ageMin,
    int? ageMax,
    int? maxCapacity,
    bool? isOutdoor,
    String? indoorAltActivityId,
    String? capabilitiesJson,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(activities)..where((a) => a.id.equals(id))).write(
      ActivitiesCompanion(
        capabilities: capabilitiesJson == null
            ? const Value.absent()
            : Value(capabilitiesJson),
        name: name == null ? const Value.absent() : Value(name),
        description:
            description == null ? const Value.absent() : Value(description),
        ownerMemberId: ownerMemberId == null
            ? const Value.absent()
            : Value(ownerMemberId),
        defaultLocationId: defaultLocationId == null
            ? const Value.absent()
            : Value(defaultLocationId),
        defaultDurationMinutes: defaultDurationMinutes == null
            ? const Value.absent()
            : Value(defaultDurationMinutes),
        supplies: supplies == null ? const Value.absent() : Value(supplies),
        ageMin: ageMin == null ? const Value.absent() : Value(ageMin),
        ageMax: ageMax == null ? const Value.absent() : Value(ageMax),
        maxCapacity:
            maxCapacity == null ? const Value.absent() : Value(maxCapacity),
        isOutdoor:
            isOutdoor == null ? const Value.absent() : Value(isOutdoor ? 1 : 0),
        indoorAltActivityId: indoorAltActivityId == null
            ? const Value.absent()
            : Value(indoorAltActivityId),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> archive(String id) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(activities)..where((a) => a.id.equals(id))).write(
      ActivitiesCompanion(
        archivedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> unarchive(String id) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(activities)..where((a) => a.id.equals(id))).write(
      ActivitiesCompanion(
        archivedAt: const Value(null),
        updatedAt: Value(now),
      ),
    );
  }
}
