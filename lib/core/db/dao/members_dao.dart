import 'package:differentworld/core/db/app_database.dart';
import 'package:drift/drift.dart';

part 'members_dao.g.dart';

/// Per-member reads + writes. Cross-table operations (e.g.
/// `createSpaceForMember`, `removeMemberFromSpace` which both touch
/// members and another table) stay on `AppDatabase`.
@DriftAccessor(tables: [Members])
class MembersDao extends DatabaseAccessor<AppDatabase>
    with _$MembersDaoMixin {
  MembersDao(super.attachedDatabase);

  Stream<Member?> watchById(String id) {
    return (select(members)..where((m) => m.id.equals(id)))
        .watchSingleOrNull();
  }

  /// One-shot read by ID. Use this — not a captured widget prop —
  /// when a write needs the latest `capabilities` JSONB to avoid
  /// clobbering concurrent edits to other cap keys.
  Future<Member?> findById(String id) {
    return (select(members)..where((m) => m.id.equals(id)))
        .getSingleOrNull();
  }

  Stream<List<Member>> watchInSpace(String spaceId) {
    return (select(members)
          ..where((m) => m.spaceId.equals(spaceId))
          ..orderBy([(m) => OrderingTerm(expression: m.displayName)]))
        .watch();
  }

  Future<void> updateCapabilities(String id, String capabilitiesJson) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(members)..where((m) => m.id.equals(id))).write(
      MembersCompanion(
        capabilities: Value(capabilitiesJson),
        updatedAt: Value(now),
      ),
    );
  }

  /// Updates a member's role using the typed Drift API so PowerSync's
  /// CRUD queue picks it up. Don't use `customStatement` for this —
  /// raw SQL bypasses the WAL triggers PowerSync relies on.
  Future<void> updateRole(String id, String role) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(members)..where((m) => m.id.equals(id))).write(
      MembersCompanion(role: Value(role), updatedAt: Value(now)),
    );
  }

  /// Set or clear the member's avatar_url. Pass null to remove the
  /// photo (the underlying Storage object stays — orphans are cheaper
  /// than risking a delete on a still-referenced path).
  Future<void> updateAvatarUrl(String id, String? url) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(members)..where((m) => m.id.equals(id))).write(
      MembersCompanion(
        avatarUrl: Value(url),
        updatedAt: Value(now),
      ),
    );
  }
}
