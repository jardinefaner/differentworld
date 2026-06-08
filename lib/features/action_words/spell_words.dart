import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A **spell word** — a beautiful word a child earns by using it three times in
/// a day (THE_DAY.md: "use it 3 times today and it's yours"). The catalog
/// drives the daily word AND the printed gold word-cards (docs/ASSETS.md):
/// word on the front, meaning + gesture + "use 3× to earn" on the back. Bundled
/// JSON; no migration. Programs can extend the list.
class SpellWord {
  const SpellWord({
    required this.word,
    required this.meaning,
    required this.gesture,
  });

  factory SpellWord.fromJson(Map<String, dynamic> j) => SpellWord(
    word: (j['word'] as String?)?.trim() ?? '',
    meaning: (j['meaning'] as String?)?.trim() ?? '',
    gesture: (j['gesture'] as String?)?.trim() ?? '',
  );

  final String word;
  final String meaning;

  /// A physical action that teaches the word — printed on the card back.
  final String gesture;
}

/// The bundled spell-word catalog.
final spellWordsProvider = FutureProvider<List<SpellWord>>((ref) async {
  final raw = await rootBundle.loadString(
    'assets/curriculum/spell_words.json',
  );
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) return const <SpellWord>[];
  return [
    for (final w in (decoded['words'] as List? ?? const []))
      if (w is Map<String, dynamic>) SpellWord.fromJson(w),
  ];
});

/// Today's word — a deterministic day-of-year rotation so the whole room shares
/// one "word of the day" without anyone choosing (mirrors `skillForDay`).
SpellWord? wordForDay(List<SpellWord> words, DateTime now) {
  if (words.isEmpty) return null;
  final day = now.difference(DateTime(now.year)).inDays;
  return words[day.abs() % words.length];
}
