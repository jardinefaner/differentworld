import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// Stream of Groups in the signed-in Member's current Space.
/// Stays in `loading` until the DB is open AND the Member's space_id is set.
final groupsProvider = StreamProvider<List<Group>>((ref) async* {
  final member = ref.watch(currentMemberProvider).value;
  final spaceId = member?.spaceId;
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
