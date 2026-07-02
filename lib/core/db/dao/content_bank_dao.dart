import 'dart:convert';

import 'package:differentworld/core/db/app_database.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

part 'content_bank_dao.g.dart';

/// The content bank's data layer (docs/CONTENT_BANK.md). Reads the banked
/// items a device can see — GLOBAL rows (`space_id IS NULL`: AI /
/// shared-curated) plus the signed-in program's OWN (crowd-grown) rows —
/// and writes new crowd items de-duped by fingerprint (uniqueness is the
/// bank's job, never the activity's, §4).
@DriftAccessor(tables: [ContentItems])
class ContentBankDao extends DatabaseAccessor<AppDatabase>
    with _$ContentBankDaoMixin {
  ContentBankDao(super.attachedDatabase);

  static const _uuid = Uuid();

  /// Everything [spaceId] can see: global rows ∪ its own. Feeds the bank.
  Stream<List<ContentItemRow>> watchForSpace(String spaceId) {
    return (select(contentItems)
          ..where((c) => c.spaceId.isNull() | c.spaceId.equals(spaceId)))
        .watch();
  }

  /// Global rows only — for a viewer with no space yet (guardian /
  /// pre-onboarding). The global AI/curated tier is still playable.
  Stream<List<ContentItemRow>> watchGlobal() {
    return (select(contentItems)..where((c) => c.spaceId.isNull())).watch();
  }

  /// How many items of [kind] are banked for [spaceId] (global ∪ own) —
  /// the signal `ensureBank` reads to decide whether to refill (Slice C).
  Future<int> countOfKind(String kind, String spaceId) async {
    final q = selectOnly(contentItems)
      ..addColumns([contentItems.id.count()])
      ..where(
        contentItems.kind.equals(kind) &
            (contentItems.spaceId.isNull() |
                contentItems.spaceId.equals(spaceId)),
      );
    final row = await q.getSingle();
    return row.read(contentItems.id.count()) ?? 0;
  }

  /// Watch a space's OWN authored items of a [kind] — the management library
  /// for staff-authored content (custom pictures, this-or-that pairs, …).
  /// Excludes global rows; newest first. Small per-space set, so no index.
  Stream<List<ContentItemRow>> watchOwnByKind(String spaceId, String kind) {
    return (select(contentItems)
          ..where((c) => c.spaceId.equals(spaceId) & c.kind.equals(kind))
          ..orderBy([
            (c) => OrderingTerm(
              expression: c.createdAt,
              mode: OrderingMode.desc,
            ),
          ]))
        .watch();
  }

  /// Create a STAFF-authored item. Unlike [bankCrowdItem], each gets a unique
  /// fingerprint (its own id) so authored items never collapse against each
  /// other — a teacher can add two "Our dog" pictures if they want. Merges into
  /// the bank via [watchForSpace] like any other row, so content-bank games
  /// pick it up with no game code. Returns the new row id.
  Future<String> createStaffItem({
    required String spaceId,
    required String kind,
    required String payload,
    String? id,
    String? createdBy,
  }) async {
    // Caller may pre-generate the id (e.g. a picture add pre-generates it to
    // pass as the upload's entityId, so the offline queue can patch this row).
    final rowId = id ?? _uuid.v4();
    await into(contentItems).insert(
      ContentItemsCompanion.insert(
        id: rowId,
        spaceId: Value(spaceId),
        kind: kind,
        payload: payload,
        fingerprint: rowId,
        source: 'staff',
        createdBy: Value(createdBy),
        createdAt: DateTime.now().toUtc().toIso8601String(),
      ),
    );
    return rowId;
  }

  /// Swap a `picture` item's image field to the real Storage path once its
  /// deferred (offline) upload lands — called by `PhotoUploadQueue` when it
  /// drains a `custom_picture` entry. Merges into the existing payload so the
  /// label is preserved; a no-op if the row is gone (deleted before the upload
  /// landed) or its payload is malformed.
  Future<void> updatePicturePath(String id, String realPath) async {
    final row =
        await (select(contentItems)..where((c) => c.id.equals(id)))
            .getSingleOrNull();
    if (row == null) return;
    final Map<String, Object?> payload;
    try {
      final decoded = jsonDecode(row.payload);
      payload = decoded is Map
          ? Map<String, Object?>.from(decoded)
          : <String, Object?>{};
    } on FormatException {
      return;
    }
    payload['image'] = realPath;
    await updatePayload(id, jsonEncode(payload));
  }

  /// Edit an authored item's payload (rename a picture, fix a pair). Only the
  /// payload is mutable; kind / space / source are fixed at creation.
  Future<void> updatePayload(String id, String payload) async {
    await (update(contentItems)..where((c) => c.id.equals(id)))
        .write(ContentItemsCompanion(payload: Value(payload)));
  }

  /// Remove an authored item. Hard delete — PowerSync propagates it; the
  /// caller pairs it with an Undo (re-insert) rather than a confirm dialog.
  Future<void> deleteById(String id) async {
    await (delete(contentItems)..where((c) => c.id.equals(id))).go();
  }

  /// Bank a new crowd-grown item if its fingerprint isn't already present
  /// in this space's scope. Returns the row id (existing or freshly
  /// inserted). De-dupe is checked here AND enforced by the server's
  /// partial unique index, so a racing duplicate just collapses.
  Future<String> bankCrowdItem({
    required String spaceId,
    required String kind,
    required String fingerprint,
    required String payload,
    String? createdBy,
  }) async {
    // Check-then-insert in one transaction so a same-device double-tap can't
    // slip a duplicate past the SELECT. (Cross-device races are still caught
    // by the server's partial unique index — uniqueness is the bank's job.)
    return transaction(() async {
      final existing =
          await (select(contentItems)..where(
                (c) =>
                    c.kind.equals(kind) &
                    c.fingerprint.equals(fingerprint) &
                    (c.spaceId.isNull() | c.spaceId.equals(spaceId)),
              ))
              .getSingleOrNull();
      if (existing != null) return existing.id;
      final id = _uuid.v4();
      await into(contentItems).insert(
        ContentItemsCompanion.insert(
          id: id,
          spaceId: Value(spaceId),
          kind: kind,
          payload: payload,
          fingerprint: fingerprint,
          source: 'crowd',
          createdBy: Value(createdBy),
          createdAt: DateTime.now().toUtc().toIso8601String(),
        ),
      );
      return id;
    });
  }
}
