import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The Supabase Storage bucket that holds every person-attached photo
/// (members, subjects, observation attachments). Mirrors the const
/// `_bucket` inside `photo_service.dart` — kept duplicated as a
/// private const so this file has no upward dependency on
/// photo_service.dart.
const String _bucket = 'person-photos';

/// How long signed URLs are minted for. One hour is the sweet spot:
/// long enough that the URL stays valid across a typical list-scroll +
/// detail-pop, short enough that a leaked URL stops working within a
/// usable session window. Riverpod caches the URL in memory while at
/// least one widget watches it, so a single signed-URL request can
/// serve every avatar / gallery render of the same photo for that
/// hour.
const int _signedUrlTtlSeconds = 60 * 60;

/// Pull the Storage path out of either a path-shaped value (new
/// writes) or an old-style public URL (rows written before the
/// bucket-private flip). Returns `null` if the input is empty, a
/// `pending:` placeholder (offline-queued upload, no remote bytes
/// yet), or otherwise unresolvable.
///
/// Old public URLs look like:
///   `https://PROJECT.supabase.co/storage/v1/object/public/person-photos/SPACE_ID/...`
/// We strip everything through `…/person-photos/` and keep the rest.
///
/// New writes already store the path (e.g.
/// `<space_id>/subject/<id>/<uuid>.jpg`) so this is a no-op for them.
@visibleForTesting
String? extractPersonPhotoPath(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.startsWith('pending:')) return null;

  // Either form of stored URL — public or signed — embeds the bucket
  // name as a literal path segment somewhere in the middle.
  const marker = '/$_bucket/';
  final idx = trimmed.indexOf(marker);
  if (idx >= 0) {
    final after = trimmed.substring(idx + marker.length);
    // Strip any query string the signed-URL form would have appended.
    final qIdx = after.indexOf('?');
    return qIdx >= 0 ? after.substring(0, qIdx) : after;
  }

  // No URL prefix — assume the caller already stored the bare path.
  // Light sanity check: paths always start with a space_id segment;
  // a value like `https://other-bucket/foo` would NOT contain
  // `/person-photos/`, so we shouldn't reach here for foreign URLs.
  // If it does, downstream createSignedUrl will throw and we'll fall
  // back to the placeholder.
  return trimmed;
}

/// Mint a signed Storage URL for a person-photo path. Returns null
/// when the input is empty / pending / unresolvable. Widgets watch
/// this and render a placeholder while loading / on error.
///
/// Why `autoDispose.family`: each unique stored value gets its own
/// cached URL. When no widget is listening for a given key (e.g. the
/// avatar scrolled out of view a long time ago), Riverpod evicts —
/// the next view re-mints. Memory bounded to "URLs currently
/// on-screen".
///
/// One-hour TTL means a watching widget hangs onto the same URL
/// across hot-reloads, list re-fetches, and drawer toggles without
/// re-requesting.
// ignore: specify_nonobvious_property_types
final signedPersonPhotoUrlProvider =
    FutureProvider.autoDispose.family<String?, String?>(
  (ref, urlOrPath) async {
    final path = extractPersonPhotoPath(urlOrPath);
    if (path == null) return null;
    try {
      final supabase = Supabase.instance.client;
      final signed = await supabase.storage
          .from(_bucket)
          .createSignedUrl(path, _signedUrlTtlSeconds);
      // Hold the result in cache for the URL's lifetime — slightly
      // less than the server TTL to avoid handing out a URL that
      // expires mid-render.
      final link = ref.keepAlive();
      Timer(
        const Duration(seconds: _signedUrlTtlSeconds - 60),
        link.close,
      );
      return signed;
    } catch (e, st) {
      // Don't crash on a 404 / RLS denial — return null and let the
      // widget fall through to its placeholder. We DO log so the
      // problem is visible during development; in production the
      // same context reaches the crash reporter via reportError.
      if (kDebugMode) {
        debugPrint(
          '[signed-url] failed for path=$path · $e',
        );
      }
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: e,
          stack: st,
          library: 'person-photo signed URL',
        ),
      );
      return null;
    }
  },
);
