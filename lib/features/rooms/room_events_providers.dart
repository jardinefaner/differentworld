import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/rooms/fair_turns.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// The kinds the shared room log carries (docs/ROTATION.md). Typed rather
/// than sprinkled as literals — every instrument reads what the others
/// write, so a typo would silently split one history into two.
abstract class RoomEventKinds {
  static const picked = 'picked';
  static const spokeFirst = 'spoke_first';
  static const spoke = 'spoke';
  static const points = 'points';
  static const promptUsed = 'prompt_used';
}

/// A cohort's log, newest first.
// ignore: specify_nonobvious_property_types
final roomEventsProvider = StreamProvider.autoDispose
    .family<List<RoomEvent>, String>((ref, groupId) async* {
      final db = await ref.watch(appDatabaseProvider.future);
      yield* db.roomEventsDao.watchForGroup(groupId);
    });

/// How many turns of one kind each child has had.
// ignore: specify_nonobvious_property_types
final turnCountsProvider = Provider.autoDispose
    .family<Map<String, int>, ({String groupId, String kind})>((ref, key) {
      final events =
          ref.watch(roomEventsProvider(key.groupId)).value ??
          const <RoomEvent>[];
      return turnCounts([
        for (final e in events)
          if (e.kind == key.kind && e.subjectId != null) e.subjectId!,
      ]);
    });

/// Seconds spoken per child.
// ignore: specify_nonobvious_property_types
final talkTotalsProvider = Provider.autoDispose
    .family<Map<String, int>, String>(
      (ref, groupId) {
        final events =
            ref.watch(roomEventsProvider(groupId)).value ?? const <RoomEvent>[];
        return talkTotals([
          for (final e in events)
            if (e.kind == RoomEventKinds.spoke && e.subjectId != null)
              (e.subjectId!, e.value),
        ]);
      },
    );

class RoomEventActions {
  const RoomEventActions(this._ref);

  final Ref _ref;

  /// Append to the shared log. Every instrument goes through here so they
  /// all answer the same question — who has had their share, how recently.
  Future<void> record({
    required String groupId,
    required String kind,
    String? subjectId,
    int value = 1,
    String? detail,
  }) async {
    final viewer = _ref.read(viewerProvider);
    final spaceId = viewer.spaceId;
    if (spaceId == null) return;
    final db = await _ref.read(appDatabaseProvider.future);
    final now = DateTime.now().toIso8601String();
    await db.roomEventsDao.create(
      RoomEventsCompanion.insert(
        id: const Uuid().v4(),
        spaceId: spaceId,
        groupId: groupId,
        kind: kind,
        occurredAt: now,
        createdAt: now,
        updatedAt: now,
        subjectId: Value(subjectId),
        value: value,
        detail: Value(detail),
      ),
    );
  }
}

final Provider<RoomEventActions> roomEventActionsProvider =
    Provider<RoomEventActions>(RoomEventActions.new);
