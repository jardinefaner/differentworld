import 'dart:convert';

import 'package:differentworld/core/db/app_database.dart';

/// Schema notes for the multi-photo storage on `entries`:
///   - `photo_url` (legacy column) holds the FIRST photo's URL. We
///     keep it populated so old code paths (a per-classroom thumbnail
///     that only knows about one URL, the search-suggestion preview,
///     etc.) keep working without change.
///   - Photos two and beyond live under `details.photos` as a JSON
///     string array.
///   - The merged list (primary + extras) is exposed via
///     [EntryPhotosX.photos] on the read side, and built on the write
///     side via [SerializedPhotos.split].
///
/// Why not store them all in `details.photos`? Because `photo_url`
/// already had real data, and migrating would have meant rewriting
/// every existing row plus changing every reader. The split keeps
/// the migration cost at zero.
extension EntryPhotosX on Entry {
  /// Flat list of every photo on this entry, primary first.
  List<String> get photos {
    final out = <String>[];
    final primary = photoUrl;
    if (primary != null && primary.isNotEmpty) out.add(primary);
    try {
      final decoded = jsonDecode(details);
      if (decoded is Map && decoded['photos'] is List) {
        for (final p in decoded['photos'] as List) {
          if (p is! String) continue;
          if (p.isEmpty) continue;
          if (p == primary) continue;
          out.add(p);
        }
      }
    } on FormatException {
      // details wasn't valid JSON — treat as no extras.
    }
    return out;
  }

  /// Whether this entry has at least one photo attached.
  bool get hasPhotos => photos.isNotEmpty;
}

/// Split a flat photo list back into the wire format the DB stores:
/// the first URL goes to `photo_url`; the rest into `details.photos`.
///
/// `baseDetails` carries any other JSON keys you don't want clobbered
/// (an existing `tags` field, kind-specific structured payload, etc).
class SerializedPhotos {
  const SerializedPhotos({required this.primary, required this.detailsJson});

  factory SerializedPhotos.split(
    List<String> photos, {
    String? baseDetailsJson,
  }) {
    final base = _decodeOrEmpty(baseDetailsJson);
    if (photos.isEmpty) {
      base.remove('photos');
      return SerializedPhotos(
        primary: null,
        detailsJson: jsonEncode(base),
      );
    }
    final primary = photos.first;
    final extras = photos.skip(1).toList(growable: false);
    if (extras.isEmpty) {
      base.remove('photos');
    } else {
      base['photos'] = extras;
    }
    return SerializedPhotos(
      primary: primary,
      detailsJson: jsonEncode(base),
    );
  }

  final String? primary;
  final String detailsJson;

  static Map<String, dynamic> _decodeOrEmpty(String? raw) {
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return Map<String, dynamic>.from(decoded);
      if (decoded is Map) {
        return {for (final e in decoded.entries) e.key.toString(): e.value};
      }
    } on FormatException {
      // fall through
    }
    return <String, dynamic>{};
  }
}
