import 'package:differentworld/features/action_words/action_words_providers.dart';
import 'package:differentworld/features/action_words/day_run.dart';
import 'package:differentworld/features/action_words/verbs.dart';
import 'package:differentworld/features/action_words/worlds.dart';

World? _worldById(String id) {
  for (final w in kNamedWorlds) {
    if (w.id == id) return w;
  }
  return null;
}

/// The child's **growth arc** — their whole story so far, compiled into a
/// castable run of beats on the shared present spine (the same surface as
/// `/play-today`, `/arc`, `/journey`). This is the "drawing becomes a film"
/// idea done as an in-app compilation (docs/VISION.md, the showcase): NOT a
/// rendered mp4, but the *story* of who they became — the words they lived
/// most, the worlds they collected, their emerging title — auto-curated from
/// the data already on the device. Cast it to the room or send it home.
///
/// Pure + deterministic so it's unit-testable and can cross the cast wire.
/// Sourced entirely from [ActionWordsCollection] (their every `action_words`
/// day), so it needs no network and no media pipeline — photos are a deferred
/// enhancement (a future `DayBeatKind.photo` + signed-URL beat).
List<DayBeat> buildGrowthArc({
  required String firstName,
  required ActionWordsCollection collection,
}) {
  final name = firstName.trim().isEmpty ? 'You' : firstName.trim();

  // Nothing collected yet — a gentle "your story starts" arc instead of an
  // empty reel.
  if (collection.dayCount == 0) {
    return [
      DayBeat(
        kind: DayBeatKind.open,
        label: 'A story begins',
        big: name,
        sub: 'Your story starts today.',
        emoji: '🌱',
      ),
      const DayBeat(
        kind: DayBeatKind.close,
        label: 'And then',
        big: 'Pick three words.',
        sub: 'Live them. Discover who you become.',
      ),
    ];
  }

  // Most-practiced verbs, most first (stable alphabetical tiebreak).
  final verbEntries = collection.verbTotals.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      return byCount != 0 ? byCount : a.key.compareTo(b.key);
    });
  final topVerbLines = <String>[
    for (final e in verbEntries.take(4))
      if (verbById(e.key) case final v?) '${v.emoji}  ${v.label}  ·  ${e.value}×',
  ];

  // Most-visited worlds, most first.
  final worldEntries = collection.worldCounts.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      return byCount != 0 ? byCount : a.key.compareTo(b.key);
    });

  return [
    DayBeat(
      kind: DayBeatKind.open,
      label: 'The story so far',
      big: name,
      sub: '${collection.dayCount} '
          '${collection.dayCount == 1 ? 'day' : 'days'}. '
          'Three words each. Lived.',
      emoji: '✨',
    ),
    if (topVerbLines.isNotEmpty)
      DayBeat(
        kind: DayBeatKind.verbs,
        label: 'The words you lived most',
        lines: topVerbLines,
      ),
    for (final e in worldEntries.take(5))
      if (_worldById(e.key) case final w?)
        DayBeat(
          kind: DayBeatKind.open,
          label: '${e.value} ${e.value == 1 ? 'day' : 'days'} as',
          big: w.name,
          sub: w.title,
          emoji: w.emoji,
        ),
    if (collection.collectedWorlds > 0)
      DayBeat(
        kind: DayBeatKind.open,
        label: 'Worlds collected',
        big: '${collection.collectedWorlds}',
        sub: 'different worlds you became',
        emoji: '🌍',
      ),
    if (collection.emergingTitle case final title?)
      DayBeat(
        kind: DayBeatKind.name,
        label: 'Who you are becoming',
        big: title,
        sub: 'Your emerging title',
      ),
    const DayBeat(
      kind: DayBeatKind.close,
      label: 'And then',
      big: 'The story continues.',
      sub: 'Tomorrow, you choose again.',
    ),
  ];
}
