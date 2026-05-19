import 'dart:convert';
import 'dart:typed_data';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/shared/viewer_x.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// All exports in the signed-in user's space (non-archived).
// ignore: specify_nonobvious_property_types
final exportsInSpaceProvider =
    StreamProvider.autoDispose<List<Export>>((ref) async* {
  final viewer = ref.watch(viewerProvider);
  final spaceId = viewer.spaceId;
  if (spaceId == null) {
    yield const <Export>[];
    return;
  }
  final db = await ref.watch(appDatabaseProvider.future);
  yield* db.exportsDao.watchInSpace(spaceId);
});

/// Exports for a specific subject — the "Sent reports" surface.
// ignore: specify_nonobvious_property_types
final exportsForSubjectProvider =
    StreamProvider.autoDispose.family<List<Export>, String>(
  (ref, subjectId) async* {
    final db = await ref.watch(appDatabaseProvider.future);
    yield* db.exportsDao.watchForSubject(subjectId);
  },
);

/// One export's recipient list (for an audit detail view).
// ignore: specify_nonobvious_property_types
final exportRecipientsProvider =
    StreamProvider.autoDispose.family<List<ExportRecipient>, String>(
  (ref, exportId) async* {
    final db = await ref.watch(appDatabaseProvider.future);
    yield* db.exportsDao.watchRecipientsFor(exportId);
  },
);

/// All the writes that touch the `exports` table + the Storage
/// bucket. Storage upload is one of the few places this app talks
/// to Supabase directly — see `no-direct-supabase` skill, which
/// lists binary-media uploads as a documented exception.
class ExportActions {
  ExportActions(this._ref);

  final Ref _ref;
  final Uuid _uuid = const Uuid();

  /// One-shot: create the row, upload the bytes to Storage, stamp
  /// the path. Returns the created export's id. Status stays
  /// 'draft' until the caller subsequently calls [markSent].
  Future<String> createAndStore({
    required String templateId,
    required String templateVersion,
    required String format,
    required Uint8List bytes,
    required Map<String, dynamic> snapshot,
    String? subjectId,
    String? groupId,
    String? note,
  }) async {
    final viewer = _ref.read(viewerProvider);
    final spaceId =
        viewer.requireSpaceId(action: 'create an export');
    final db = await _ref.read(appDatabaseProvider.future);
    final id = _uuid.v4();

    // 1. Insert the metadata row first so a power-failure mid-upload
    //    still leaves a recoverable record.
    await db.exportsDao.insert(
      id: id,
      spaceId: spaceId,
      templateId: templateId,
      templateVersion: templateVersion,
      format: format,
      snapshotJson: jsonEncode(snapshot),
      authorId: viewer.memberId,
      subjectId: subjectId,
      groupId: groupId,
      note: note,
    );

    // 2. Upload bytes to Storage under <space>/<id>.<format>. We
    //    namespace by space so RLS / signed URLs scope cleanly.
    final supabase = Supabase.instance.client;
    final path = '$spaceId/$id.$format';
    await supabase.storage.from('exports').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: _contentTypeFor(format),
          ),
        );

    // 3. Stamp the path so the row knows where its bytes live.
    await db.exportsDao.markStored(id: id, storagePath: path);
    return id;
  }

  /// Flip status to 'sent' and attach recipient rows. Each
  /// recipient is one of:
  ///   - guardianId set → guardian recipient
  ///   - memberId set → internal member share
  ///   - externalEmail + externalLabel → free-text external recipient
  ///
  /// For the share-sheet "I handed the PDF off and don't track
  /// delivery" path, pass `channel = 'manual'` and `state = 'manual'`
  /// (defaults).
  Future<void> markSent({
    required String exportId,
    required List<({
      String kind,
      String? guardianId,
      String? memberId,
      String? externalLabel,
      String? externalEmail,
      String channel,
    })> recipients,
  }) async {
    final viewer = _ref.read(viewerProvider);
    final spaceId = viewer.requireSpaceId(action: 'send an export');
    final db = await _ref.read(appDatabaseProvider.future);
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = [
      for (final r in recipients)
        ExportRecipientsCompanion.insert(
          id: _uuid.v4(),
          exportId: exportId,
          spaceId: spaceId,
          kind: r.kind,
          guardianId: Value(r.guardianId),
          memberId: Value(r.memberId),
          externalLabel: Value(r.externalLabel),
          externalEmail: Value(r.externalEmail),
          channel: r.channel,
          state: 'manual',
          sentAt: Value(now),
          createdAt: now,
        ),
    ];
    await db.exportsDao.markSent(id: exportId, recipientRows: rows);
  }

  /// Hide an export from the active list (kept for audit).
  Future<void> archive(String exportId) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.exportsDao.archive(exportId);
  }

  /// Generate a short-lived signed URL for the export's bytes.
  /// Returns null if the export has no stored path yet (still a
  /// draft).
  Future<String?> downloadUrl(String exportId,
      {int expiresInSeconds = 600}) async {
    final db = await _ref.read(appDatabaseProvider.future);
    final row = await db.exportsDao.findById(exportId);
    if (row == null || row.storagePath == null) return null;
    final supabase = Supabase.instance.client;
    return supabase.storage
        .from('exports')
        .createSignedUrl(row.storagePath!, expiresInSeconds);
  }
}

String _contentTypeFor(String format) => switch (format) {
      'pdf' => 'application/pdf',
      'csv' => 'text/csv',
      _ => 'application/octet-stream',
    };

final exportActionsProvider =
    Provider<ExportActions>(ExportActions.new);
