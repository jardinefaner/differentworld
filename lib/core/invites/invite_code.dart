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

  /// Deep-link URI for a code. The receiver app responds to this scheme
  /// (Pass 2: app_links wiring + manifest filters). For now the string
  /// is what we embed in QR codes and share-sheet text.
  static String deepLinkFor(String code) =>
      'https://differentworld.app/invite/$code';

  /// Plain-text share blurb a director can copy / SMS / paste.
  static String shareTextFor({required String code, String? programName}) {
    final lead = programName == null
        ? 'Join my Different World program.'
        : 'Join $programName on Different World.';
    return '$lead\n\nCode: $code\n\n${deepLinkFor(code)}';
  }
}
