/// The STABLE cast channel code for a program (space). The room screen and
/// every phone in the same program derive the SAME code from the space id, so
/// they land on one Realtime channel with no pairing — the "set the screen
/// once, then just cast" model (docs/LIVE_SESSIONS.md).
///
/// A 4-char code in the ambiguity-free alphabet the manual fallback uses, so a
/// not-signed-in spare device can still type it. It's a hash of the space id,
/// not the raw uuid — stable per program, but not the id itself on the screen.
String castCodeForSpace(String spaceId) {
  const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  // FNV-1a (32-bit) over the space id → a stable 4-char code.
  var hash = 0x811c9dc5;
  for (final unit in spaceId.codeUnits) {
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
