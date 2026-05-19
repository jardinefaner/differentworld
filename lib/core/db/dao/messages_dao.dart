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
                m.subjectId.equals(subjectId) &
                m.guardianId.equals(guardianId),
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
    return (select(messages)
          ..where((m) => m.spaceId.equals(spaceId)))
        .watch();
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
    await (update(messages)
          ..where(
            (m) =>
                m.subjectId.equals(subjectId) &
                m.guardianId.equals(guardianId) &
                m.senderKind.equals(otherKind) &
                m.readAt.isNull(),
          ))
        .write(MessagesCompanion(readAt: Value(now)));
  }

  Future<void> deleteById(String id) async {
    await (delete(messages)..where((m) => m.id.equals(id))).go();
  }
}
