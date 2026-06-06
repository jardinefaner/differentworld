import 'package:differentworld/core/db/app_database.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

part 'character_sheets_dao.g.dart';

/// Drift mutators for the persistent in-world SELF (Different World;
/// docs/WORLD.md, docs/WORLD_DESIGN.md). One row per subject (1:1), keyed in
/// practice by `subjectId` (UNIQUE server-side) — callers always address a
/// child, not a sheet id.
///
/// The drawn avatar lives in `avatarUrl` as a `person-photos` bucket path,
/// SEPARATE from the subject's administrative `photoUrl`. Reached via
/// `db.characterSheetsDao`.
@DriftAccessor(tables: [CharacterSheets])
class CharacterSheetsDao extends DatabaseAccessor<AppDatabase>
    with _$CharacterSheetsDaoMixin {
  CharacterSheetsDao(super.attachedDatabase);

  static const _uuid = Uuid();

  /// Live view of a child's world-self (null until the day-one ritual).
  Stream<CharacterSheet?> watchForSubject(String subjectId) {
    return (select(characterSheets)
          ..where((c) => c.subjectId.equals(subjectId)))
        .watchSingleOrNull();
  }

  Future<CharacterSheet?> findForSubject(String subjectId) {
    return (select(characterSheets)
          ..where((c) => c.subjectId.equals(subjectId)))
        .getSingleOrNull();
  }

  /// Ensure a sheet exists for the subject, returning it. Idempotent — the
  /// 1:1 invariant means we never create a second row for the same child.
  ///
  /// Wrapped in a transaction so the find→insert is atomic: the local
  /// PowerSync SQLite has no UNIQUE(subject_id) constraint (PowerSync owns the
  /// schema and only adds the `id` PK), so two concurrent ensures would
  /// otherwise both see null and both INSERT — a second local row the server's
  /// UNIQUE rejects forever on upload. Drift serialises transactions on the
  /// connection, so the second caller sees the first's row.
  Future<CharacterSheet> ensureForSubject({
    required String spaceId,
    required String subjectId,
  }) {
    return transaction(() async {
      final existing = await findForSubject(subjectId);
      if (existing != null) return existing;
      final now = DateTime.now().toUtc().toIso8601String();
      final row = CharacterSheetsCompanion.insert(
        id: _uuid.v4(),
        spaceId: spaceId,
        subjectId: subjectId,
        createdAt: now,
        updatedAt: now,
      );
      await into(characterSheets).insert(row);
      // Re-read so callers get the persisted row (with any DB-side defaults).
      return (await findForSubject(subjectId))!;
    });
  }

  /// Set the drawn avatar (a bucket path or a `pending:<id>` token). Creates
  /// the sheet first if the child doesn't have one yet.
  Future<void> setAvatar({
    required String spaceId,
    required String subjectId,
    required String? avatarUrl,
  }) async {
    await ensureForSubject(spaceId: spaceId, subjectId: subjectId);
    await _patchBySubject(
      subjectId,
      CharacterSheetsCompanion(avatarUrl: Value(avatarUrl)),
    );
  }

  /// Patch just the avatar path by subject — the offline upload queue's hook
  /// (entityId == subjectId). The row already exists (set with the `pending:`
  /// token at draw time), so this is a pure UPDATE.
  Future<void> setAvatarUrlForSubject(String subjectId, String url) {
    return _patchBySubject(
      subjectId,
      CharacterSheetsCompanion(avatarUrl: Value(url)),
    );
  }

  /// Set the world-self's chosen name. Creates the sheet first if needed.
  Future<void> setChosenName({
    required String spaceId,
    required String subjectId,
    required String? chosenName,
  }) async {
    await ensureForSubject(spaceId: spaceId, subjectId: subjectId);
    await _patchBySubject(
      subjectId,
      CharacterSheetsCompanion(chosenName: Value(chosenName)),
    );
  }

  Future<void> _patchBySubject(
    String subjectId,
    CharacterSheetsCompanion patch,
  ) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(characterSheets)..where((c) => c.subjectId.equals(subjectId)))
        .write(patch.copyWith(updatedAt: Value(now)));
  }
}
