import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/shared/viewer_x.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// Filter shape for [capturesProvider]. `open` is the daily inbox
/// view; `all` includes discarded + promoted rows and is used by
/// the "show everything" toggle + audit views.
enum CaptureFilter { open, all }

/// All captures matching the given filter in the signed-in user's
/// space, newest first. Empty when no space (signed out /
/// pre-onboarding) — the inbox quietly disappears rather than
/// asserting.
///
/// Family parameter is the filter; the two named accessors
/// [openCapturesProvider] / [allCapturesProvider] are aliases so
/// existing call sites keep working without typing the family key.
// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final capturesProvider = StreamProvider.autoDispose
    .family<List<Capture>, CaptureFilter>((ref, filter) async* {
  final viewer = ref.watch(viewerProvider);
  final spaceId = viewer.spaceId;
  if (spaceId == null) {
    yield const <Capture>[];
    return;
  }
  final db = await ref.watch(appDatabaseProvider.future);
  yield* switch (filter) {
    CaptureFilter.open => db.capturesDao.watchOpen(spaceId),
    CaptureFilter.all => db.capturesDao.watchAll(spaceId),
  };
});

/// Open captures only. Drives the inbox + Today launchpad badge.
// ignore: specify_nonobvious_property_types
final openCapturesProvider = capturesProvider(CaptureFilter.open);

/// All captures (any status). Drives the "show everything" toggle
/// + future audit views.
// ignore: specify_nonobvious_property_types
final allCapturesProvider = capturesProvider(CaptureFilter.all);

/// Mutations on the capture inbox. The sheet UI calls `start` once on
/// first non-empty keystroke and `updateBody` thereafter (debounced),
/// so each open-sheet creates at most one row. `discardEmpty` lets the
/// sheet hard-delete a row whose body never had content (no audit
/// value).
class CaptureActions {
  CaptureActions(this._ref);

  final Ref _ref;
  final Uuid _uuid = const Uuid();

  /// Begins a new capture and returns its id. The body can be empty —
  /// later keystrokes go through [updateBody] using the returned id.
  Future<String> start({String body = ''}) async {
    final viewer = _ref.read(viewerProvider);
    final spaceId = viewer.requireSpaceId(action: 'capture');
    final db = await _ref.read(appDatabaseProvider.future);
    return db.capturesDao.insert(
      id: _uuid.v4(),
      spaceId: spaceId,
      authorId: viewer.memberId,
      body: body,
    );
  }

  Future<void> updateBody({
    required String id,
    required String body,
  }) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.capturesDao.updateBody(id: id, body: body);
  }

  /// The sheet calls this when the user backs out without ever typing
  /// anything meaningful. Hard-deletes — no audit value in keeping
  /// empty rows.
  Future<void> discardEmpty(String id) async {
    final db = await _ref.read(appDatabaseProvider.future);
    final row = await db.capturesDao.findById(id);
    if (row == null) return;
    if (row.body.trim().isNotEmpty) return; // somebody re-edited; leave it
    await db.capturesDao.deleteById(id);
  }

  /// Promote a capture to a standalone observation on a chosen subject.
  /// Both writes (create entry + mark capture promoted) run inside a
  /// single Drift transaction so a mid-flight failure leaves no
  /// orphan entry and no half-flipped capture. Blast-radius flagged
  /// the previous "atomic-ish" two-write path 2026-05-22.
  Future<String> promoteToObservation({
    required String captureId,
    required String subjectId,
    String kind = 'observation',
  }) async {
    final viewer = _ref.read(viewerProvider);
    final (:spaceId, :memberId) =
        viewer.requireSpaceAndMember(action: 'promote a capture');
    final db = await _ref.read(appDatabaseProvider.future);
    // Read the source rows outside the transaction — they're read-only
    // and not part of the atomicity contract. Pulling the subject's
    // group so the new entry shows up in the per-classroom observation
    // feeds too.
    final cap = await db.capturesDao.findById(captureId);
    if (cap == null) {
      throw StateError('Capture $captureId not found.');
    }
    final subj = await db.subjectsDao.findById(subjectId);
    final entryId = _uuid.v4();
    await db.transaction(() async {
      await db.entriesDao.create(
        id: entryId,
        spaceId: spaceId,
        kind: kind,
        recordedBy: memberId,
        groupId: subj?.groupId,
        subjectId: subjectId,
        body: cap.body,
      );
      // Carry forward any photos snapped onto the capture so they land
      // on the new observation instead of being orphaned. Same txn as
      // markPromoted → the reparent commits atomically with the promote.
      await db.attachmentsDao.reparent(
        oldKind: 'capture',
        oldId: captureId,
        newKind: 'entry',
        newId: entryId,
      );
      await db.capturesDao.markPromoted(
        id: captureId,
        promotedToKind: 'entry',
        promotedToId: entryId,
        promotedSubjectId: subjectId,
      );
    });
    return entryId;
  }

  /// Promote a capture to a standalone task. Subject is optional —
  /// the user can attach the task to a kid or leave it program-level.
  /// Both writes (create task + mark capture promoted) run inside a
  /// single Drift transaction; same atomicity guarantee as
  /// promoteToObservation.
  Future<String> promoteToTask({
    required String captureId,
    String? subjectId,
    String? dueAt,
  }) async {
    final viewer = _ref.read(viewerProvider);
    final spaceId =
        viewer.requireSpaceId(action: 'promote a capture to a task');
    final db = await _ref.read(appDatabaseProvider.future);
    final cap = await db.capturesDao.findById(captureId);
    if (cap == null) {
      throw StateError('Capture $captureId not found.');
    }
    final taskId = _uuid.v4();
    await db.transaction(() async {
      await db.tasksDao.insert(
        id: taskId,
        spaceId: spaceId,
        body: cap.body,
        authorId: viewer.memberId,
        subjectId: subjectId,
        dueAt: dueAt,
        createdFromCaptureId: captureId,
      );
      // Tasks don't render photos today, but a photo snapped onto the
      // capture must not be orphaned. Reparent onto the task row
      // (entityKind 'task') so the bytes stay referenced — if a task
      // photo surface lands later it picks them up for free, and until
      // then they're still reachable via the attachment row. Same txn
      // as markPromoted so it commits atomically.
      await db.attachmentsDao.reparent(
        oldKind: 'capture',
        oldId: captureId,
        newKind: 'task',
        newId: taskId,
      );
      await db.capturesDao.markPromoted(
        id: captureId,
        promotedToKind: 'task',
        promotedToId: taskId,
        promotedSubjectId: subjectId,
      );
    });
    return taskId;
  }

  /// Explicit "not going to act on this" — keeps the row for audit but
  /// hides it from the inbox.
  Future<void> discard(String captureId) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.capturesDao.markDiscarded(captureId);
  }

  /// Rewind: pull a promoted / discarded capture back into the inbox.
  /// Not wired into v1 UI but worth having so the audit trail is
  /// correctable from a debug surface.
  Future<void> reopen(String captureId) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.capturesDao.reopen(captureId);
  }
}

final captureActionsProvider = Provider<CaptureActions>(CaptureActions.new);
