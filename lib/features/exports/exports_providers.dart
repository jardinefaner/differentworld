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

/// Minimal record carrying just what the Family Today "Recent
/// reports" card needs to render + open a PDF. We don't reconstruct
/// the full Drift `Export` here because (a) PowerSync's `by_space`
/// doesn't reach guardian devices — see DAO comment in
/// `lib/core/db/dao/exports_dao.dart` — and (b) the card only reads
/// id / sent_at / subject_id / storage_path / my read_at. Direct
/// PostgREST round-trip every time, gated by RLS on
/// `export_recipients`.
///
/// `myReadAt` (Wave 42, Devon persona) is the signed-in guardian's
/// own recipient row's `read_at` — null until they tap to open the
/// PDF, ISO-8601 timestamp after. Drives the "Seen" badge on the
/// card so a parent can tell what they've already read. Co-parent
/// visibility ("Also seen by Lauren") needs a sibling-recipient
/// fetch — deferred to a follow-up wave once we settle the
/// multi-recipient PostgREST query shape.
typedef ReceivedExport = ({
  String id,
  String? subjectId,
  String? sentAt,
  String? storagePath,
  String? myReadAt,
});

/// Every progress report the current GuardianViewer is a recipient
/// on — the Family Today "Recent reports" card. **Direct PostgREST**:
/// the local Drift mirror is empty for guardians because they have a
/// `members.space_id = null` row (handle_new_user trigger), so the
/// `by_space` sync stream's `space_id IN (...)` subquery yields NULL
/// and PowerSync delivers no `exports` / `export_recipients` rows.
///
/// RLS on `export_recipients` already gates by recipient identity
/// (guardian linked to the signed-in user), so the SELECT below
/// returns only this guardian's rows even though the query has no
/// `space_id` filter.
///
/// Always empty for staff viewers — the family lens never renders
/// for them anyway. Capped at 10 rows to keep the round-trip tight;
/// the card itself only shows the first three.
///
/// Closes the last Tier-B item from the 2026-05-23 persona-audit —
/// Lauren / Devon / Helen / Marcus finally see what the director
/// has sent them inside the app instead of only via email.
// ignore: specify_nonobvious_property_types
final myReceivedExportsProvider =
    FutureProvider.autoDispose<List<ReceivedExport>>((ref) async {
  final viewer = ref.watch(viewerProvider);
  if (viewer is! GuardianViewer) {
    return const <ReceivedExport>[];
  }
  final supabase = Supabase.instance.client;
  // PostgREST `!inner` filters on a related table while still
  // selecting the parent. The nested column filter ensures the join
  // is gated by the recipient row's guardian_id — exactly the rows
  // RLS would have permitted anyway, but the explicit filter keeps
  // the planner happy and the response small. We also select
  // `read_at` off the inner row to drive the "Seen" badge.
  final rows = await supabase
      .from('exports')
      .select('id, subject_id, sent_at, storage_path, '
          'export_recipients!inner(guardian_id, read_at)')
      .eq('export_recipients.guardian_id', viewer.guardian.id)
      .eq('status', 'sent')
      .order('sent_at', ascending: false)
      .limit(10);
  return [
    for (final r in rows)
      (
        id: r['id'] as String,
        subjectId: r['subject_id'] as String?,
        sentAt: r['sent_at'] as String?,
        storagePath: r['storage_path'] as String?,
        // `export_recipients` is returned as a list (one element after
        // the !inner filter on my guardian_id); read_at lives on that
        // row. Null if the guardian hasn't opened it yet.
        myReadAt: () {
          final recipients = r['export_recipients'];
          if (recipients is List && recipients.isNotEmpty) {
            final first = recipients.first;
            if (first is Map) return first['read_at'] as String?;
          }
          return null;
        }(),
      ),
  ];
});

/// Stamp the signed-in guardian's `read_at` on an export. Called from
/// the Family Today received-reports card the moment the parent taps
/// to open the PDF — the "Seen" state is owned by them, not the
/// server-side delivery pipeline. Idempotent; safe to call from a tap
/// handler without checking the current state first.
///
/// Sibling recipients' rows aren't touched; that's intentional
/// (co-parent visibility is a separate signal).
Future<void> markReceivedExportRead({
  required String exportId,
  required String guardianId,
}) async {
  final supabase = Supabase.instance.client;
  await supabase
      .from('export_recipients')
      .update({'read_at': DateTime.now().toUtc().toIso8601String()})
      .eq('guardian_id', guardianId)
      .eq('export_id', exportId);
}

