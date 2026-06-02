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
  }
}
