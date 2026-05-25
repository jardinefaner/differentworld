import 'package:supabase_flutter/supabase_flutter.dart';

/// The Storage bucket that holds rendered exports (progress reports,
/// future yearly reviews, etc.).
const String _bucket = 'exports';

/// TTL for export signed URLs. 10 minutes — enough for the user to
/// tap → launchUrl → external app load, short enough that a leaked
/// URL stops working within a usable session window.
const int _signedUrlTtlSeconds = 10 * 60;

/// Mint a short-lived signed URL for an export PDF stored at [path].
///
/// One-shot helper (not a provider) because exports are opened via a
/// user-tap → `launchUrl` flow, not a rebuilding widget watch. Pairs
/// with `signedPersonPhotoUrlProvider` as the canonical place each
/// Storage bucket lives — UI code never reaches into
/// `Supabase.instance.client.storage` directly.
Future<String> mintExportSignedUrl(String path) {
  return Supabase.instance.client.storage
      .from(_bucket)
      .createSignedUrl(path, _signedUrlTtlSeconds);
}
