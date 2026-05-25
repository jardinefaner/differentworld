import 'package:differentworld/core/db/app_database.dart';
import 'package:drift/drift.dart';

part 'captures_dao.g.dart';

/// All Drift mutators for the Capture inbox.
///
/// Extracted from `app_database.dart` per the `split-dao` recipe — the
/// captures domain has clean lines (its rows are independent of every
/// other table), making it a low-risk first pass at the DAO pattern.
///
/// Callers reach this via `db.capturesDao` (Drift generates the
/// accessor from the `@DriftDatabase(daos: [CapturesDao])` declaration).
@DriftAccessor(tables: [Captures])
class CapturesDao extends DatabaseAccessor<AppDatabase>
    with _$CapturesDaoMixin {
  CapturesDao(super.attachedDatabase);

  /// Open captures in a space, **oldest first** — the inbox is a
  /// triage queue. The thing that's been sitting longest is the most
  /// likely to be forgotten; surfacing newest-first inverted the
  /// triage priority (Wave 64 UX rerank). Today launchpad's "captures
  /// awaiting triage" count still works regardless of order.
  Stream<List<Capture>> watchOpen(String spaceId) {
    return (select(captures)
          ..where((c) => c.spaceId.equals(spaceId) & c.status.equals('open'))
          ..orderBy([
            (c) => OrderingTerm(
                  expression: c.createdAt,
                ),
          ]))
        .watch();
  }

  /// All captures (any status), newest first — used by the inbox
  /// screen when the user toggles "show triaged" or by a future audit
  /// view.
  Stream<List<Capture>> watchAll(String spaceId) {
    return (select(captures)
          ..where((c) => c.spaceId.equals(spaceId))
          ..orderBy([
            (c) => OrderingTerm(
                  expression: c.createdAt,
                  mode: OrderingMode.desc,
                ),
          ]))
        .watch();
  }

  Future<Capture?> findById(String id) {
    return (select(captures)..where((c) => c.id.equals(id)))
        .getSingleOrNull();
  }

  /// Insert a fresh capture and return its id. The sheet calls this
  /// once the user starts typing; subsequent edits go through
  /// [updateBody] against the returned id (so the cursor keystroke at
  /// t+200ms doesn't create a second row).
  Future<String> insert({
    required String id,
    required String spaceId,
    required String body,
    String? authorId,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await into(captures).insert(
      CapturesCompanion.insert(
        id: id,
        spaceId: spaceId,
        authorId: Value(authorId),
        body: body,
        status: 'open',
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  Future<void> updateBody({
    required String id,
    required String body,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(captures)..where((c) => c.id.equals(id))).write(
      CapturesCompanion(body: Value(body), updatedAt: Value(now)),
    );
  }

  /// Mark a capture as turned into a downstream entity. The pointer is
  /// loose (no FK to the other table) because the destination table is
  /// open-ended (today entries; later tasks / events / etc.).
  Future<void> markPromoted({
    required String id,
    required String promotedToKind,
    required String promotedToId,
    String? promotedSubjectId,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(captures)..where((c) => c.id.equals(id))).write(
      CapturesCompanion(
        status: const Value('promoted'),
        promotedToKind: Value(promotedToKind),
        promotedToId: Value(promotedToId),
        promotedSubjectId: Value(promotedSubjectId),
        processedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> markDiscarded(String id) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(captures)..where((c) => c.id.equals(id))).write(
      CapturesCompanion(
        status: const Value('discarded'),
        processedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  /// Reopens a capture that was previously promoted or discarded. Not
  /// exposed in v1 UI; kept cheap so the audit trail stays correctable
  /// from a debug surface.
  Future<void> reopen(String id) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(captures)..where((c) => c.id.equals(id))).write(
      CapturesCompanion(
        status: const Value('open'),
        promotedToKind: const Value(null),
        promotedToId: const Value(null),
        promotedSubjectId: const Value(null),
        processedAt: const Value(null),
        updatedAt: Value(now),
      ),
    );
  }

  /// Hard-delete a capture. Distinct from [markDiscarded], which keeps
  /// the row for audit. Use when the user mis-typed and immediately
  /// backs out of an empty draft.
  Future<void> deleteById(String id) async {
    await (delete(captures)..where((c) => c.id.equals(id))).go();
  }
}
