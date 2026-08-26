import 'dart:convert';

import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/class_memory/class_memory.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// Everything a room remembers, newest first.
// ignore: specify_nonobvious_property_types
final classMemoriesProvider = StreamProvider.autoDispose
    .family<List<ClassMemory>, String>((ref, groupId) async* {
      final db = await ref.watch(appDatabaseProvider.future);
      yield* db.entriesDao
          .watchForGroup(groupId: groupId, kind: EntryKind.classMemory)
          .map(
            (rows) => [
              for (final r in rows) ?ClassMemory.fromEntry(r),
            ],
          );
    });

/// The room's memories bucketed by sort, every heading present.
// ignore: specify_nonobvious_property_types
final classMemoriesBySortProvider = Provider.autoDispose
    .family<Map<ClassMemorySort, List<ClassMemory>>, String>((ref, groupId) {
      final all =
          ref.watch(classMemoriesProvider(groupId)).value ??
          const <ClassMemory>[];
      return groupBySort(all);
    });

/// The oldest still-open question for this room — what Return offers.
///
/// Null until the room has been going long enough to have one, which is
/// correct: a feature whose whole point is "you asked this before" has
/// nothing to say in week one and should say nothing.
// ignore: specify_nonobvious_property_types
final returnableQuestionProvider = Provider.autoDispose
    .family<ClassMemory?, String>((ref, groupId) {
      final all =
          ref.watch(classMemoriesProvider(groupId)).value ??
          const <ClassMemory>[];
      return oldestOpenQuestion(all);
    });

final classMemoryActionsProvider = Provider<ClassMemoryActions>(
  ClassMemoryActions.new,
);

class ClassMemoryActions {
  ClassMemoryActions(this._ref);

  final Ref _ref;

  /// Keep something for the room. One line of text and which sort it is —
  /// nothing else, because a capture surface that asks for more than the
  /// moment allows is one nobody uses while the moment is happening.
  Future<void> keep({
    required String groupId,
    required ClassMemorySort sort,
    required String text,
    String? context,
  }) async {
    final viewer = _ref.read(viewerProvider);
    final spaceId = viewer.spaceId;
    final memberId = viewer.memberId;
    if (spaceId == null || memberId == null) return;
    final db = await _ref.read(appDatabaseProvider.future);
    await db.entriesDao.create(
      id: const Uuid().v4(),
      spaceId: spaceId,
      kind: EntryKind.classMemory,
      recordedBy: memberId,
      groupId: groupId,
      // subjectId deliberately absent — this belongs to the ROOM.
      body: text.trim(),
      detailsJson: jsonEncode({
        'sort': sort.id,
        if (context != null && context.trim().isNotEmpty)
          'context': context.trim(),
      }),
    );
  }

  /// Remove one. Deleting a memory is rare and always deliberate, so the
  /// caller pairs this with undo rather than a confirm — the row carries a
  /// stable client uuid, so putting it back is a re-insert.
  Future<void> forget(String entryId) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.entriesDao.deleteById(entryId);
  }
}
