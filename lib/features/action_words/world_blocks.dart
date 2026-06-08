import 'dart:convert';

import 'package:differentworld/features/action_words/world_schedule.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One authored day of the 50-day journey — its title and the day's focus
/// (the minute-by-minute intent staff read before the room opens). The `day`
/// is the program-day number (1–50), independent of calendar date.
@immutable
class JourneyDay {
  const JourneyDay({
    required this.day,
    required this.title,
    required this.focus,
  });

  factory JourneyDay.fromJson(Map<String, dynamic> j) => JourneyDay(
        day: (j['day'] as num?)?.toInt() ?? 0,
        title: (j['title'] as String?) ?? '',
        focus: (j['focus'] as String?) ?? '',
      );

  final int day;
  final String title;
  final String focus;
}

/// One two-week "world" of the 50-day journey — the environment the room
/// becomes, the words for the wall, the bank of questions, the key moment,
/// and its ten authored days.
///
/// This is the narrative layer ABOVE the 10-week curriculum: where
/// `ten_worlds.json` (`CurriculumWorld`) is the verb / facet / activity
/// catalog, `world_blocks.json` is the *lived experience* — what the room
/// looks and sounds like, the arrival ritual, the transition out. Five blocks
/// of ten days each = the whole summer. Loaded from the bundle (offline-first).
@immutable
class WorldBlock {
  const WorldBlock({
    required this.name,
    required this.emoji,
    required this.color,
    required this.weeks,
    required this.arrival,
    required this.room,
    required this.soundtrack,
    required this.words,
    required this.wallQuestions,
    required this.keyMoment,
    required this.transition,
    required this.days,
  });

  factory WorldBlock.fromJson(Map<String, dynamic> j) => WorldBlock(
        name: (j['name'] as String?) ?? '',
        emoji: (j['emoji'] as String?) ?? '🌍',
        color: _parseHexColor(j['color'] as String?),
        weeks: (j['weeks'] as String?) ?? '',
        arrival: (j['arrival'] as String?) ?? '',
        room: (j['room'] as String?) ?? '',
        soundtrack: (j['soundtrack'] as String?) ?? '',
        words: <String>[
          for (final w in (j['words'] as List? ?? const [])) w.toString(),
        ],
        wallQuestions: <String>[
          for (final q in (j['wallQuestions'] as List? ?? const []))
            q.toString(),
        ],
        keyMoment: (j['keyMoment'] as String?) ?? '',
        transition: (j['transition'] as String?) ?? '',
        days: <JourneyDay>[
          for (final d in (j['days'] as List? ?? const []))
            if (d is Map<String, dynamic>) JourneyDay.fromJson(d),
        ],
      );

  final String name;
  final String emoji;
  final Color color;

  /// Human label of which curriculum weeks this block spans, e.g. "1-2".
  final String weeks;

  /// What the kids walk into on the Monday this block begins.
  final String arrival;

  /// How the room is dressed for the two weeks.
  final String room;

  /// The ambient sound bed for the block.
  final String soundtrack;

  /// The five spell-words featured on the wall this block.
  final List<String> words;

  /// Ten wall questions — one surfaces per day of the block.
  final List<String> wallQuestions;

  /// The one moment that, if it lands, IS the program for this block.
  final String keyMoment;

  /// How the room dissolves into the next world on the final Friday.
  final String transition;

  /// The ten authored days (program-day numbers within this block).
  final List<JourneyDay> days;
}

Color _parseHexColor(String? hex) {
  if (hex == null) return const Color(0xFF888888);
  var h = hex.replaceFirst('#', '').trim();
  if (h.length == 6) h = 'FF$h';
  final value = int.tryParse(h, radix: 16);
  return value == null ? const Color(0xFF888888) : Color(value);
}

