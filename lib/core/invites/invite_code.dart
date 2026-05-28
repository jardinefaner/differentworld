import 'dart:math';

/// Invite-code utilities.
///
/// Codes are short (6 chars) so a director can read one over the phone or
/// type it from a sticky note. The alphabet excludes visually-ambiguous
/// characters (0/O, 1/I/L) so handoff doesn't fail at the last step.
///
/// 30 chars × 6 positions = ~729M codes. With our scale (a handful of
/// pending invites per program, ever) collisions are not a meaningful
/// risk — but `createInvite` still wraps the insert; the unique
/// constraint on `invites.code` is the real guarantee.
abstract final class InviteCode {
  static const String _alphabet =
      'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; // no 0, O, 1, I, L

  static const int _length = 6;

  static final Random _rng = Random.secure();

  /// Returns a random 6-character code using the unambiguous alphabet.
  static String generate() {
    final buf = StringBuffer();
    for (var i = 0; i < _length; i++) {
      buf.write(_alphabet[_rng.nextInt(_alphabet.length)]);
    }
    return buf.toString();
  }

  /// Normalises user-typed input: uppercase, strip separators, and
  /// drop any character that isn't part of the code alphabet. This
  /// runs both on UI input (where a `FilteringTextInputFormatter`
  /// already guards) and on the deep-link path (where the URL could
  /// carry anything), so the alphabet check is the real guard.
  static String normalize(String input) {
    final upper = input.toUpperCase();
    final cleaned = StringBuffer();
    for (final rune in upper.runes) {
      final c = String.fromCharCode(rune);
      if (_alphabet.contains(c)) cleaned.write(c);
    }
    return cleaned.toString();
  }

  /// Custom-scheme form of the invite deep link — registered in
  /// AndroidManifest.xml + ios/Runner/Info.plist. The in-app
  /// listener still accepts this (via `extractFromUri`), but Wave
  /// 165.3 stopped putting it in QR codes / share text because
  /// several Android camera apps treat custom schemes as plain text
  /// and fall through to a browser 404. Use [httpsLinkFor] instead
  /// for anything that leaves the app.
  static String deepLinkFor(String code) => 'differentworld://invite/$code';

  /// HTTPS form — what we put in QR codes, SMS share text, and email.
  /// Pairs with the static fallback page hosted at
  /// `differentworld.app/404.html`, which JS-redirects into the
  /// custom scheme when the app is installed and falls back to an
  /// "Open in app" affordance when it isn't.
  static String httpsLinkFor(String code) =>
      'https://differentworld.app/invite/$code';

  /// Wave 170: github.io project-page URL used while DNS for
  /// differentworld.app is unresolved. Revert callers to
  /// [httpsLinkFor] once DNS lands.
  static String pagesLinkFor(String code) =>
      'https://jardinefaner.github.io/differentworld-web/invite/$code';

  /// Plain-text share blurb a director can copy / SMS / paste.
  /// Includes both the human-typeable code AND the HTTPS link
  /// (clickable from iMessage, SMS, email, Slack — anywhere).
  ///
  /// Wave 170: uses [pagesLinkFor] while DNS is unresolved. Swap
  /// back to [httpsLinkFor] once differentworld.app routes.
  static String shareTextFor({required String code, String? programName}) {
    final lead = programName == null
        ? 'Join my Different World program.'
        : 'Join $programName on Different World.';
    return '$lead\n\nCode: $code\n\n${pagesLinkFor(code)}';
  }

  /// Extract a code from an inbound deep link. Accepts:
  ///   - the custom scheme `differentworld://invite/ABC123`
  ///   - the apex HTTPS form `https://differentworld.app/invite/ABC123`
  ///   - the github.io project-page form (Wave 170)
  ///     `https://jardinefaner.github.io/differentworld-web/invite/ABC123`
  /// Returns null if the URI doesn't match any of the three.
  static String? extractFromUri(Uri uri) {
    final isCustomScheme =
        uri.scheme == 'differentworld' && uri.host == 'invite';
    final isHttpsApex = uri.scheme == 'https' &&
        uri.host == 'differentworld.app' &&
        uri.pathSegments.isNotEmpty &&
        uri.pathSegments.first == 'invite';
    final isHttpsPages = uri.scheme == 'https' &&
        uri.host == 'jardinefaner.github.io' &&
        uri.pathSegments.length >= 2 &&
        uri.pathSegments[0] == 'differentworld-web' &&
        uri.pathSegments[1] == 'invite';
    if (!isCustomScheme && !isHttpsApex && !isHttpsPages) return null;

    final segments = uri.pathSegments;
    // For differentworld://invite/CODE the segments are ['CODE'].
    // For https://differentworld.app/invite/CODE: ['invite', 'CODE'].
    // For https://jardinefaner.github.io/differentworld-web/invite/CODE:
    // ['differentworld-web', 'invite', 'CODE'].
    final String raw;
    if (isCustomScheme) {
      raw = segments.isEmpty ? '' : segments.last;
    } else if (isHttpsApex) {
      raw = segments.length < 2 ? '' : segments[1];
    } else {
      raw = segments.length < 3 ? '' : segments[2];
    }
    if (raw.isEmpty) return null;
    final normalized = normalize(raw);
    return normalized.isEmpty ? null : normalized;
  }
}
