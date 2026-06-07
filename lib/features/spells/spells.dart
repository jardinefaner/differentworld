import 'package:flutter/foundation.dart';

/// One translation of a spell — the same command in another language.
/// Spells are "words in different languages" (the user's direction): over
/// a term a class learns each spell across languages — growth that stays
/// unhidden (docs/ACTION_WORDS.md).
@immutable
class SpellWord {
  const SpellWord({
    required this.word,
    required this.language,
    required this.pronunciation,
    required this.meaning,
  });

  final String word;
  final String language;

  /// A simple phonetic hint a non-speaker can say aloud.
  final String pronunciation;
  final String meaning;
}

/// A spell — a timer command shown fullscreen (the brief's only loud
/// moment): a big emoji, the foreign word, and a breathing countdown.
@immutable
class Spell {
  const Spell({
    required this.id,
    required this.english,
    required this.emoji,
    required this.durationSeconds,
    required this.words,
  });

  final String id;

  /// The plain-English command (FREEZE, MOVE, …) — shown small under the
  /// foreign word.
  final String english;
  final String emoji;
  final int durationSeconds;

  /// Translations, in display order. A program extends these with its own
  /// languages over time (continuity / their own culture).
  final List<SpellWord> words;
}

/// The five spells (the brief), each carrying a starter set of confident,
/// simple translations. **Programs own and extend these** — add languages
/// your room speaks; that vocabulary is part of the culture they build.
const List<Spell> kSpells = [
  Spell(
    id: 'freeze',
    english: 'FREEZE',
    emoji: '❄️',
    durationSeconds: 300,
    words: [
      SpellWord(word: 'Alto', language: 'Spanish', pronunciation: 'AHL-toh', meaning: 'stop'),
      SpellWord(word: 'Arrête', language: 'French', pronunciation: 'ah-RET', meaning: 'stop'),
      SpellWord(word: 'Simama', language: 'Swahili', pronunciation: 'see-MAH-mah', meaning: 'stand still'),
    ],
  ),
  Spell(
    id: 'move',
    english: 'MOVE',
    emoji: '🏃',
    durationSeconds: 180,
    words: [
      SpellWord(word: 'Vamos', language: 'Spanish', pronunciation: 'VAH-mohs', meaning: "let's go"),
      SpellWord(word: 'Allez', language: 'French', pronunciation: 'ah-LAY', meaning: 'go'),
      SpellWord(word: 'Twende', language: 'Swahili', pronunciation: 'TWEN-deh', meaning: "let's go"),
    ],
  ),
  Spell(
    id: 'create',
    english: 'CREATE',
    emoji: '🎨',
    durationSeconds: 300,
    words: [
      SpellWord(word: 'Crea', language: 'Spanish', pronunciation: 'KREH-ah', meaning: 'create'),
      SpellWord(word: 'Crée', language: 'French', pronunciation: 'kray', meaning: 'create'),
      SpellWord(word: 'Tengeneza', language: 'Swahili', pronunciation: 'ten-geh-NEH-zah', meaning: 'make'),
    ],
  ),
  Spell(
    id: 'share',
    english: 'SHARE',
    emoji: '🤝',
    durationSeconds: 180,
    words: [
      SpellWord(word: 'Comparte', language: 'Spanish', pronunciation: 'kom-PAR-teh', meaning: 'share'),
      SpellWord(word: 'Partage', language: 'French', pronunciation: 'par-TAHZH', meaning: 'share'),
      SpellWord(word: 'Shiriki', language: 'Swahili', pronunciation: 'shee-REE-kee', meaning: 'take part'),
    ],
  ),
  Spell(
    id: 'wonder',
    english: 'WONDER',
    emoji: '🌌',
    durationSeconds: 180,
    words: [
      SpellWord(word: 'Imagina', language: 'Spanish', pronunciation: 'ee-mah-HEE-nah', meaning: 'imagine'),
      SpellWord(word: 'Imagine', language: 'French', pronunciation: 'ee-mah-ZHEEN', meaning: 'imagine'),
      SpellWord(word: 'Fikiria', language: 'Swahili', pronunciation: 'fee-kee-REE-ah', meaning: 'imagine'),
    ],
  ),
];

/// Which translation to show for [spell] on [dayKey] — deterministic by
/// day (stable within a day, varies across days) so the class meets the
/// spell in a different language as the term goes on. Uses a sum-of-code-
/// units hash so it's stable across runs/platforms (unlike String.hashCode).
SpellWord spellWordForDay(Spell spell, String dayKey) {
  if (spell.words.length == 1) return spell.words.first;
  var h = 0;
  for (final c in dayKey.codeUnits) {
    h += c;
  }
  // Offset by the spell id too, so all five aren't the same language each
  // day.
  for (final c in spell.id.codeUnits) {
    h += c;
  }
  return spell.words[h % spell.words.length];
}

String spellTimeLabel(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}
