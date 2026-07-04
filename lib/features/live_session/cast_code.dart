/// A stable cast code in the ambiguity-free alphabet the manual fallback uses
/// (a spare device can still type it). A hash of the seed, not the raw ids —
/// stable, but it doesn't leak the uuid on the screen. 6 chars (~730M combos)
/// so a guessed code is impractical; Realtime channels aren't RLS-gated, so the
/// code's entropy IS the gate until true channel auth lands (see note below).
String _castCode(String seed) {
  const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  // FNV-1a (64-bit) over the seed → a stable 6-char code. 64-bit so the extra
  // chars carry real entropy (a 32-bit hash only has ~4.3B states ≈ 6.5 chars
  // of headroom; 64-bit comfortably fills 6).
  var hash = BigInt.parse('14695981039346656037'); // FNV offset basis
  final prime = BigInt.from(1099511628211);
  final mask = (BigInt.one << 64) - BigInt.one;
  for (final unit in seed.codeUnits) {
    hash = (hash ^ BigInt.from(unit)) & mask;
    hash = (hash * prime) & mask;
  }
  final base = BigInt.from(chars.length);
  final out = StringBuffer();
  for (var i = 0; i < 6; i++) {
    out.write(chars[(hash % base).toInt()]);
    hash = hash ~/ base;
  }
  return out.toString();
}

/// THE controller's stable code (docs/LIVE_SESSIONS.md — "one controller, many
/// receivers"). The controller — a phone driving the cast — broadcasts on its
/// own code; screens FOLLOW a controller by entering it. Seeded with BOTH the
/// space and the member, so:
///   * it's stable per person, and a screen signed into the SAME account
///     auto-derives the same code (no typing);
///   * it's PROGRAM-SCOPED — two programs' controllers can never collide on a
///     channel, and the space id (not in the code) is extra entropy a guesser
///     doesn't have.
///
/// SECURITY NOTE: Supabase Realtime channels are not RLS-gated, so today the
/// 6-char code's entropy is the only gate — fine for ephemeral coordination
/// (which slide is up), but BEFORE casting kid-identifying content (names,
/// drawings, the Reveal) we should add true channel auth (a member-scoped
/// token / Realtime authorize callback). Tracked in docs/LIVE_SESSIONS.md.
String castCodeForController({
  required String memberId,
  required String spaceId,
}) => _castCode('$spaceId:$memberId');
