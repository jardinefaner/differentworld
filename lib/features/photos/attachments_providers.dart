import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// Identity of an entity for attachment queries. Kept as a record so
/// it works as a Riverpod family key.
typedef AttachmentEntity = ({String kind, String id});

/// Live list of attachments for a given entity, ordered by
/// `sort_order` (nulls last) then `created_at`.
// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final attachmentsForEntityProvider =
    StreamProvider.autoDispose.family<List<Attachment>, AttachmentEntity>(
  (ref, key) async* {
    final db = await ref.watch(appDatabaseProvider.future);
    yield* db.attachmentsDao.watchFor(
      entityKind: key.kind,
      entityId: key.id,
    );
  },
);

/// Convenience extension: extract just the URLs in order. Handy
/// because most UI surfaces just want a `List<String>` for the
/// PhotoViewer / thumbnail list.
extension AttachmentsX on List<Attachment> {
  List<String> get urls => map((a) => a.url).toList(growable: false);

  /// Like `urls` but prefers `thumb_url` when available — used by
  /// thumbnail strips so a list view doesn't pull the full-res image.
  List<String> get thumbUrls => map((a) => a.thumbUrl ?? a.url)
      .toList(growable: false);
}

/// Mutators for attachments. Upload bytes happens in `PhotoService`;
/// this class persists the row pointing at the resulting URL.
class AttachmentActions {
  AttachmentActions(this._ref);

  final Ref _ref;
  final Uuid _uuid = const Uuid();

  /// Persist a freshly-uploaded asset as a new attachment row. The
  /// caller has already uploaded the bytes via `PhotoService.uploadOnly`
  /// and pass the resulting URL here. Returns the new attachment id.
  ///
  /// `sortOrder` defaults to "after everything currently attached" —
  /// pass an explicit int to control ordering (e.g. when re-ordering
  /// a gallery).
  Future<String> add({
    required String entityKind,
    required String entityId,
    required String url,
    String mimeType = 'image/jpeg',
    String? thumbUrl,
    String? caption,
    int? sortOrder,
  }) async {
    final viewer = _ref.read(viewerProvider);
    final spaceId = viewer.spaceId;
    if (spaceId == null) {
      throw StateError('No Space — cannot attach a photo.');
    }
    final db = await _ref.read(appDatabaseProvider.future);
    final id = _uuid.v4();
    final effectiveSort = sortOrder ?? await _nextSortOrder(db, entityKind, entityId);
    await db.attachmentsDao.create(
      id: id,
      spaceId: spaceId,
      entityKind: entityKind,
      entityId: entityId,
      url: url,
      mimeType: mimeType,
      thumbUrl: thumbUrl,
      caption: caption,
      sortOrder: effectiveSort,
      uploadedBy: viewer.memberId,
      takenAt: DateTime.now().toUtc().toIso8601String(),
    );
    return id;
  }

  Future<void> updateCaption({required String id, String? caption}) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.attachmentsDao.update_(id: id, caption: caption);
  }

  Future<void> reorder({required String id, required int sortOrder}) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.attachmentsDao.update_(id: id, sortOrder: sortOrder);
  }

  Future<void> remove(String id) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.attachmentsDao.deleteById(id);
  }

  /// "Insert after everything currently attached." Reads the existing
  /// rows once so we can pick `max(sortOrder) + 1`. Concurrent callers
  /// could race here (two devices both compute the same next value)
  /// but the duplicate-ordering just means visual ties; no correctness
  /// issue and PowerSync's eventual consistency will sort them by
  /// created_at as a tiebreaker.
  Future<int> _nextSortOrder(
    AppDatabase db,
    String entityKind,
    String entityId,
  ) async {
    final existing = await db.attachmentsDao.findFor(
      entityKind: entityKind,
      entityId: entityId,
    );
    var max = -1;
    for (final a in existing) {
      final s = a.sortOrder;
      if (s != null && s > max) max = s;
    }
    return max + 1;
  }
}

final attachmentActionsProvider =
    Provider<AttachmentActions>(AttachmentActions.new);
