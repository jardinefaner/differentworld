import 'package:differentworld/core/db/app_database.dart';
import 'package:drift/drift.dart';

part 'rotation_dao.g.dart';

/// Drift mutators for a cohort's arrangements (docs/ROTATION.md).
///
/// Rounds ARE the pair history — the engine folds `groups` back into a
/// `RotationHistory` — so this DAO is deliberately small: watch a cohort's
/// rounds, append one, delete one (undo).
@DriftAccessor(tables: [RotationRounds])
class RotationDao extends DatabaseAccessor<AppDatabase>
    with _$RotationDaoMixin {
  RotationDao(super.attachedDatabase);

  /// A cohort's rounds, newest first. Matches the local index
  /// `rotation_rounds_group (group_id, round_no DESC)`.
  Stream<List<RotationRound>> watchForGroup(String groupId) {
    return (select(rotationRounds)
          ..where((r) => r.groupId.equals(groupId))
          ..orderBy([
            (r) => OrderingTerm(expression: r.roundNo, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// The most recent round, or null — what the Room shows on open.
  Stream<RotationRound?> watchLatest(String groupId) {
    return (select(rotationRounds)
          ..where((r) => r.groupId.equals(groupId))
          ..orderBy([
            (r) => OrderingTerm(expression: r.roundNo, mode: OrderingMode.desc),
          ])
          ..limit(1))
        .watchSingleOrNull();
  }

  /// The next round number for a cohort.
  ///
  /// Derived from `max(round_no) + 1`, **never from a count** — minting ids
  /// from a count collides straight after an undo (delete round 8, next
  /// shuffle also claims 8) and silently corrupts the history. That bug is
  /// why this is a method and not an inline expression at the call site.
  Future<int> nextRoundNo(String groupId) async {
    final rows =
        await (select(rotationRounds)
              ..where((r) => r.groupId.equals(groupId))
              ..orderBy([
                (r) => OrderingTerm(
                  expression: r.roundNo,
                  mode: OrderingMode.desc,
                ),
              ])
              ..limit(1))
            .get();
    return rows.isEmpty ? 1 : rows.first.roundNo + 1;
  }

  Future<void> create(RotationRoundsCompanion row) =>
      into(rotationRounds).insert(row);

  /// Undo — the round is genuinely gone, and with it its contribution to the
  /// pair history (which is derived, so nothing is left orphaned).
  Future<void> delete_(String id) =>
      (delete(rotationRounds)..where((r) => r.id.equals(id))).go();

  /// Re-insert a deleted round, for undo-the-undo. The client id is stable,
  /// so it re-syncs as the same row.
  Future<void> restore(RotationRound row) =>
      into(rotationRounds).insert(row, mode: InsertMode.insertOrReplace);
}
