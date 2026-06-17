/// A stable 4-char cast code in the ambiguity-free alphabet the manual fallback
/// uses (a not-signed-in spare device can still type it). A hash of the seed,
/// not the raw id — stable, but it doesn't leak the uuid on the screen.
String _castCode(String seed) {
  const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  // FNV-1a (32-bit) → a stable 4-char code.
  var hash = 0x811c9dc5;
  for (final unit in seed.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  final out = StringBuffer();
  for (var i = 0; i < 4; i++) {
    out.write(chars[hash % chars.length]);
    hash ~/= chars.length;
  }
  return out.toString();
}

/// THE controller's stable code (docs/LIVE_SESSIONS.md — "one controller, many
/// receivers"). The controller — a phone driving the cast — broadcasts on its
/// own code; screens FOLLOW a controller by entering it. Keyed on the member
/// id, so it's stable per person AND a screen signed into the SAME account
/// derives the same code and auto-follows (no typing). A different-account
/// screen types the controller's code once.
String castCodeForController(String memberId) => _castCode(memberId);
