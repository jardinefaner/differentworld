// Pins the spell catalog + the deterministic day→language pick + the
// timer label (docs/ACTION_WORDS.md "spells are words in other languages").

import 'package:differentworld/features/spells/spells.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the spell catalog', () {
    test('five spells, each with translations + a positive duration', () {
      expect(kSpells.length, 5);
      for (final s in kSpells) {
        expect(s.words, isNotEmpty, reason: s.id);
        expect(s.durationSeconds, greaterThan(0), reason: s.id);
        expect(s.emoji, isNotEmpty);
        for (final w in s.words) {
          expect(w.word, isNotEmpty);
          expect(w.meaning, isNotEmpty);
          expect(w.language, isNotEmpty);
        }
      }
      expect(kSpells.map((s) => s.id).toSet().length, 5);
    });
  });

  group('spellWordForDay', () {
    test('is deterministic within a day and returns a real translation', () {
      for (final s in kSpells) {
        final a = spellWordForDay(s, '2026-06-06');
        final b = spellWordForDay(s, '2026-06-06');
        expect(a.word, b.word); // stable within a day
        expect(s.words.contains(a), isTrue); // always a real translation
      }
    });

    test('varies across days for a multi-language spell', () {
      final freeze = kSpells.firstWhere((s) => s.id == 'freeze');
      final picks = <String>{
        for (var d = 1; d <= 28; d++)
          spellWordForDay(freeze, '2026-06-${d.toString().padLeft(2, '0')}')
              .word,
      };
      // Over a month it should land on more than one language.
      expect(picks.length, greaterThan(1));
    });
  });

  group('spellTimeLabel', () {
    test('formats m:ss', () {
      expect(spellTimeLabel(300), '5:00');
      expect(spellTimeLabel(180), '3:00');
      expect(spellTimeLabel(65), '1:05');
      expect(spellTimeLabel(9), '0:09');
      expect(spellTimeLabel(0), '0:00');
    });
  });
}
