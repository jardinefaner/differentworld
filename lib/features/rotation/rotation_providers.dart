import 'dart:convert';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/rotation/rotation_coverage.dart';
import 'package:differentworld/features/rotation/rotation_engine.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// A cohort's rounds, newest first.
// ignore: specify_nonobvious_property_types
final roundsForGroupProvider = StreamProvider.autoDispose
    .family<List<RotationRound>, String>((ref, groupId) async* {
      final db = await ref.watch(appDatabaseProvider.future);
      yield* db.rotationDao.watchForGroup(groupId);
    });

/// Who has been with whom, rebuilt by folding the stored rounds.
///
/// The history is DERIVED rather than stored separately, so an undo (delete
/// the round) genuinely removes its contribution — there is no second table
/// to fall out of step, and no orphan to clean up.
// ignore: specify_nonobvious_property_types
final rotationHistoryProvider = Provider.autoDispose
    .family<RotationHistory, String>((ref, groupId) {
      final rounds =
          ref.watch(roundsForGroupProvider(groupId)).value ??
          const <RotationRound>[];
      var history = const RotationHistory();
      // Oldest first, so round numbers fold in ascending order.
      for (final r in rounds.reversed) {
        final groups = _decodeGroups(r.groups);
        history = history.recording(
          RotationResult(
            groups: groups,
            satOut: _decodeIds(r.satOut),
            newPairs: r.newPairs,
            repeats: const [],
            seed: 0,
          ),
          r.roundNo,
        );
      }
      return history;
    });

/// Coverage for a cohort: who has still never worked with whom.
// ignore: specify_nonobvious_property_types
final coverageForGroupProvider = Provider.autoDispose
    .family<RotationCoverage, String>((ref, groupId) {
      final roster =
          ref.watch(subjectsInGroupProvider(groupId)).value ??
          const <Subject>[];
      final history = ref.watch(rotationHistoryProvider(groupId));
      return computeCoverage([for (final s in roster) s.id], history);
    });

List<List<String>> _decodeGroups(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return [
      for (final g in decoded)
        if (g is List) [for (final id in g) '$id'],
    ];
  } on FormatException {
    return const [];
  }
}

List<String> _decodeIds(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return [for (final id in decoded) '$id'];
  } on FormatException {
    return const [];
  }
}

class RotationActions {
  const RotationActions(this._ref);

  final Ref _ref;

  /// Store an arrangement. The round number comes from `max + 1`, never a
  /// count — see RotationDao.nextRoundNo.
  Future<void> keep({
    required String groupId,
    required RotationResult result,
    required SplitMode mode,
    required int n,
    required RemainderPolicy remainder,
  }) async {
    final viewer = _ref.read(viewerProvider);
    final spaceId = viewer.spaceId;
    if (spaceId == null) return;
    final db = await _ref.read(appDatabaseProvider.future);
    final now = DateTime.now().toIso8601String();
    await db.rotationDao.create(
      RotationRoundsCompanion.insert(
        id: const Uuid().v4(),
        spaceId: spaceId,
        groupId: groupId,
        roundNo: await db.rotationDao.nextRoundNo(groupId),
        mode: mode.name,
        n: n,
        remainder: remainder.name,
        groups: jsonEncode(result.groups),
        satOut: jsonEncode(result.satOut),
        seed: '${result.seed}',
        newPairs: result.newPairs,
        repeatPairs: result.repeatPairs,
        createdBy: Value(viewer.memberId),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> undo(String roundId) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.rotationDao.delete_(roundId);
  }
}

final Provider<RotationActions> rotationActionsProvider =
    Provider<RotationActions>(RotationActions.new);
