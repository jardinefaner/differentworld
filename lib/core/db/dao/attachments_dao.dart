import 'package:differentworld/core/db/app_database.dart';
import 'package:drift/drift.dart';

part 'attachments_dao.g.dart';

/// Polymorphic attachments — photos / PDFs / future audio attached to
/// any entity via (entity_kind, entity_id).
///
/// `entityKind` is a string discriminator: 'entry' | 'subject' |
/// 'member' | 'vehicle' | 'certification' | future kinds.
@DriftAccessor(tables: [Attachments])
class AttachmentsDao extends DatabaseAccessor<AppDatabase>
    with _$AttachmentsDaoMixin {
  AttachmentsDao(super.attachedDatabase);

  /// Every attachment for a given entity, ordered by sort_order (nulls
  /// last) then created_at. Used by photo grids on observation / cert
  /// / future galleries.
  Stream<List<Attachment>> watchFor({
    required String entityKind,
    required String entityId,
  }) {
    return (select(attachments)
          ..where(
            (a) =>
                a.entityKind.equals(entityKind) &
                a.entityId.equals(entityId),
          )
          ..orderBy([
            (a) => OrderingTerm(expression: a.sortOrder),
            (a) => OrderingTerm(expression: a.createdAt),
          ]))
        .watch();
  }

  /// One-shot read of attachments for an entity. Used by writers that
  /// need the latest list to compute a new sort_order.
  Future<List<Attachment>> findFor({
    required String entityKind,
    required String entityId,
  }) {
    return (select(attachments)
          ..where(
            (a) =>
                a.entityKind.equals(entityKind) &
                a.entityId.equals(entityId),
          )
          ..orderBy([
            (a) => OrderingTerm(expression: a.sortOrder),
            (a) => OrderingTerm(expression: a.createdAt),
          ]))
        .get();
  }

  Future<void> create({
    required String id,
    required String spaceId,
    required String entityKind,
    required String entityId,
    required String url,
    String mimeType = 'image/jpeg',
    String? thumbUrl,
    String? caption,
    int? sortOrder,
    String? uploadedBy,
    String? takenAt,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await into(attachments).insert(
      AttachmentsCompanion.insert(
        id: id,
        spaceId: spaceId,
        entityKind: entityKind,
        entityId: entityId,
        url: url,
        thumbUrl: Value(thumbUrl),
        mimeType: mimeType,
        caption: Value(caption),
        sortOrder: Value(sortOrder),
        uploadedBy: Value(uploadedBy),
        takenAt: Value(takenAt),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> update_({
    required String id,
    String? caption,
    int? sortOrder,
    String? thumbUrl,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(attachments)..where((a) => a.id.equals(id))).write(
      AttachmentsCompanion(
        caption: caption == null ? const Value.absent() : Value(caption),
        sortOrder:
            sortOrder == null ? const Value.absent() : Value(sortOrder),
        thumbUrl: thumbUrl == null ? const Value.absent() : Value(thumbUrl),
        updatedAt: Value(now),
      ),
    );
  }

  /// Replace the attachment's url. Used by `PhotoUploadQueue` when
  /// a deferred upload finally lands — we wrote `pending:<id>` into
  /// the row at enqueue time; this method swaps it for the real
  /// bucket path.
  Future<void> updateUrl(String id, String url) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(attachments)..where((a) => a.id.equals(id))).write(
      AttachmentsCompanion(
        url: Value(url),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> deleteById(String id) async {
    await (delete(attachments)..where((a) => a.id.equals(id))).go();
  }
}
