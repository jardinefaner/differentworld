import 'dart:async';
import 'dart:isolate';

import 'package:differentworld/core/db/drift_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// What kind of entity is the photo attached to. The entity drives:
/// - which Drift column gets the resulting URL
/// - the storage path prefix
enum PhotoEntity { member, subject }

class PhotoService {
  PhotoService(this._ref);

  final Ref _ref;
  static const _uuid = Uuid();
  static const _bucket = 'person-photos';

  /// Max longest edge after resize, in pixels. 1024 px is well above
  /// any avatar render size and keeps faces recognisable. Mirrored
  /// inside `_compressSync` as a local const since isolate fns can't
  /// reach class statics across the boundary.
  static const int _maxEdge = 1024;

  SupabaseClient get _supabase => Supabase.instance.client;

  /// Pick a photo from the camera or gallery — returns the picked
  /// XFile (or null if the user cancelled). Kept separate from upload
  /// so the caller can show a spinner around the long-running
  /// compress+upload phase without blocking the picker UI.
  Future<XFile?> pickPhoto(ImageSource source) async {
    return ImagePicker().pickImage(
      source: source,
      maxWidth: _maxEdge.toDouble(),
      maxHeight: _maxEdge.toDouble(),
      imageQuality: 88,
      // Skips EXIF location data — privacy win for a children's app,
      // and makes the iOS NSMicrophoneUsageDescription unnecessary.
      requestFullMetadata: false,
    );
  }

  /// Compress + upload + persist the URL. Call after [pickPhoto]
  /// returned non-null. Compress runs in an Isolate so the UI thread
  /// stays free for the spinner.
  Future<String> uploadAndPersist({
    required PhotoEntity entity,
    required String entityId,
    required XFile picked,
  }) async {
    final me = _ref.read(currentMemberProvider).value;
    final spaceId = me?.spaceId;
    if (spaceId == null) {
      throw StateError('No Space — sign in and join a program first.');
    }

    final bytes = await picked.readAsBytes();
    final compressed = await Isolate.run(() => _compressSync(bytes));
    final path = '$spaceId/${entity.name}/$entityId/${_uuid.v4()}.jpg';

    await _supabase.storage.from(_bucket).uploadBinary(
          path,
          compressed,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );

    // The path includes a fresh UUID per upload, so the public URL
    // changes every time — cached_network_image will fetch the new
    // bytes without any explicit cache-bust query string. Keeping the
    // stored URL clean (no `?v=`) avoids persisting upload timestamps
    // to the database, which would otherwise become a tiny PII leak.
    final url = _supabase.storage.from(_bucket).getPublicUrl(path);

    final db = await _ref.read(appDatabaseProvider.future);
    switch (entity) {
      case PhotoEntity.member:
        await db.updateMemberAvatarUrl(entityId, url);
      case PhotoEntity.subject:
        await db.updateSubjectPhotoUrl(entityId, url);
    }
    return url;
  }

  /// Drop the photo from the entity row. Doesn't delete the object in
  /// Storage — orphans are fine; we'd rather avoid the destructive
  /// cleanup if the same path was somehow referenced twice.
  Future<void> clear({
    required PhotoEntity entity,
    required String entityId,
  }) async {
    final db = await _ref.read(appDatabaseProvider.future);
    switch (entity) {
      case PhotoEntity.member:
        await db.updateMemberAvatarUrl(entityId, null);
      case PhotoEntity.subject:
        await db.updateSubjectPhotoUrl(entityId, null);
    }
  }

}

/// Top-level so it can run inside `Isolate.run` (closures over instance
/// fields can't be sent across isolate boundaries).
///
/// Resize-to-fit + JPEG re-encode at descending quality until the byte
/// count is at or below 1 MB. Image_picker already caps the longest
/// edge at 1024 px and Q88, so this is mostly a safety net — but a
/// large gallery photo unaffected by the picker's resize hint will
/// still come through here.
Uint8List _compressSync(Uint8List input) {
  const targetBytes = 1024 * 1024;
  const maxEdge = 1024;
  final decoded = img.decodeImage(input);
  if (decoded == null) {
    throw const FormatException('Could not decode the picked image.');
  }
  var resized = decoded;
  if (decoded.width > maxEdge || decoded.height > maxEdge) {
    resized = img.copyResize(
      decoded,
      width: decoded.width >= decoded.height ? maxEdge : null,
      height: decoded.width < decoded.height ? maxEdge : null,
      interpolation: img.Interpolation.average,
    );
  }
  var quality = 88;
  var encoded = Uint8List.fromList(img.encodeJpg(resized, quality: quality));
  while (encoded.lengthInBytes > targetBytes && quality > 50) {
    quality -= 10;
    encoded = Uint8List.fromList(img.encodeJpg(resized, quality: quality));
  }
  if (kDebugMode) {
    debugPrint(
      '[photo] compressed ${input.lengthInBytes ~/ 1024}KB → '
      '${encoded.lengthInBytes ~/ 1024}KB @ q=$quality',
    );
  }
  return encoded;
}

final Provider<PhotoService> photoServiceProvider =
    Provider<PhotoService>(PhotoService.new);
