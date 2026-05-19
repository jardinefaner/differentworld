import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/shared/viewer_x.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// Thread = (subject, guardian) pair.
typedef MessageThreadKey = ({String subjectId, String guardianId});

/// Stream of messages in a single thread, oldest first.
// ignore: specify_nonobvious_property_types
final messageThreadProvider =
    StreamProvider.autoDispose.family<List<Message>, MessageThreadKey>(
  (ref, key) async* {
    final db = await ref.watch(appDatabaseProvider.future);
    yield* db.messagesDao.watchThread(
      subjectId: key.subjectId,
      guardianId: key.guardianId,
    );
  },
);

/// All messages for a subject (any guardian) — staff side per-kid view.
// ignore: specify_nonobvious_property_types
final messagesForSubjectProvider =
    StreamProvider.autoDispose.family<List<Message>, String>(
  (ref, subjectId) async* {
    final db = await ref.watch(appDatabaseProvider.future);
    yield* db.messagesDao.watchAllForSubject(subjectId);
  },
);

/// All messages this guardian is on, newest first. Empty for staff.
// ignore: specify_nonobvious_property_types
final myGuardianMessagesProvider =
    StreamProvider.autoDispose<List<Message>>((ref) async* {
  final viewer = ref.watch(viewerProvider);
  if (viewer is! GuardianViewer) {
    yield const <Message>[];
    return;
  }
  final db = await ref.watch(appDatabaseProvider.future);
  yield* db.messagesDao.watchAllForGuardian(viewer.guardian.id);
});

/// Unread count for the current viewer. For staff, counts unread
/// guardian-sent messages in their space. For a guardian, counts
/// unread staff-sent messages addressed to them.
final unreadMessagesCountProvider = Provider<int>((ref) {
  final viewer = ref.watch(viewerProvider);
  if (viewer is GuardianViewer) {
    final all = ref.watch(myGuardianMessagesProvider).value ??
        const <Message>[];
    return all
        .where((m) => m.senderKind == 'staff' && m.readAt == null)
        .length;
  }
  final spaceId = viewer.spaceId;
  if (spaceId == null) return 0;
  final allAsync = ref.watch(_messagesInSpaceProvider(spaceId));
  final all = allAsync.value ?? const <Message>[];
  return all
      .where((m) => m.senderKind == 'guardian' && m.readAt == null)
      .length;
});

// Private — only used for the unread-count derivation above.
// ignore: specify_nonobvious_property_types
final _messagesInSpaceProvider =
    StreamProvider.autoDispose.family<List<Message>, String>(
  (ref, spaceId) async* {
    final db = await ref.watch(appDatabaseProvider.future);
    yield* db.messagesDao.watchInSpace(spaceId);
  },
);

class MessageActions {
  MessageActions(this._ref);

  final Ref _ref;
  final Uuid _uuid = const Uuid();

  /// Send a new message. The caller passes (subjectId, guardianId);
  /// the sender side is derived from the current viewer.
  Future<void> send({
    required String subjectId,
    required String guardianId,
    required String body,
  }) async {
    final viewer = _ref.read(viewerProvider);
    final spaceId = viewer.requireSpaceId(action: 'send a message');
    final db = await _ref.read(appDatabaseProvider.future);
    final isGuardian = viewer is GuardianViewer;
    await db.messagesDao.insert(
      id: _uuid.v4(),
      spaceId: spaceId,
      subjectId: subjectId,
      guardianId: guardianId,
      senderKind: isGuardian ? 'guardian' : 'staff',
      senderMemberId: isGuardian ? null : viewer.memberId,
      senderGuardianId: isGuardian ? viewer.guardian.id : null,
      body: body,
    );
  }

  /// Marks all unread messages in a thread as read by the current
  /// viewer. Call when the thread is opened.
  Future<void> markThreadRead({
    required String subjectId,
    required String guardianId,
  }) async {
    final viewer = _ref.read(viewerProvider);
    final db = await _ref.read(appDatabaseProvider.future);
    final recipientKind = viewer is GuardianViewer ? 'guardian' : 'staff';
    await db.messagesDao.markThreadRead(
      subjectId: subjectId,
      guardianId: guardianId,
      recipientKind: recipientKind,
    );
  }
}

final messageActionsProvider =
    Provider<MessageActions>(MessageActions.new);
