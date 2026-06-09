import 'dart:convert';

import 'package:differentworld/features/action_words/curriculum.dart';
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
/// This is the narrative layer ABOVE the 10-week curriculum, aligned 1:1 with
/// it: where `ten_worlds.json` (`CurriculumWorld`) is the verb / facet /
/// activity catalog for each weekly world, `world_blocks.json` is the same
/// world's *lived experience* — what the room looks and sounds like, the
/// arrival ritual, the transition out, and its five authored days. Ten weekly
/// worlds of five days each = the whole 50-day summer (one world per week, the
/// canonical "new world every week" journey). Same `week`/`id`/`name`/`emoji`/
/// `color` as the matching `CurriculumWorld`. Loaded from the bundle
/// (offline-first). The class name is historical — a "block" is now one weekly
/// world.
@immutable
class WorldBlock {
  const WorldBlock({
    required this.week,
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
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
        week: (j['week'] as num?)?.toInt() ?? 0,
        id: (j['id'] as String?) ?? '',
        name: (j['name'] as String?) ?? '',
        emoji: (j['emoji'] as String?) ?? '🌍',
        color: _parseHexColor(j['color'] as String?),
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

  /// The curriculum week (1–10) this world IS — matches the `CurriculumWorld`.
  final int week;

  /// The stable id (`me`, `stories`, …) — matches the `CurriculumWorld`.
  final String id;

  final String name;
  final String emoji;
  final Color color;

  /// What the kids walk into on the Monday this world begins.
  final String arrival;

  /// How the room is dressed for the week.
  final String room;

  /// The ambient sound bed for the world.
  final String soundtrack;

  /// The spell-words featured on the wall this world.
  final List<String> words;

  /// Wall questions — one surfaces per day of the world.
  final List<String> wallQuestions;

  /// The one moment that, if it lands, IS the program for this world.
  final String keyMoment;

  /// How the room dissolves into the next world on the final day.
  final String transition;

  /// The five authored days (program-day numbers within this world).
  final List<JourneyDay> days;
}

Color _parseHexColor(String? hex) {
  if (hex == null) return const Color(0xFF888888);
  var h = hex.replaceFirst('#', '').trim();
  if (h.length == 6) h = 'FF$h';
  final value = int.tryParse(h, radix: 16);
  return value == null ? const Color(0xFF888888) : Color(value);
}

/// The full 50-day journey (ten weekly worlds), loaded once from the bundled
/// JSON. Offline-first: the asset ships in the app bundle, no network. Sorted
/// by week so index == week − 1.
final worldBlocksProvider = FutureProvider<List<WorldBlock>>((ref) async {
  final raw = await rootBundle.loadString('assets/curriculum/world_blocks.json');
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) return const [];
  final worlds = decoded['worlds'];
  if (worlds is! List) return const [];
  return [
    for (final b in worlds)
      if (b is Map<String, dynamic>) WorldBlock.fromJson(b),
  ]..sort((a, b) => a.week.compareTo(b.week));
});

/// The weekly world that contains program [day] (1–50) — five days per world,
/// so world index == (day − 1) ~/ 5 == week − 1. Clamped to the first / last
/// world for out-of-range days. Null only when [blocks] is empty. Pure.
WorldBlock? blockForDay(List<WorldBlock> blocks, int day) {
  if (blocks.isEmpty) return null;
  final idx = ((day - 1) ~/ 5).clamp(0, blocks.length - 1);
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
/// its weekly world's bank (one per day of the five-day world). Null when the
/// world has no questions. Pure + testable.
String? wallQuestionForDay(List<WorldBlock> blocks, int day) {
  final b = blockForDay(blocks, day);
  if (b == null || b.wallQuestions.isEmpty) return null;
  final within = (day - 1) % 5; // 0–4 within the weekly world
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

/// The single canonical "where are we in the season" — bundling both layers of
/// skin (see docs/PROGRAM.md): the immersive `block` (the weekly world the room
/// becomes — its environment + days) AND the week's `world` (the curriculum
/// focus — verbs / activities / videos). Now aligned 1:1 (same week/id/name),
/// so `block` and `world` describe the SAME world at two grains. One source of
/// truth. Null when the journey isn't active (or content still loading).
typedef SeasonPosition = ({
  int day, // 1–50
  int week, // 1–10
  WorldBlock block, // the weekly world's environment + days
  CurriculumWorld? world, // the same world's verbs / activities; may lag-load
  JourneyDay? journeyDay, // today's title + focus
  String? wallQuestion, // today's wall question
});

/// Today's season position, or null when the journey isn't active.
final seasonPositionProvider = Provider<SeasonPosition?>((ref) {
  final day = ref.watch(currentProgramDayProvider);
  final week = ref.watch(currentCurriculumWeekProvider);
  final block = ref.watch(currentBlockProvider);
  if (day == null || week == null || block == null) return null;
  return (
    day: day,
    week: week,
    block: block,
    world: ref.watch(currentWorldProvider),
    journeyDay: ref.watch(todaysJourneyDayProvider),
    wallQuestion: ref.watch(todaysWallQuestionProvider),
  );
});
