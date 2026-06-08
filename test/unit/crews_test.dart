import 'package:differentworld/features/world/crews.dart';
import 'package:flutter_test/flutter_test.dart';

/// The crew catalog — the one chosen element of the character sheet. A closed
/// set (no rarity, fully reachable) per the human-first design call.
void main() {
  test('crewById resolves known ids, null for unknown / null', () {
    expect(crewById('explorer')?.name, 'Explorer');
    expect(crewById('builder')?.emoji, '🔨');
    expect(crewById('nope'), isNull);
    expect(crewById(null), isNull);
  });

  test('the catalog has unique ids and complete fields', () {
    final ids = kCrews.map((c) => c.id).toList();
    expect(ids.toSet().length, ids.length, reason: 'duplicate crew id');
    for (final c in kCrews) {
      expect(c.id, isNotEmpty);
      expect(c.emoji, isNotEmpty);
      expect(c.name, isNotEmpty);
      expect(c.blurb, isNotEmpty);
    }
  });
}
