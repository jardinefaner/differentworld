// Pins the sensory "become it" (docs/ACTION_WORDS.md "culture becomes
// activity"): every catalog world has beats; invented/fresh worlds get a
// generic embodiment from their verbs.

import 'package:differentworld/features/action_words/senses.dart';
import 'package:differentworld/features/action_words/worlds.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every catalog world has at least one sensory become beat', () {
    for (final w in kNamedWorlds) {
      expect(kWorldBecome[w.id], isNotNull, reason: w.id);
      expect(kWorldBecome[w.id], isNotEmpty, reason: w.id);
    }
  });

  test('becomeFor a named world returns its authored beats', () {
    final dolphin = matchWorld({'play', 'echo', 'flow'});
    final beats = becomeFor(dolphin);
    expect(beats, kWorldBecome['dolphin']);
    expect(beats.any((b) => b.sense == Sense.move), isTrue);
  });

  test('becomeFor a fresh world is a generic embodiment of its verbs', () {
    final fresh = matchWorld({'carry', 'echo', 'solve'}); // no named world
    final beats = becomeFor(fresh);
    expect(beats.length, 3); // one per verb
    expect(beats.every((b) => b.sense == Sense.move), isTrue);
    expect(beats.first.prompt.toLowerCase(), contains('carry'));
  });
}
