import 'package:differentworld/features/action_words/verbs.dart';
import 'package:differentworld/features/activity_forge/activity_forge.dart';
import 'package:flutter_test/flutter_test.dart';

/// The activity forge — the user's #3 novelty made real: a formula, not a
/// list. verb × noun × constraint × time, recombined deterministically.
void main() {
  test('forge is deterministic — same seed, same activity', () {
    final a = forgeActivity(42);
    final b = forgeActivity(42);
    expect(a.instruction, b.instruction);
    expect(a.verb.id, b.verb.id);
    expect(a.minutes, b.minutes);
  });

  test('consecutive seeds change the noun (rolls feel different)', () {
    // The odometer turns the noun fastest, so seed+1 always swaps the noun.
    final a = forgeActivity(0, verbId: 'carry');
    final b = forgeActivity(1, verbId: 'carry');
    expect(a.noun, isNot(b.noun));
  });

  test('a locked verb is honoured; an unknown id falls back', () {
    expect(forgeActivity(7, verbId: 'listen').verb.id, 'listen');
    // Unknown id → still produces a real verb (seed-picked), never crashes.
    final f = forgeActivity(7, verbId: 'not-a-verb');
    expect(kVerbs.map((v) => v.id), contains(f.verb.id));
  });

  test('every part comes from its catalog; instruction is well-formed', () {
    for (var s = 0; s < 200; s++) {
      final f = forgeActivity(s);
      expect(kForgeNouns, contains(f.noun));
      expect(kForgeConstraints, contains(f.constraint));
      expect(kForgeTimes, contains(f.minutes));
      expect(kVerbs.map((v) => v.id), contains(f.verb.id));
      // "Verb noun constraint." — ends with a period, no empty pieces.
      expect(f.instruction.endsWith('.'), isTrue);
      expect(f.instruction.contains(f.noun), isTrue);
      expect(f.instruction.contains(f.constraint), isTrue);
    }
  });

  test('world nouns make the forge context-bound', () {
    final water = kWorldNouns['water']!;
    for (var s = 0; s < 50; s++) {
      final f = forgeActivity(s, verbId: 'flow', nouns: water);
      expect(water, contains(f.noun), reason: 'noun must come from the world');
    }
    // Every curriculum world has a non-trivial noun set.
    const worldIds = [
      'me',
      'stories',
      'nature',
      'water',
      'music',
      'space',
      'dreams',
      'time',
      'feelings',
      'us',
    ];
    for (final id in worldIds) {
      expect(kWorldNouns[id], isNotNull, reason: '$id has no nouns');
      expect(kWorldNouns[id]!.length, greaterThanOrEqualTo(6));
    }
    // An empty/absent list falls back to the general nouns (never crashes).
    expect(kForgeNouns, contains(forgeActivity(0, nouns: const []).noun));
  });

  test('the space is large — a formula, not a finite library', () {
    // 12 verbs × 26 nouns × 18 constraints × 4 times.
    expect(ForgedActivity.space, greaterThan(20000));
    expect(
      ForgedActivity.space,
      kVerbs.length *
          kForgeNouns.length *
          kForgeConstraints.length *
          kForgeTimes.length,
    );
  });

  test('negative seeds are handled (abs), never crash or index-out', () {
    final f = forgeActivity(-99);
    expect(kForgeNouns, contains(f.noun));
  });
}