/// The full 50-day journey (five two-week blocks), loaded once from the
/// bundled JSON. Offline-first: the asset ships in the app bundle, no network.
final worldBlocksProvider = FutureProvider<List<WorldBlock>>((ref) async {
  final raw = await rootBundle.loadString('assets/curriculum/world_blocks.json');
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) return const [];
  final blocks = decoded['blocks'];
  if (blocks is! List) return const [];
  return [
    for (final b in blocks)
      if (b is Map<String, dynamic>) WorldBlock.fromJson(b),
  ];
});

/// The block (two-week world) that contains program [day] (1–50). Clamped to
/// the first / last block for out-of-range days so callers always get the
/// nearest world. Null only when [blocks] is empty. Pure + testable.
WorldBlock? blockForDay(List<WorldBlock> blocks, int day) {
  if (blocks.isEmpty) return null;
  final idx = ((day - 1) ~/ 10).clamp(0, blocks.length - 1);
  return blocks[idx];
}

/// The authored day (title + focus) for program [day] (1–50). Searches every
/// block for the exact day number; null when not found. Pure + testable.
JourneyDay? journeyDayForDay(List<WorldBlock> blocks, int day) {
  for (final b in blocks) {
    for (final d in b.days) {
      if (d.day == day) return d;
    }
  }
  return null;
}

/// The wall question for program [day] (1–50) — the day's question drawn from
/// its block's bank of ten (one per day of the two-week block). Null when the
/// block has no questions. Pure + testable.
String? wallQuestionForDay(List<WorldBlock> blocks, int day) {
  final b = blockForDay(blocks, day);
  if (b == null || b.wallQuestions.isEmpty) return null;
  final within = (day - 1) % 10; // 0–9 within the block
  return b.wallQuestions[within % b.wallQuestions.length];
}

/// The program-day number (1–50) for [now], given the program's Week-1
/// [start] date. Reuses [curriculumWeekFor] for the week boundary, then adds
/// the weekday within the week (Mon=1 … Fri=5). Weekends clamp to Friday so a
/// staffer prepping on Saturday still sees the week's last focus. Null when
/// the journey isn't set up / active. Pure + testable.
///
/// Assumes the program runs Mon–Fri and Week 1 begins on a Monday (the shape
/// the "jump to week N" action preserves). For a mid-week start it's an
/// approximate hint, not an exact index — the day-level surfaces are always
/// navigable.
int? programDayFor(DateTime? start, DateTime now) {
  final week = curriculumWeekFor(start, now);
  if (week == null) return null;
  final dow = now.weekday.clamp(1, 5); // Mon=1 … Fri=5, weekend → Fri
  return (week - 1) * 5 + dow;
}

/// Today's program-day number (1–50), derived from the program start-date cap.
/// Null when the journey isn't active. The single source for "what day are we
/// on" across the day-focus + wall-question surfaces.
final currentProgramDayProvider = Provider<int?>((ref) {
  final start = ref.watch(programStartDateProvider);
  return programDayFor(start, DateTime.now());
});

/// The block the room is living in right now, or null when the journey isn't
/// active (or the catalog is still loading).
final currentBlockProvider = Provider<WorldBlock?>((ref) {
  final day = ref.watch(currentProgramDayProvider);
  if (day == null) return null;
  final blocks = ref.watch(worldBlocksProvider).value;
  if (blocks == null) return null;
  return blockForDay(blocks, day);
});

/// Today's authored day (title + focus), or null when the journey isn't active.
final todaysJourneyDayProvider = Provider<JourneyDay?>((ref) {
  final day = ref.watch(currentProgramDayProvider);
  if (day == null) return null;
  final blocks = ref.watch(worldBlocksProvider).value;
  if (blocks == null) return null;
  return journeyDayForDay(blocks, day);
});

/// Today's wall question, or null when the journey isn't active.
final todaysWallQuestionProvider = Provider<String?>((ref) {
  final day = ref.watch(currentProgramDayProvider);
  if (day == null) return null;
  final blocks = ref.watch(worldBlocksProvider).value;
  if (blocks == null) return null;
  return wallQuestionForDay(blocks, day);
});
