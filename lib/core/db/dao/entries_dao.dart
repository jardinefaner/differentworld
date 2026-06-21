import 'package:differentworld/core/db/app_database.dart';
import 'package:drift/drift.dart';

part 'entries_dao.g.dart';

/// The unified daily-log table. `kind` discriminates between
/// 'observation', 'meal', 'nap', 'diaper', 'incident', etc.; `details`
/// holds the kind-specific JSONB shape.
@DriftAccessor(tables: [Entries])
class EntriesDao extends DatabaseAccessor<AppDatabase>
    with _$EntriesDaoMixin {
  EntriesDao(super.attachedDatabase);

  /// All entries for a classroom of a given kind, newest first. The
  /// observations screen uses kind='observation'.
  Stream<List<Entry>> watchForGroup({
    required String groupId,
    required String kind,
    int limit = 100,
  }) {
    return (select(entries)
          ..where((e) => e.groupId.equals(groupId) & e.kind.equals(kind))
          ..orderBy([(e) => OrderingTerm.desc(e.recordedAt)])
          ..limit(limit))
        .watch();
  }

  /// All entries for a subject, newest first. Powers the Subject detail
  /// screen and the "recent observations" surface.
  Stream<List<Entry>> watchForSubject({
    required String subjectId,
    String? kind,
    int limit = 50,
  }) {
    final query = select(entries)
      ..where((e) {
        final base = e.subjectId.equals(subjectId);
        return kind == null ? base : base & e.kind.equals(kind);
      })
      ..orderBy([(e) => OrderingTerm.desc(e.recordedAt)])
      ..limit(limit);
    return query.watch();
  }

  /// Every entry of a kind across the whole space, newest first.
  /// Powers the top-level `/observations` index. Teachers see only
  /// what's visible to them — the viewer-side filtering happens in
  /// the provider that wraps this stream, since the DB doesn't know
  /// about classroom assignments.
  Stream<List<Entry>> watchInSpace({
    required String spaceId,
    required String kind,
    int limit = 200,
  }) {
    return (select(entries)
          ..where((e) => e.spaceId.equals(spaceId) & e.kind.equals(kind))
          ..orderBy([(e) => OrderingTerm.desc(e.recordedAt)])
          ..limit(limit))
        .watch();
  }

  /// Every entry in the space, ANY kind, newest first — the substrate for
  /// the room Story timeline (it weaves all moment kinds together).
  Stream<List<Entry>> watchAllInSpace({
    required String spaceId,
    int limit = 300,
  }) {
    return (select(entries)
          ..where((e) => e.spaceId.equals(spaceId))
          ..orderBy([(e) => OrderingTerm.desc(e.recordedAt)])
          ..limit(limit))
        .watch();
  }

  /// Entries tagged to a schedule block, newest first — the reverse of
  /// the live-block tag. Powers the block's "moments" sheet.
  Stream<List<Entry>> watchForBlock({
    required String scheduleBlockId,
    int limit = 100,
  }) {
    return (select(entries)
          ..where((e) => e.scheduleBlockId.equals(scheduleBlockId))
          ..orderBy([(e) => OrderingTerm.desc(e.recordedAt)])
          ..limit(limit))
        .watch();
  }

  Future<void> create({
    required String id,
    required String spaceId,
    required String kind,
    required String recordedBy,
    String? groupId,
    String? subjectId,
    String? scheduleBlockId,
    String? body,
    String? photoUrl,
    String detailsJson = '{}',
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await into(entries).insert(
      EntriesCompanion.insert(
        id: id,
        spaceId: spaceId,
        kind: kind,
        groupId: groupId == null ? const Value.absent() : Value(groupId),
        subjectId:
            subjectId == null ? const Value.absent() : Value(subjectId),
        scheduleBlockId: scheduleBlockId == null
            ? const Value.absent()
            : Value(scheduleBlockId),
        body: body == null ? const Value.absent() : Value(body),
        photoUrl: photoUrl == null ? const Value.absent() : Value(photoUrl),
        details: detailsJson,
        recordedBy: recordedBy,
        recordedAt: now,
        updatedAt: now,
      ),
    );
  }

  /// Re-insert a previously-deleted entry VERBATIM — the undo path for
  /// `deleteWithUndo`. The row keeps its stable client UUID, so
  /// insert-or-replace re-creates the exact row and PowerSync re-syncs it
  /// (it reappears on every device).
  Future<void> restore(Entry entry) async {
    await into(entries).insertOnConflictUpdate(entry);
  }

  /// Update an entry's text. The other fields are effectively
  /// immutable here — kind / subject / group don't move once the row
  /// is created. Use [updatePhotos] to change attached photos.
  Future<void> updateText({
    required String id,
    String? body,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(entries)..where((e) => e.id.equals(id))).write(
      EntriesCompanion(
        body: body == null ? const Value.absent() : Value(body),
        updatedAt: Value(now),
      ),
    );
  }

  /// Replace an entry's structured `details` JSON. Amends an entry after
  /// the fact without touching its narrative — e.g. flipping an
  /// incident's `parent_notified` once the family's actually been called
  /// (the "log now, notify later" flow).
  Future<void> updateDetails({
    required String id,
    required String detailsJson,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(entries)..where((e) => e.id.equals(id))).write(
      EntriesCompanion(
        details: Value(detailsJson),
        updatedAt: Value(now),
      ),
    );
  }

  /// Replace an entry's attached photos. Pass `photoUrl: null` and the
  /// serialized `detailsJson` that has no `photos` key to clear them.
  /// Both fields are always written (Value(...)), not Value.absent(),
  /// because callers explicitly stage the full new state.
  Future<void> updatePhotos({
    required String id,
    required String? photoUrl,
    required String detailsJson,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(entries)..where((e) => e.id.equals(id))).write(
      EntriesCompanion(
        photoUrl: Value(photoUrl),
        details: Value(detailsJson),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> deleteById(String id) async {
    await (delete(entries)..where((e) => e.id.equals(id))).go();
  }
}
