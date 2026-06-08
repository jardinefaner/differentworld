import 'dart:convert';
import 'dart:io';

import 'package:differentworld/features/action_words/spell_words.dart';
import 'package:flutter_test/flutter_test.dart';

/// The spell-words catalog — the daily word + the printed gold word-cards.
void main() {
  List<SpellWord> load() {
    final raw = File('assets/curriculum/spell_words.json').readAsStringSync();
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return [
      for (final w in decoded['words'] as List)
        SpellWord.fromJson(w as Map<String, dynamic>),
    ];
  }

  test('the catalog loads 30 complete words (incl. LUMINOUS)', () {
    final words = load();
    expect(words.length, 30);
    for (final w in words) {
      expect(w.word, isNotEmpty);
      expect(w.meaning, isNotEmpty);
      expect(w.gesture, isNotEmpty, reason: '${w.word} has no gesture');
    }
    // THE_DAY.md's worked example.
    expect(words.any((w) => w.word == 'LUMINOUS'), isTrue);
  });

  test('wordForDay is deterministic and covers the whole catalog', () {
    final words = load();
    // Same day → same word.
    expect(
      wordForDay(words, DateTime(2026, 6, 8))?.word,
      wordForDay(words, DateTime(2026, 6, 8))?.word,
    );
    // 30 consecutive days touch all 30 words.
    final seen = <String>{};
    for (var i = 0; i < words.length; i++) {
      final w = wordForDay(words, DateTime(2026).add(Duration(days: i)));
      if (w != null) seen.add(w.word);
    }
    expect(seen.length, words.length);
  });

  test('empty catalog → null', () {
    expect(wordForDay(const [], DateTime(2026, 6, 8)), isNull);
  });
}
