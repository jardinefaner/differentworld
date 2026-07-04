import 'dart:convert';

import 'package:differentworld/core/db/app_database.dart';
import 'package:drift/drift.dart';

part 'messages_dao.g.dart';

/// Staff ↔ guardian thread messages. Thread identity is the
/// (subject_id, guardian_id) pair — no separate threads table.
@DriftAccessor(tables: [Messages])
class MessagesDao extends DatabaseAccessor<AppDatabase>
    with _$MessagesDaoMixin {
  MessagesDao(super.attachedDatabase);

  /// Every message in a thread (subject, guardian), oldest first so
  /// the chat scroll reads naturally.
  Stream<List<Message>> watchThread({
    required String subjectId,
    required String guardianId,
  }) {
    return (select(messages)
          ..where(
            (m) =>
                m.subjectId.equals(subjectId) & m.guardianId.equals(guardianId),
          )
          ..orderBy([(m) => OrderingTerm(expression: m.createdAt)]))
        .watch();
  }

  /// All distinct guardians who have a thread with this subject — for
  /// the staff-side per-kid "Messages" section that lists which
  /// guardians have messaged.
  Stream<List<Message>> watchAllForSubject(String subjectId) {
    return (select(messages)
          ..where((m) => m.subjectId.equals(subjectId))
          ..orderBy([
            (m) => OrderingTerm(
              expression: m.createdAt,
              mode: OrderingMode.desc,
            ),
          ]))
        .watch();
  }

  /// All messages this guardian is on (for the family-side messages
  /// list across multiple children).
  Stream<List<Message>> watchAllForGuardian(String guardianId) {
    return (select(messages)
          ..where((m) => m.guardianId.equals(guardianId))
          ..orderBy([
            (m) => OrderingTerm(
              expression: m.createdAt,
              mode: OrderingMode.desc,
            ),
          ]))
        .watch();
  }

  /// All messages in a space — used to compute per-kid unread badges.
  Stream<List<Message>> watchInSpace(String spaceId) {
    return (select(messages)..where((m) => m.spaceId.equals(spaceId))).watch();
  }

  Future<void> insert({
    required String id,
    required String spaceId,
    required String subjectId,
    required String guardianId,
    required String senderKind,
    required String body,
    String? senderMemberId,
    String? senderGuardianId,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await into(messages).insert(
      MessagesCompanion.insert(
        id: id,
        spaceId: spaceId,
        subjectId: subjectId,
        guardianId: guardianId,
        senderKind: senderKind,
        senderMemberId: Value(senderMemberId),
        senderGuardianId: Value(senderGuardianId),
        body: body,
        createdAt: now,
      ),
    );
  }

  /// Mark unread incoming messages in a thread as read by the
  /// recipient — bulk-update so opening the thread clears every
  /// notification at once. `recipientKind` is the kind of the
  /// _viewer_, not the sender (i.e. staff opening a thread marks
  /// guardian-sent messages read).
  Future<void> markThreadRead({
    required String subjectId,
    required String guardianId,
    required String recipientKind,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final otherKind = recipientKind == 'staff' ? 'guardian' : 'staff';
    await (update(messages)..where(
          (m) =>
              m.subjectId.equals(subjectId) &
              m.guardianId.equals(guardianId) &
              m.senderKind.equals(otherKind) &
              m.readAt.isNull(),
        ))
        .write(MessagesCompanion(readAt: Value(now)));
  }

  /// Mark every staff-authored message in this thread as having
  /// been read by THIS guardian. Devon-persona: divorced parents
  /// share a kid; each guardian opening the thread appends their
  /// id to the message's `readByGuardianIds` list. Staff side then
  /// renders "Seen by both" / "Seen by Mom only" / "Unread" based
  /// on the list size + the thread's known guardian count.
  ///
  /// Idempotent — re-running for the same guardian is a no-op
  /// because we check the list before appending. The JSONB merge
  /// happens server-side; locally we read + JSON-parse + append +
  /// JSON-encode + write.
  Future<void> markThreadReadByGuardian({
    required String subjectId,
    required String guardianId,
  }) async {
    final rows =
        await (select(messages)..where(
              (m) =>
                  m.subjectId.equals(subjectId) &
                  m.guardianId.equals(guardianId) &
                  m.senderKind.equals('staff'),
            ))
            .get();
    final now = DateTime.now().toUtc().toIso8601String();
    for (final row in rows) {
      // Parse existing list, append if missing, write back. raw may be
      // null when the column wasn't populated (older inserts / PowerSync
      // delivers NULL); treat that as an empty list.
      final raw = row.readByGuardianIds ?? '[]';
      final List<dynamic> ids;
      try {
        ids = jsonDecode(raw) as List<dynamic>;
      } on Object {
        // Corrupt — replace.
        await (update(messages)..where((m) => m.id.equals(row.id))).write(
          MessagesCompanion(
            readByGuardianIds: Value(jsonEncode([guardianId])),
            readAt: Value(now),
          ),
        );
        continue;
      }
      if (ids.contains(guardianId)) continue;
      ids.add(guardianId);
      await (update(messages)..where((m) => m.id.equals(row.id))).write(
        MessagesCompanion(
          readByGuardianIds: Value(jsonEncode(ids)),
          // Keep `readAt` as the first-read-by-anybody timestamp.
          readAt: row.readAt == null ? Value(now) : const Value.absent(),
        ),
      );
    }
  }

  Future<void> deleteById(String id) async {
    await (delete(messages)..where((m) => m.id.equals(id))).go();
  }
}
