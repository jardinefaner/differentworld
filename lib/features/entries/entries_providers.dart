import 'dart:convert';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/photos/attachments_providers.dart';
import 'package:differentworld/shared/viewer_x.dart';
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

  /// A mission completion — the room/kid did a real job (docs/MISSIONS.md).
  /// `details` carries {missionId, missionName, builds, stepsDone,
  /// stepsTotal}; feeds the track record + the growth book.
  static const String mission = 'mission';

  /// A pickup / dismissal — the child was released to an authorized
  /// person (docs/WORKFLOWS.md gap #2, the Pickup board). `body` holds
  /// who they were released to; `details` may carry {guardian_id}. A
  /// SEPARATE axis from attendance: releasing never mutates the day's
  /// attendance status (attendance = "did they come"; departure =
  /// "have they left").
  static const String departure = 'departure';
}

typedef GroupEntriesKey = ({String groupId, String kind});

/// Stream of entries for a classroom, filtered by kind. Used by the
/// per-classroom observations / meals / naps screens.
// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final entriesForGroupProvider = StreamProvider.autoDispose
    .family<List<Entry>, GroupEntriesKey>(
      (ref, key) async* {
        final db = await ref.watch(appDatabaseProvider.future);
        yield* db.entriesDao.watchForGroup(
          groupId: key.groupId,
          kind: key.kind,
        );
      },
    );

/// Moments (entries of any kind) tied to one schedule block, newest first.
/// Drives the live strip's ⊕ N counter and the block's moment sheet
/// (live-block Slice 2). See docs/LIVE_BLOCK_CONTEXT.md.
// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final momentsForBlockProvider = StreamProvider.autoDispose
    .family<List<Entry>, String>(
      (ref, blockId) async* {
        final db = await ref.watch(appDatabaseProvider.future);
        yield* db.entriesDao.watchForBlock(scheduleBlockId: blockId);
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
final observationsInSpaceProvider = StreamProvider<List<Entry>>((ref) async* {
  final viewer = ref.watch(viewerProvider);
  final spaceId = viewer.spaceId;
  final memberId = viewer.memberId;
  if (spaceId == null) {
    yield const [];
    return;
  }
  final db = await ref.watch(appDatabaseProvider.future);
  final entries = db.entriesDao.watchInSpace(
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
final entriesForSubjectProvider = StreamProvider.autoDispose
    .family<List<Entry>, SubjectEntriesKey>(
      (ref, key) async* {
        final db = await ref.watch(appDatabaseProvider.future);
        yield* db.entriesDao.watchForSubject(
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
  ///
  /// [photoIds] (aligned by index with [photoUrls]) lets the caller pin each
  /// attachment's id. REQUIRED for offline correctness when a url is a
  /// `pending:` token: the bytes were uploaded via
  /// `uploadOnly(entityKind:'attachment', entityId:<this id>)`, and the queue
  /// patches the deferred upload via `updateUrl(<this id>)` — so the
  /// attachment row MUST carry that same id or the photo is silently lost.
  /// When empty (text-only callers / no offline photos) ids are random.
  Future<String> createObservation({
    required String subjectId,
    required String groupId,
    required String text,
    List<String> photoUrls = const [],
    List<String> photoIds = const [],
    String? scheduleBlockId,
    String? id,
  }) async {
    final entryId = await _create(
      kind: EntryKind.observation,
      subjectId: subjectId,
      groupId: groupId,
      body: text,
      scheduleBlockId: scheduleBlockId,
      id: id,
    );
    if (photoUrls.isNotEmpty) {
      final attachments = _ref.read(attachmentActionsProvider);
      for (var i = 0; i < photoUrls.length; i++) {
        await attachments.add(
          id: i < photoIds.length ? photoIds[i] : null,
          entityKind: 'entry',
          entityId: entryId,
          url: photoUrls[i],
          sortOrder: i,
        );
      }
    }
    return entryId;
  }

  /// Create a structured incident (docs/WORKFLOWS.md gap #3). The
  /// narrative goes in [text]; the structured fields ride in `details`
  /// JSON ({incident_type, action_taken?, parent_notified}). Reuses the
  /// `entries` table — `kind='incident'` — so there's no new data layer.
  /// A separate first-class kind from observations: incidents are a
  /// compliance record, filtered + exported on their own axis.
  Future<String> createIncident({
    required String subjectId,
    required String text,
    required String incidentType,
    String? groupId,
    String? actionTaken,
    String? familyNote,
    bool parentNotified = false,
    String? id,
  }) async {
    // Shape kept in sync with `incidentDetailsJson` in incidents_providers
    // (a leaf encoder there can't be imported here — that'd cycle).
    final details = <String, dynamic>{
      'incident_type': incidentType,
      if (actionTaken != null && actionTaken.trim().isNotEmpty)
        'action_taken': actionTaken.trim(),
      if (familyNote != null && familyNote.trim().isNotEmpty)
        'family_note': familyNote.trim(),
      'parent_notified': parentNotified,
    };
    return _create(
      kind: EntryKind.incident,
      subjectId: subjectId,
      groupId: groupId,
      body: text,
      detailsJson: jsonEncode(details),
      id: id,
    );
  }

  Future<String> _create({
    required String kind,
    String? subjectId,
    String? groupId,
    String? scheduleBlockId,
    String? body,
    String detailsJson = '{}',
    String? id,
  }) async {
    final db = await _ref.read(appDatabaseProvider.future);
    final (:spaceId, :memberId) = _ref
        .read(viewerProvider)
        .requireSpaceAndMember(action: 'create an entry');
    final useId = id ?? _uuid.v4();
    await db.entriesDao.create(
      id: useId,
      spaceId: spaceId,
      kind: kind,
      recordedBy: memberId,
      subjectId: subjectId,
      groupId: groupId,
      scheduleBlockId: scheduleBlockId,
      body: body,
      detailsJson: detailsJson,
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
    await db.entriesDao.updateText(id: id, body: text);
  }

  Future<void> delete(String id) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.entriesDao.deleteById(id);
  }
}

final entryActionsProvider = Provider<EntryActions>(EntryActions.new);
