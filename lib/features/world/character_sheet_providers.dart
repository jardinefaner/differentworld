import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/features/photos/photo_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' show XFile;

/// Live in-world self for a subject — null until the day-one ritual (draw +
/// name). Different World; docs/WORLD.md.
// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final characterSheetForSubjectProvider = StreamProvider.autoDispose
    .family<CharacterSheet?, String>(
      (ref, subjectId) async* {
        final db = await ref.watch(appDatabaseProvider.future);
        yield* db.characterSheetsDao.watchForSubject(subjectId);
      },
    );

final characterSheetActionsProvider = Provider<CharacterSheetActions>(
  CharacterSheetActions.new,
);

/// Writes to the persistent world-self. Optimistic + offline-first, like every
/// other mutation: local Drift write commits immediately, PowerSync uploads
/// later.
class CharacterSheetActions {
  CharacterSheetActions(this._ref);
  final Ref _ref;

  /// Save a child's DRAWING as their world-self avatar — deliberately separate
  /// from the subject's administrative `photoUrl` (pickup ID photo). Routes
  /// through the shared photo pipeline (compression, private bucket, signed
  /// reads, offline queue) via [PhotoService.uploadOnly], then writes the path
  /// to `character_sheets.avatar_url`.
  ///
  /// The sheet row is created BEFORE the (possibly offline) upload so the
  /// queue's later patch — `UPDATE … WHERE subject_id = entityId` — has a row
  /// to hit. `entityId` is the subjectId so the queue's `case 'character_sheet'`
  /// resolves the right child.
  Future<void> setDrawnAvatar({
    required String subjectId,
    required XFile drawing,
  }) async {
    final spaceId = _ref.read(currentMemberProvider).value?.spaceId;
    if (spaceId == null) {
      throw StateError('No Space — sign in and join a program first.');
    }
    final db = await _ref.read(appDatabaseProvider.future);
    await db.characterSheetsDao.ensureForSubject(
      spaceId: spaceId,
      subjectId: subjectId,
    );
    final stored = await _ref
        .read(photoServiceProvider)
        .uploadOnly(
          entityKind: 'character_sheet',
          entityId: subjectId,
          picked: drawing,
        );
    await db.characterSheetsDao.setAvatarUrlForSubject(subjectId, stored);
  }

  /// Set / clear the world-self's chosen name.
  Future<void> setChosenName({
    required String subjectId,
    required String? name,
  }) async {
    final spaceId = _ref.read(currentMemberProvider).value?.spaceId;
    if (spaceId == null) {
      throw StateError('No Space — sign in and join a program first.');
    }
    final db = await _ref.read(appDatabaseProvider.future);
    final trimmed = name?.trim();
    await db.characterSheetsDao.setChosenName(
      spaceId: spaceId,
      subjectId: subjectId,
      chosenName: (trimmed == null || trimmed.isEmpty) ? null : trimmed,
    );
  }
}
