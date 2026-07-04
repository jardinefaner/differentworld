import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reactive list of every classroom a specific member is assigned to.
/// Empty for unassigned non-directors; not used for directors (they
/// see all rooms regardless).
// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final assignmentsForMemberProvider = StreamProvider.autoDispose
    .family<List<GroupMember>, String>(
      (ref, memberId) async* {
        final db = await ref.watch(appDatabaseProvider.future);
        yield* db.groupMembersDao.watchForMember(memberId);
      },
    );

/// Reactive list of every member assigned to a classroom. Used by
/// the Group detail screen's staff section.
// ignore: specify_nonobvious_property_types
final assignmentsForGroupProvider = StreamProvider.autoDispose
    .family<List<GroupMember>, String>(
      (ref, groupId) async* {
        final db = await ref.watch(appDatabaseProvider.future);
        yield* db.groupMembersDao.watchForGroup(groupId);
      },
    );

class GroupAssignmentActions {
  GroupAssignmentActions(this._ref);

  final Ref _ref;

  Future<void> assign({
    required String groupId,
    required String memberId,
  }) async {
    final db = await _ref.read(appDatabaseProvider.future);
    final spaceId = _ref.read(currentMemberProvider).value?.spaceId;
    if (spaceId == null) {
      throw StateError('No Space — sign in and join a program first.');
    }
    await db.groupMembersDao.assign(
      groupId: groupId,
      memberId: memberId,
      spaceId: spaceId,
    );
  }

  Future<void> unassign({
    required String groupId,
    required String memberId,
  }) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.groupMembersDao.unassign(groupId: groupId, memberId: memberId);
  }
}

final groupAssignmentActionsProvider = Provider<GroupAssignmentActions>(
  GroupAssignmentActions.new,
);
