import 'dart:convert';
import 'dart:math';

/// The fair-draw core of the name picker (`/picker`) — pure, persisted as
/// JSON, pinned by unit tests.
///
/// The rule the whole tool exists for: **everyone gets picked before anyone
/// repeats.** A bag holds the room's shuffled ids; draws take from the
/// front; when the bag empties it refills with a fresh shuffle (a new
/// round). The bag survives app restarts (SharedPreferences, per room) and
/// re-syncs against the eligible roster every build, so kids joining,
/// leaving, or being absent today never break fairness.
class FairBag {
  const FairBag({required this.remaining, required this.picked});

  factory FairBag.fresh(List<String> roster, Random rng) {
    final shuffled = List.of(roster)..shuffle(rng);
    return FairBag(remaining: shuffled, picked: const []);
  }

  factory FairBag.fromJson(String json) {
    final m = jsonDecode(json) as Map<String, dynamic>;
    return FairBag(
      remaining: [for (final id in (m['remaining'] as List? ?? [])) '$id'],
      picked: [for (final id in (m['picked'] as List? ?? [])) '$id'],
    );
  }

  /// Ids not yet drawn this round, in draw order.
  final List<String> remaining;

  /// Ids already drawn this round, oldest first.
  final List<String> picked;

  String toJson() => jsonEncode({'remaining': remaining, 'picked': picked});

  /// Reconcile with today's eligible roster: departed/absent ids drop out
  /// of both piles; new ids slot into the remaining pile at random spots
  /// (never at guaranteed positions — that would be gameable by the kids
  /// who watch the list).
  FairBag syncedWith(List<String> eligible, Random rng) {
    final known = {...remaining, ...picked};
    final keptRemaining = [
      for (final id in remaining)
        if (eligible.contains(id)) id,
    ];
    final keptPicked = [
      for (final id in picked)
        if (eligible.contains(id)) id,
    ];
    final fresh = [
      for (final id in eligible)
        if (!known.contains(id)) id,
    ];
    for (final id in fresh) {
      keptRemaining.insert(rng.nextInt(keptRemaining.length + 1), id);
    }
    return FairBag(remaining: keptRemaining, picked: keptPicked);
  }

  /// Draw [n] names. If the bag runs dry mid-draw it refills with a fresh
  /// shuffle of [eligible] minus the names already drawn IN THIS CALL (so a
  /// two-kid draw can never hand the same kid both slots). Returns the new
  /// bag, the drawn ids, and whether a new round started.
  ({FairBag bag, List<String> drawn, bool refilled}) draw(
    int n,
    List<String> eligible,
    Random rng,
  ) {
    var rem = List.of(remaining);
    var pick = List.of(picked);
    final drawn = <String>[];
    var refilled = false;
    final want = n.clamp(0, eligible.length);
    while (drawn.length < want) {
      if (rem.isEmpty) {
        // New round: everyone's been picked. Reshuffle everyone except
        // whoever was just drawn in this same call.
        rem = [
          for (final id in eligible)
            if (!drawn.contains(id)) id,
        ]..shuffle(rng);
        pick = [];
        refilled = true;
        if (rem.isEmpty) break;
      }
      final id = rem.removeAt(0);
      drawn.add(id);
      pick.add(id);
    }
    return (
      bag: FairBag(remaining: rem, picked: pick),
      drawn: drawn,
      refilled: refilled,
    );
  }
}

/// Even team split: shuffle, then deal round-robin so sizes differ by at
/// most one. Returns [teams] lists (fewer if the roster is smaller).
List<List<String>> splitTeams(List<String> ids, int teams, Random rng) {
  final n = teams.clamp(1, ids.isEmpty ? 1 : ids.length);
  final shuffled = List.of(ids)..shuffle(rng);
  final out = List.generate(n, (_) => <String>[]);
  for (var i = 0; i < shuffled.length; i++) {
    out[i % n].add(shuffled[i]);
  }
  return out;
}

/// Calm nature names for teams, in a stable order.
const List<String> kTeamNames = [
  'River',
  'Mountain',
  'Forest',
  'Meadow',
  'Ocean',
  'Canyon',
];
