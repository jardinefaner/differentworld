import 'package:differentworld/core/db/app_database.dart';
import 'package:drift/drift.dart';

part 'spaces_dao.g.dart';

/// The Space (program) table itself. Most space-level concerns live on
/// other tables (members, groups, etc.); this DAO owns the row that
/// represents the space itself + its capability JSONB.
///
/// Cross-table operations that touch *both* spaces and members (e.g.
/// `createSpaceForMember`) stay on `AppDatabase` since they require a
/// transaction across two DAOs.
@DriftAccessor(tables: [Spaces])
class SpacesDao extends DatabaseAccessor<AppDatabase>
    with _$SpacesDaoMixin {
  SpacesDao(super.attachedDatabase);

  Stream<Space?> watchById(String id) {
    return (select(spaces)..where((s) => s.id.equals(id)))
        .watchSingleOrNull();
  }

  /// One-shot read by ID. Use this — not a captured widget prop —
  /// when a write needs the latest `capabilities` JSONB to avoid
  /// clobbering concurrent edits to other cap keys.
  Future<Space?> findById(String id) {
    return (select(spaces)..where((s) => s.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> updateCapabilities(String id, String capabilitiesJson) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(spaces)..where((s) => s.id.equals(id))).write(
      SpacesCompanion(
        capabilities: Value(capabilitiesJson),
        updatedAt: Value(now),
      ),
    );
  }
}
