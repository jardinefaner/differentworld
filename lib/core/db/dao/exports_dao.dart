import 'package:differentworld/core/db/app_database.dart';
import 'package:drift/drift.dart';

part 'exports_dao.g.dart';

/// Exports — the audit + snapshot trail for every document the
/// program generates. Bytes live in Supabase Storage at
/// `exports/<id>.<format>`; this DAO owns the metadata rows.
@DriftAccessor(tables: [Exports, ExportRecipients])
class ExportsDao extends DatabaseAccessor<AppDatabase> with _$ExportsDaoMixin {
  ExportsDao(super.attachedDatabase);

  /// All non-archived exports in the space, newest first. Drives
  /// the per-program audit list.
  Stream<List<Export>> watchInSpace(String spaceId) {
    return (select(exports)
          ..where(
            (e) =>
                e.spaceId.equals(spaceId) & e.status.equals('archived').not(),
          )
          ..orderBy([
            (e) => OrderingTerm(
              expression: e.generatedAt,
              mode: OrderingMode.desc,
            ),
          ]))
        .watch();
  }

  /// Every export attached to a specific subject — drives the
  /// "Sent reports" section on subject_detail.
  Stream<List<Export>> watchForSubject(String subjectId) {
    return (select(exports)
          ..where((e) => e.subjectId.equals(subjectId))
          ..orderBy([
            (e) => OrderingTerm(
              expression: e.generatedAt,
              mode: OrderingMode.desc,
            ),
          ]))
        .watch();
  }

  /// Every export this guardian appears on as a recipient. Drives the
  /// staff-side audit lens — "which exports went to this guardian."
  /// Returns rows from the LOCAL Drift mirror, which is populated for
  /// staff via the `by_space` sync stream.
  ///
  /// **Not used by the guardian-side Family Today card.** Guardians'
  /// `members.space_id` is NULL (handle_new_user trigger), so the
  /// `by_space` query `space_id IN (SELECT space_id FROM members
  /// WHERE id = auth.user_id())` evaluates to `space_id IN (NULL)`
  /// which is false — no `exports` or `export_recipients` rows ever
  /// reach a guardian's device. The Family Today `_ReceivedReportsCard`
  /// reads via direct PostgREST instead (see `myReceivedExportsProvider`).
  /// We can switch the family card to this DAO method later once a
  /// `by_guardian` sync stream is added.
  ///
  /// Joins `export_recipients` (one row per recipient) back to
  /// `exports`. Filters to `status = 'sent'` so drafts don't leak;
  /// `sent_at` descending so the most recent report comes first.
  /// External-email-only recipients have `guardian_id IS NULL` and
  /// are excluded.
  Stream<List<Export>> watchReceivedByGuardian(String guardianId) {
    final query =
        select(exports).join([
            innerJoin(
              exportRecipients,
              exportRecipients.exportId.equalsExp(exports.id),
            ),
          ])
          ..where(exportRecipients.guardianId.equals(guardianId))
          ..where(exports.status.equals('sent'))
          ..orderBy([
            OrderingTerm(
              expression: exports.sentAt,
              mode: OrderingMode.desc,
            ),
          ]);
    return query.watch().map(
      (rows) => rows.map((r) => r.readTable(exports)).toList(),
    );
  }

  Future<Export?> findById(String id) {
    return (select(exports)..where((e) => e.id.equals(id))).getSingleOrNull();
  }

  Stream<List<ExportRecipient>> watchRecipientsFor(String exportId) {
    return (select(
      exportRecipients,
    )..where((r) => r.exportId.equals(exportId))).watch();
  }

  /// Create a fresh export row. Returns the id so the caller can
  /// upload bytes to Storage under that key, then call
  /// [markStored] with the path.
  Future<String> insert({
    required String id,
    required String spaceId,
    required String templateId,
    required String templateVersion,
    required String format,
    required String snapshotJson,
    String? authorId,
    String? subjectId,
    String? groupId,
    String? note,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await into(exports).insert(
      ExportsCompanion.insert(
        id: id,
        spaceId: spaceId,
        authorId: Value(authorId),
        templateId: templateId,
        templateVersion: templateVersion,
        subjectId: Value(subjectId),
        groupId: Value(groupId),
        status: 'draft',
        format: format,
        snapshotJson: snapshotJson,
        note: Value(note),
        generatedAt: now,
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  /// Stamp the Storage path once the bytes are uploaded. Stays
  /// 'draft' until the caller explicitly sends.
  Future<void> markStored({
    required String id,
    required String storagePath,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(exports)..where((e) => e.id.equals(id))).write(
      ExportsCompanion(
        storagePath: Value(storagePath),
        updatedAt: Value(now),
      ),
    );
  }

  /// Mark sent. Records the recipient rows in the same transaction
  /// so the audit trail is atomic.
  Future<void> markSent({
    required String id,
    required List<ExportRecipientsCompanion> recipientRows,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await transaction(() async {
      await (update(exports)..where((e) => e.id.equals(id))).write(
        ExportsCompanion(
          status: const Value('sent'),
          sentAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      for (final row in recipientRows) {
        await into(exportRecipients).insert(row);
      }
    });
  }

  Future<void> archive(String id) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(exports)..where((e) => e.id.equals(id))).write(
      ExportsCompanion(
        status: const Value('archived'),
        archivedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }
}
