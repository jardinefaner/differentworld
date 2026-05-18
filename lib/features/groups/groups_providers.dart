import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';

/// Stream of Groups the signed-in Member can see.
///
/// Director: every group in the space.
/// Non-director: only groups they're assigned to via group_members.
///
/// The composition is two Drift streams (groups + assignments) joined
/// with `combineLatest`; both update reactively, so re-assigning a
/// staffer flips their visible classroom list in real time.
final groupsProvider = StreamProvider<List<Group>>((ref) async* {
  final viewer = ref.watch(viewerProvider);
  final spaceId = viewer.spaceId;
  final memberId = viewer.memberId;
  if (spaceId == null || memberId == null) return;

  final db = await ref.watch(appDatabaseProvider.future);
  final allGroups = db.watchGroupsInSpace(spaceId);

  if (viewer.seesAllClassrooms) {
    yield* allGroups;
    return;
  }

  final assignments = db.watchAssignmentsForMember(memberId);
  yield* Rx.combineLatest2<List<Group>, List<GroupMember>, List<Group>>(
    allGroups,
    assignments,
    (groups, my) {
      final ids = my.map((a) => a.groupId).toSet();
      return groups.where((g) => ids.contains(g.id)).toList();
    },
  );
});

/// Every group in the space, ignoring assignment — used by the
/// "Assign to classroom" picker on the Member detail screen (a director
/// needs to see all rooms when assigning a staffer).
final allGroupsInSpaceProvider = StreamProvider<List<Group>>((ref) async* {
  final spaceId = ref.watch(currentMemberProvider).value?.spaceId;
  if (spaceId == null) return;
  final db = await ref.watch(appDatabaseProvider.future);
  yield* db.watchGroupsInSpace(spaceId);
});

class GroupActions {
  GroupActions(this._ref);

  final Ref _ref;
  static const _uuid = Uuid();

  Future<void> create({
    required String name,
    String? ageRange,
    String? color,
    String? capabilitiesJson,
  }) async {
    final db = await _ref.read(appDatabaseProvider.future);
    final member = _ref.read(currentMemberProvider).value;
    final spaceId = member?.spaceId;
    if (spaceId == null) {
      throw StateError('No Space selected for the current Member.');
    }
    await db.createGroup(
      id: _uuid.v4(),
      spaceId: spaceId,
      name: name,
      ageRange: ageRange,
      color: color,
      capabilitiesJson: capabilitiesJson ?? '{}',
    );
  }

  Future<void> update({
    required String id,
    String? name,
    String? ageRange,
    String? color,
    String? capabilitiesJson,
  }) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.updateGroup(
      id: id,
      name: name,
      ageRange: ageRange,
      color: color,
      capabilitiesJson: capabilitiesJson,
    );
  }

  Future<void> delete(String id) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.deleteGroup(id);
  }
}

/// Long-lived singleton. Intentionally not `autoDispose` — Actions hold a
/// `Ref` and are reused for the life of the app.
final groupActionsProvider = Provider<GroupActions>(GroupActions.new);
