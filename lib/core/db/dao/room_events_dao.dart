import 'package:differentworld/core/db/app_database.dart';
import 'package:drift/drift.dart';

part 'room_events_dao.g.dart';

/// Drift mutators for the shared fairness log (docs/ROTATION.md).
///
/// Every Room instrument writes here — picked, spoke first, spoke, points,
/// prompt used — because they all answer one question: who has had their
/// share, and how recently. One store is what lets "pick someone" know that
/// this child already answered twice today.
@DriftAccessor(tables: [RoomEvents])
class RoomEventsDao extends DatabaseAccessor<AppDatabase>
    with _$RoomEventsDaoMixin {
  RoomEventsDao(super.attachedDatabase);

  /// A cohort's events, newest first. Matches the local index
  /// `room_events_group (group_id, occurred_at DESC)`.
  Stream<List<RoomEvent>> watchForGroup(String groupId) {
    return (select(roomEvents)
          ..where((e) => e.groupId.equals(groupId))
          ..orderBy([
            (e) =>
                OrderingTerm(expression: e.occurredAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// One kind only (turn order reads `spoke_first`; the picker reads
  /// `picked`), newest first.
  Stream<List<RoomEvent>> watchKind(String groupId, String kind) {
    return (select(roomEvents)
          ..where((e) => e.groupId.equals(groupId) & e.kind.equals(kind))
          ..orderBy([
            (e) =>
                OrderingTerm(expression: e.occurredAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Future<void> create(RoomEventsCompanion row) => into(roomEvents).insert(row);

  Future<void> delete_(String id) =>
      (delete(roomEvents)..where((e) => e.id.equals(id))).go();

  Future<void> restore(RoomEvent row) =>
      into(roomEvents).insert(row, mode: InsertMode.insertOrReplace);
}
