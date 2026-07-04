import 'package:differentworld/core/db/app_database.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

part 'group_members_dao.g.dart';

/// Staff ↔ classroom assignment join. One row per (group, member) pair
/// (the server-side UNIQUE constraint enforces this; we keep our
/// assigns idempotent on the client side too).
@DriftAccessor(tables: [GroupMembers])
class GroupMembersDao extends DatabaseAccessor<AppDatabase>
    with _$GroupMembersDaoMixin {
  GroupMembersDao(super.attachedDatabase);

  /// Assignment rows for a member — used to derive which classrooms
  /// they're scoped to. Directors don't need this; their groupsProvider
  /// returns the full space.
  Stream<List<GroupMember>> watchForMember(String memberId) {
    return (select(
      groupMembers,
    )..where((g) => g.memberId.equals(memberId))).watch();
  }

  /// All members assigned to a classroom. Used by the Group detail
  /// screen's staff list.
  Stream<List<GroupMember>> watchForGroup(String groupId) {
    return (select(
      groupMembers,
    )..where((g) => g.groupId.equals(groupId))).watch();
  }

  /// Idempotent assign. Inserts a row if the (group, member) pair
  /// isn't already there; otherwise no-op.
  Future<void> assign({
    required String groupId,
    required String memberId,
    required String spaceId,
    String? roleInGroup,
  }) async {
    final existing =
        await (select(groupMembers)..where(
              (g) => g.groupId.equals(groupId) & g.memberId.equals(memberId),
            ))
            .getSingleOrNull();
    if (existing != null) return;
    final now = DateTime.now().toUtc().toIso8601String();
    await into(groupMembers).insert(
      GroupMembersCompanion.insert(
        id: const Uuid().v4(),
        groupId: groupId,
        memberId: memberId,
        spaceId: spaceId,
        roleInGroup: roleInGroup == null
            ? const Value.absent()
            : Value(roleInGroup),
        assignedAt: now,
      ),
    );
  }

  /// Idempotent unassign.
  Future<void> unassign({
    required String groupId,
    required String memberId,
  }) async {
    await (delete(groupMembers)..where(
          (g) => g.groupId.equals(groupId) & g.memberId.equals(memberId),
        ))
        .go();
  }
}