/// One export's recipient list (for an audit detail view).
// ignore: specify_nonobvious_property_types
final exportRecipientsProvider =
    StreamProvider.autoDispose.family<List<ExportRecipient>, String>(
  (ref, exportId) async* {
    final db = await ref.watch(appDatabaseProvider.future);
    yield* db.exportsDao.watchRecipientsFor(exportId);
  },
);

/// Recipient kind for `export_recipients.kind`.
class ExportRecipientKind {
  static const String guardian = 'guardian';
}

/// All the writes that touch the `exports` table + the Storage
/// bucket. Storage upload is one of the few places this app talks
/// to Supabase directly — see `offline-first` skill, which lists
/// binary-media uploads as a documented exception.
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

  /// Generate a longer-lived shareable URL — same kind of signed
  /// link, just minted with a 7-day expiry by default. UI labels this
  /// as the "Copy link" affordance for parents who don't have email
  /// or for asynchronous channels.
  Future<String?> shareableLink(String exportId,
      {int expiresInSeconds = 7 * 24 * 60 * 60}) {
    return downloadUrl(exportId, expiresInSeconds: expiresInSeconds);
  }

  /// Dispatch an export to one or more email addresses via the
  /// `send-export` Edge Function. The function authenticates as the
  /// caller (RLS gates access), mints a signed download URL, fans
  /// out to Resend, and stamps `export_recipients` server-side with
  /// the actual delivered/failed state.
  ///
  /// Returns the list of (email, ok) pairs so the UI can surface
  /// per-recipient failures.
  Future<List<({String email, bool ok})>> sendByEmail({
    required String exportId,
    required List<({
      String email,
      String? label,
      String? guardianId,
      String kind, // 'guardian' | 'member' | 'external'
    })> recipients,
  }) async {
    final supabase = Supabase.instance.client;
    try {
      final resp = await supabase.functions.invoke(
        'send-export',
        body: {
          'exportId': exportId,
          'recipients': [
            for (final r in recipients)
              {
                'email': r.email,
                if (r.label != null) 'label': r.label,
                if (r.guardianId != null) 'guardianId': r.guardianId,
                'kind': r.kind,
              },
          ],
        },
      );
      final results = (resp.data as Map?)?['results'] as List? ?? const [];
      return [
        for (final raw in results)
          () {
            final r = raw as Map;
            final recipient = (r['recipient'] as Map?) ?? const {};
            return (
              email: (recipient['email'] as String?) ?? '',
              ok: (r['ok'] as bool?) ?? false,
            );
          }(),
      ];
    } on FunctionException catch (e) {
      // The function returns 401 + `{ code: 'JWT_INVALID' }` when
      // the caller's JWT can't be validated — happens during a
      // Supabase JWT-key rotation while the standby key hasn't
      // propagated, or after the old key has been revoked while
      // the client still holds a token signed with it. We surface
      // a typed `SessionExpiredException` so the UI can show a
      // clear "sign out + back in" path.
      if (e.status == 401) {
        final details = e.details;
        if (details is Map && details['code'] == 'JWT_INVALID') {
          throw SessionExpiredException(
            details['error']?.toString() ??
                'auth invalid; please sign out and sign back in',
          );
        }
      }
      rethrow;
    }
  }
}

/// Thrown by long-running surfaces (export send, …) when the
/// Supabase Edge Function reports `JWT_INVALID`. Happens during JWT-
/// key rotation windows and after the old key is revoked. UI catches
/// this specifically and prompts the user to sign out + back in;
/// other `FunctionException`s remain generic.
class SessionExpiredException implements Exception {
  SessionExpiredException(this.message);
  final String message;

  @override
  String toString() => 'SessionExpiredException: $message';
}

String _contentTypeFor(String format) => switch (format) {
      'pdf' => 'application/pdf',
      'csv' => 'text/csv',
      _ => 'application/octet-stream',
    };

final exportActionsProvider =
    Provider<ExportActions>(ExportActions.new);
