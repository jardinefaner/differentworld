import 'dart:convert';

import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/photos/photo_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

/// A staff-authored picture for the "Reveal the Picture" grid game. Stored as a
/// `content_items` row (`kind='picture'`) with `payload = {image, label}` — the
/// bytes live in the private `person-photos` bucket (binary-media rule); the row
/// carries only the path. Rides the existing content bank, so no new table.
@immutable
class CustomPicture {
  const CustomPicture({
    required this.id,
    required this.label,
    required this.path,
  });

  final String id;
  final String label;

  /// Storage path, or a `pending:<id>` token while an offline upload waits.
  final String path;

  /// True while the bytes haven't uploaded yet (offline add) — the UI shows an
  /// "uploading…" state and the game skips it until it lands.
  bool get isPending => path.startsWith('pending:');
}

/// The `content_items.kind` these ride on — the same kind the picture-card
/// games read, so the grid game picks them up through the bank.
const String kPictureKind = 'picture';

/// The current space's own authored pictures, newest first. Plain (keepAlive)
/// like `bankedContentProvider` next door — the set is small and app-wide, so
/// the Drift watch stays warm for both the library screen and the game seed.
final customPicturesProvider =
    StreamProvider<List<CustomPicture>>((ref) async* {
  final viewer = ref.watch(viewerProvider);
  final spaceId = viewer.spaceId;
  if (spaceId == null) {
    yield const <CustomPicture>[];
    return;
  }
  final db = await ref.watch(appDatabaseProvider.future);
  await for (final rows in db.contentBankDao.watchOwnByKind(spaceId, kPictureKind)) {
    yield [
      for (final r in rows)
        if (_decode(r.payload) case final Map<String, Object?> p)
          CustomPicture(
            id: r.id,
            label: (p['label'] as String?)?.trim() ?? '',
            path: (p['image'] as String?) ?? '',
          ),
    ];
  }
});

Map<String, Object?>? _decode(String raw) {
  try {
    final d = jsonDecode(raw);
    return d is Map ? Map<String, Object?>.from(d) : null;
  } on FormatException {
    return null;
  }
}

final customPictureActionsProvider =
    Provider<CustomPictureActions>(CustomPictureActions.new);

class CustomPictureActions {
  CustomPictureActions(this._ref);
  final Ref _ref;
  static const _uuid = Uuid();

  /// Add a picture. Pre-generate the row id so it can be the upload's
  /// `entityId`; upload the bytes (online → the real Storage path; offline →
  /// `pending:<id>`, enqueued as a non-deferred `custom_picture` entry the
  /// queue patches on reconnect); then create the `content_items` row with the
  /// same id. Optimistic: the row (and its "uploading…" state offline) shows at
  /// once.
  Future<void> add({required XFile picked, required String label}) async {
    final spaceId = _ref.read(viewerProvider).spaceId;
    if (spaceId == null) {
      throw StateError('No Space — join a program before adding pictures.');
    }
    final id = _uuid.v4();
    final path = await _ref.read(photoServiceProvider).uploadOnly(
          entityKind: 'custom_picture',
          entityId: id,
          picked: picked,
        );
    final db = await _ref.read(appDatabaseProvider.future);
    await db.contentBankDao.createStaffItem(
      id: id,
      spaceId: spaceId,
      kind: kPictureKind,
      payload: jsonEncode({'image': path, 'label': label.trim()}),
    );
  }

  /// Rename a picture (payload keeps the same image path).
  Future<void> rename(CustomPicture pic, String newLabel) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.contentBankDao.updatePayload(
      pic.id,
      jsonEncode({'image': pic.path, 'label': newLabel.trim()}),
    );
  }

  /// Remove a picture (the caller pairs this with an Undo snackbar via
  /// [restore]). Leaves the Storage bytes in place so Undo re-links them.
  Future<void> delete(String id) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.contentBankDao.deleteById(id);
  }

  /// Undo a delete — re-insert with the SAME id so it re-syncs and re-links its
  /// (still-present) Storage bytes.
  Future<void> restore(CustomPicture pic) async {
    final spaceId = _ref.read(viewerProvider).spaceId;
    if (spaceId == null) return;
    final db = await _ref.read(appDatabaseProvider.future);
    await db.contentBankDao.createStaffItem(
      id: pic.id,
      spaceId: spaceId,
      kind: kPictureKind,
      payload: jsonEncode({'image': pic.path, 'label': pic.label}),
    );
  }
}
