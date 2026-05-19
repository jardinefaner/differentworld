import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/photos/attachments_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';

/// Kind discriminators for the unified `entries` table.
class EntryKind {
  static const String observation = 'observation';
  static const String meal = 'meal';
  static const String nap = 'nap';
  static const String diaper = 'diaper';
  static const String incident = 'incident';
  static const String medication = 'medication';
}

typedef GroupEntriesKey = ({String groupId, String kind});

/// Stream of entries for a classroom, filtered by kind. Used by the
/// per-classroom observations / meals / naps screens.
// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final entriesForGroupProvider =
    StreamProvider.autoDispose.family<List<Entry>, GroupEntriesKey>(
  (ref, key) async* {
    final db = await ref.watch(appDatabaseProvider.future);
    yield* db.watchEntriesForGroup(groupId: key.groupId, kind: key.kind);
  },
);

/// Every observation in the signed-in user's program, scoped to what
/// the viewer can see (director: all; teacher: only entries in
/// classrooms they're assigned to). Newest first.
///
/// The non-director path joins two Drift streams (entries + my
/// assignments) directly via `Rx.combineLatest2` rather than going
/// through `groupsProvider` — Riverpod 3 removed `.stream` so
/// composing provider streams is no longer the easy path. Raw Drift
/// streams stay reactive the same way.
final observationsInSpaceProvider =
    StreamProvider<List<Entry>>((ref) async* {
  final viewer = ref.watch(viewerProvider);
  final spaceId = viewer.spaceId;
  final memberId = viewer.memberId;
  if (spaceId == null) {
    yield const [];
    return;
  }
  final db = await ref.watch(appDatabaseProvider.future);
  final entries = db.watchEntriesInSpace(
    spaceId: spaceId,
    kind: EntryKind.observation,
  );
  if (viewer.seesAllClassrooms || memberId == null) {
    yield* entries;
    return;
  }
  final assignments = db.groupMembersDao.watchForMember(memberId);
  yield* Rx.combineLatest2<List<Entry>, List<GroupMember>, List<Entry>>(
    entries,
    assignments,
    (entryList, assigns) {
      final ids = assigns.map((a) => a.groupId).toSet();
      return entryList
          .where((e) => e.groupId == null || ids.contains(e.groupId))
          .toList(growable: false);
    },
  );
});

typedef SubjectEntriesKey = ({String subjectId, String? kind});

// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final entriesForSubjectProvider =
    StreamProvider.autoDispose.family<List<Entry>, SubjectEntriesKey>(
  (ref, key) async* {
    final db = await ref.watch(appDatabaseProvider.future);
    yield* db.watchEntriesForSubject(
      subjectId: key.subjectId,
      kind: key.kind,
    );
  },
);

class EntryActions {
  EntryActions(this._ref);

  final Ref _ref;
  static const _uuid = Uuid();

  /// Create an observation. Returns the new entry's id. If [id] is
  /// supplied the caller controls it (so pre-uploaded photo paths
  /// already point at the right entry); otherwise a new uuid is
  /// generated inside.
  ///
  /// Photos are persisted as separate `attachments` rows (entity_kind:
  /// 'entry'), in the order they appear in [photoUrls]. Per
  /// UX_DECISIONS §8 the entry row no longer carries photo URLs
  /// directly; attachments are first-class.
  Future<String> createObservation({
    required String subjectId,
    required String groupId,
    required String text,
    List<String> photoUrls = const [],
    String? id,
  }) async {
    final entryId = await _create(
      kind: EntryKind.observation,
      subjectId: subjectId,
      groupId: groupId,
      body: text,
      id: id,
    );
    if (photoUrls.isNotEmpty) {
      final attachments = _ref.read(attachmentActionsProvider);
      var sort = 0;
      for (final url in photoUrls) {
        await attachments.add(
          entityKind: 'entry',
          entityId: entryId,
          url: url,
          sortOrder: sort++,
        );
      }
    }
    return entryId;
  }

  Future<String> _create({
    required String kind,
    String? subjectId,
    String? groupId,
    String? body,
    String? id,
  }) async {
    final db = await _ref.read(appDatabaseProvider.future);
    final member = _ref.read(currentMemberProvider).value;
    final spaceId = member?.spaceId;
    final recordedBy = member?.id;
    if (spaceId == null || recordedBy == null) {
      throw StateError('No Space / signed-in Member.');
    }
    final useId = id ?? _uuid.v4();
    await db.createEntry(
      id: useId,
      spaceId: spaceId,
      kind: kind,
      recordedBy: recordedBy,
      subjectId: subjectId,
      groupId: groupId,
      body: body,
    );
    return useId;
  }

  /// Update an existing entry's text. Photo changes go through
  /// [AttachmentActions]; this method does not touch attachments.
  /// The observation form computes a diff against the existing
  /// attachment list and adds / removes rows directly.
  Future<void> updateText({
    required String id,
    required String text,
  }) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.updateEntry(id: id, body: text);
  }

  Future<void> delete(String id) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.deleteEntry(id);
  }
}

final entryActionsProvider = Provider<EntryActions>(EntryActions.new);
