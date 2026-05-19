import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/shared/viewer_x.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// All open captures in the signed-in user's space, newest first.
/// Empty when no space (signed out / pre-onboarding) — the inbox
/// quietly disappears rather than asserting.
// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final openCapturesProvider =
    StreamProvider.autoDispose<List<Capture>>((ref) async* {
  final viewer = ref.watch(viewerProvider);
  final spaceId = viewer.spaceId;
  if (spaceId == null) {
    yield const <Capture>[];
    return;
  }
  final db = await ref.watch(appDatabaseProvider.future);
  yield* db.watchOpenCaptures(spaceId);
});

/// Includes discarded + promoted rows. Used by the inbox's "show
/// everything" toggle and any future audit view.
// ignore: specify_nonobvious_property_types
final allCapturesProvider =
    StreamProvider.autoDispose<List<Capture>>((ref) async* {
  final viewer = ref.watch(viewerProvider);
  final spaceId = viewer.spaceId;
  if (spaceId == null) {
    yield const <Capture>[];
    return;
  }
  final db = await ref.watch(appDatabaseProvider.future);
  yield* db.watchAllCaptures(spaceId);
});

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
    return db.insertCapture(
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
    await db.updateCaptureBody(id: id, body: body);
  }

  /// The sheet calls this when the user backs out without ever typing
  /// anything meaningful. Hard-deletes — no audit value in keeping
  /// empty rows.
  Future<void> discardEmpty(String id) async {
    final db = await _ref.read(appDatabaseProvider.future);
    final row = await db.findCaptureById(id);
    if (row == null) return;
    if (row.body.trim().isNotEmpty) return; // somebody re-edited; leave it
    await db.deleteCapture(id);
  }

  /// Promote a capture to a standalone observation on a chosen subject.
  /// Atomic-ish: creates the entry first, then flips the capture's
  /// status. If the entry write succeeds and the status update fails,
  /// the user sees a duplicate entry without the capture being marked
  /// processed — they can re-promote and we'd silently dedupe. Worth
  /// tightening if we ever observe it; until then, the chance is small
  /// (both writes are local and same-DB).
  Future<String> promoteToObservation({
    required String captureId,
    required String subjectId,
    String kind = 'observation',
  }) async {
    final viewer = _ref.read(viewerProvider);
    final (:spaceId, :memberId) =
        viewer.requireSpaceAndMember(action: 'promote a capture');
    final db = await _ref.read(appDatabaseProvider.future);
    final cap = await db.findCaptureById(captureId);
    if (cap == null) {
      throw StateError('Capture $captureId not found.');
    }
    // Pull the subject's group so the new entry shows up in
    // the per-classroom observation feeds too.
    final subj = await db.findSubjectById(subjectId);
    final entryId = _uuid.v4();
    await db.createEntry(
      id: entryId,
      spaceId: spaceId,
      kind: kind,
      recordedBy: memberId,
      groupId: subj?.groupId,
      subjectId: subjectId,
      body: cap.body,
    );
    await db.markCapturePromoted(
      id: captureId,
      promotedToKind: 'entry',
      promotedToId: entryId,
      promotedSubjectId: subjectId,
    );
    return entryId;
  }

  /// Explicit "not going to act on this" — keeps the row for audit but
  /// hides it from the inbox.
  Future<void> discard(String captureId) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.markCaptureDiscarded(captureId);
  }

  /// Rewind: pull a promoted / discarded capture back into the inbox.
  /// Not wired into v1 UI but worth having so the audit trail is
  /// correctable from a debug surface.
  Future<void> reopen(String captureId) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.reopenCapture(captureId);
  }
}

final captureActionsProvider = Provider<CaptureActions>(CaptureActions.new);
