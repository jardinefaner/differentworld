import 'package:differentworld/core/db/app_database.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

part 'activity_supplies_dao.g.dart';

/// The activity ↔ supplies pack-list join (docs/SUPPLIES.md). An activity
/// declares the supplies it needs; this is the link the editor writes and
/// the pack-list views read.
@DriftAccessor(tables: [ActivitySupplies])
class ActivitySuppliesDao extends DatabaseAccessor<AppDatabase>
    with _$ActivitySuppliesDaoMixin {
  ActivitySuppliesDao(super.attachedDatabase);

  static const _uuid = Uuid();

  /// The supply links for one activity.
  Stream<List<ActivitySupply>> watchForActivity(String activityId) {
    return (select(
      activitySupplies,
    )..where((r) => r.activityId.equals(activityId))).watch();
  }

  /// All links in the space (for a day/program-wide pack-list rollup).
  Stream<List<ActivitySupply>> watchInSpace(String spaceId) {
    return (select(
      activitySupplies,
    )..where((r) => r.spaceId.equals(spaceId))).watch();
  }

  /// Replace the whole set of links for [activityId] with [picks]
  /// (`supplyId` → optional `quantity`), in one transaction. Idempotent —
  /// the editor calls this on every save.
  Future<void> replaceForActivity({
    required String activityId,
    required String spaceId,
    required List<({String supplyId, double? quantity})> picks,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await transaction(() async {
      await (delete(
        activitySupplies,
      )..where((r) => r.activityId.equals(activityId))).go();
      for (final p in picks) {
        await into(activitySupplies).insert(
          ActivitySuppliesCompanion.insert(
            id: _uuid.v4(),
            spaceId: spaceId,
            activityId: activityId,
            supplyId: p.supplyId,
            quantity: Value(p.quantity),
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    });
  }
}
