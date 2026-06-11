import 'dart:convert';

import 'package:differentworld/features/action_words/world_schedule.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The missions a weekly world offers — what a kid can DO: a pool of [daily]
/// missions (pick 1–2 a day), a [weekly] goal or two, and the [project] (the
/// world's capstone artifact).
@immutable
class WorldMissions {
  const WorldMissions({
    required this.daily,
    required this.weekly,
    required this.project,
  });

  factory WorldMissions.fromJson(Map<String, dynamic> j) => WorldMissions(
        daily: <String>[
          for (final m in (j['daily'] as List? ?? const [])) m.toString(),
        ],
        weekly: <String>[
          for (final m in (j['weekly'] as List? ?? const [])) m.toString(),
        ],
        project: (j['project'] as String?) ?? '',
      );

  final List<String> daily;
  final List<String> weekly;
  final String project;
}

/// The RPG progression for a weekly world — the kid-as-player layer
/// (docs/VISION.md dreams #2 / #9 / #16). Each field is authored guidance for
/// this world's *stage* of the summer-long character arc: how the avatar
/// evolves, the spell-words to earn, the tools that unlock, what the inventory
/// holds, how allies form, what the Wall (lore) explores, and how mood-weather
/// deepens.
@immutable
class WorldRpg {
  const WorldRpg({
    required this.avatar,
    required this.name,
    required this.spells,
    required this.tools,
    required this.inventory,
    required this.allies,
    required this.lore,
    required this.weather,
  });

  factory WorldRpg.fromJson(Map<String, dynamic> j) => WorldRpg(
        avatar: (j['avatar'] as String?) ?? '',
        name: (j['name'] as String?) ?? '',
        spells: (j['spells'] as String?) ?? '',
        tools: (j['tools'] as String?) ?? '',
        inventory: (j['inventory'] as String?) ?? '',
        allies: (j['allies'] as String?) ?? '',
        lore: (j['lore'] as String?) ?? '',
        weather: (j['weather'] as String?) ?? '',
      );

  final String avatar;
  final String name;
  final String spells;
  final String tools;
  final String inventory;
  final String allies;
  final String lore;
  final String weather;
}

/// One weekly world's missions + RPG stage — keyed 1:1 with `CurriculumWorld`
/// and `WorldBlock` by `week`/`id`. The kid-as-player layer above the room
/// theme (world_blocks) and the verb catalog (ten_worlds). Loaded from the
/// bundle (offline-first).
@immutable
class WorldArc {
  const WorldArc({
    required this.week,
    required this.id,
    required this.missions,
    required this.rpg,
  });

  factory WorldArc.fromJson(Map<String, dynamic> j) => WorldArc(
        week: (j['week'] as num?)?.toInt() ?? 0,
        id: (j['id'] as String?) ?? '',
        missions: WorldMissions.fromJson(
          (j['missions'] as Map<String, dynamic>?) ?? const {},
        ),
        rpg: WorldRpg.fromJson(
          (j['rpg'] as Map<String, dynamic>?) ?? const {},
        ),
      );

  /// The curriculum week (1–10) — matches `CurriculumWorld` / `WorldBlock`.
  final int week;

  /// The stable id (`me`, `stories`, …) — matches the matching world.
  final String id;

  final WorldMissions missions;
  final WorldRpg rpg;
}

/// The full 10-world missions + RPG arc, loaded once from the bundled JSON.
/// Offline-first. Sorted by week so index == week − 1.
final worldArcProvider = FutureProvider<List<WorldArc>>((ref) async {
  final raw = await rootBundle.loadString('assets/curriculum/world_arc.json');
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) return const [];
  final worlds = decoded['worlds'];
  if (worlds is! List) return const [];
  return [
    for (final w in worlds)
      if (w is Map<String, dynamic>) WorldArc.fromJson(w),
  ]..sort((a, b) => a.week.compareTo(b.week));
});

/// A focused [count] of a world's daily missions for program [day], rotating
/// across the program's days so the menu varies day to day (without repeating
/// within a day). Returns fewer only if the pool is smaller. Pure + testable.
List<String> dailyMissionsForDay(List<String> daily, int day, {int count = 3}) {
  if (daily.isEmpty) return const [];
  final n = count.clamp(1, daily.length);
  final start = ((day - 1) * count) % daily.length;
  return [
    for (var i = 0; i < n; i++) daily[(start + i) % daily.length],
  ];
}

/// The arc for curriculum [week] (1–10). Null when [arcs] is empty or the week
/// is out of range. Pure + testable.
WorldArc? arcForWeek(List<WorldArc> arcs, int week) {
  for (final a in arcs) {
    if (a.week == week) return a;
  }
  return null;
}

/// The arc for program [day] (1–50) — five days per world, so world index
/// == (day − 1) ~/ 5 == week − 1. Clamped to the first / last world for
/// out-of-range days. Null only when [arcs] is empty. Pure + testable.
WorldArc? arcForDay(List<WorldArc> arcs, int day) {
  if (arcs.isEmpty) return null;
  final idx = ((day - 1) ~/ 5).clamp(0, arcs.length - 1);
  return arcs[idx];
}

/// The active weekly world's missions + RPG arc, or null when the journey
/// isn't active / the catalog is still loading.
final currentWorldArcProvider = Provider<WorldArc?>((ref) {
  final week = ref.watch(currentCurriculumWeekProvider);
  if (week == null) return null;
  final arcs = ref.watch(worldArcProvider).value;
  if (arcs == null) return null;
  return arcForWeek(arcs, week);
});
