import 'dart:convert';

import 'package:differentworld/features/action_words/world_schedule.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A **Big Thinking** game (docs — the user's play→name→bridge→question
/// framework). A 5-minute embodied game teaches a concept through the body;
/// then you NAME it (one word — the spell/vocab of the day); then you BRIDGE
/// it ("where else does this happen?" room → world → universe); then you ask
/// the QUESTION with no answer (it goes on the Wall and grows answers all
/// week). Play the body, name the mind, bridge the transfer, question the
/// wonder.
@immutable
class ThinkingGame {
  const ThinkingGame({
    required this.id,
    required this.emoji,
    required this.concept,
    required this.meaning,
    required this.play,
    required this.name,
    required this.bridge,
    required this.question,
    this.week = 0,
    this.system = '',
  });

  factory ThinkingGame.fromJson(Map<String, dynamic> j) => ThinkingGame(
    id: (j['id'] as String?) ?? '',
    emoji: (j['emoji'] as String?) ?? '💡',
    concept: (j['concept'] as String?) ?? '',
    meaning: (j['meaning'] as String?) ?? '',
    play: (j['play'] as String?) ?? '',
    name: (j['name'] as String?) ?? '',
    bridge: [
      for (final b in (j['bridge'] as List? ?? const [])) b.toString(),
    ],
    question: (j['question'] as String?) ?? '',
    week: (j['week'] as num?)?.toInt() ?? 0,
    system: (j['system'] as String?) ?? '',
  );

  final String id;
  final String emoji;

  /// The curriculum week this game belongs to (1–10), tying it to that week's
  /// world — or 0 for an "anytime" game that fits no specific world.
  final int week;

  /// The RPG SYSTEM this game sits underneath (avatar / skills / weather / …),
  /// or '' for a world / anytime game. The bridge between the character sheet
  /// and the thinking deck — every system has a game underneath it.
  final String system;

  /// The NAME — the one-word concept ("CAUSE AND EFFECT", "DRIFT"). The spell.
  final String concept;

  /// The concept in plain words.
  final String meaning;

  /// THE GAME — the 5-minute embodied play.
  final String play;

  /// THE NAME beat — what the teacher says to name the concept.
  final String name;

  /// THE BRIDGE — the zoom-out steps (use it here → deeper → deepest).
  final List<String> bridge;

  /// THE QUESTION — the one with no answer; goes on the Wall.
  final String question;
}

/// The Big Thinking deck, loaded once from the bundled JSON (offline-first).
final thinkingGamesProvider = FutureProvider<List<ThinkingGame>>((ref) async {
  final raw = await rootBundle.loadString(
    'assets/curriculum/thinking_games.json',
  );
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) return const [];
  final games = decoded['games'];
  if (games is! List) return const [];
  return [
    for (final g in games)
      if (g is Map<String, dynamic>) ThinkingGame.fromJson(g),
  ];
});

/// A suggested thinking game for [now] — rotates one per day, deterministic.
ThinkingGame? thinkingGameForDay(List<ThinkingGame> games, DateTime now) {
  if (games.isEmpty) return null;
  final day = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(2026)).inDays;
  return games[day.abs() % games.length];
}

/// The thinking game(s) tied to a curriculum [week] (1–10). Some weeks have
/// two; an off-curriculum week (null/0) has none.
List<ThinkingGame> thinkingGamesForWeek(List<ThinkingGame> games, int? week) {
  if (week == null || week == 0) return const [];
  return [
    for (final g in games)
      if (g.week == week) g,
  ];
}

/// This week's thinking game(s) — the ones tied to the live curriculum world.
/// Empty when the journey isn't set up or no game maps to the current week.
final thisWeekThinkingProvider = Provider<List<ThinkingGame>>((ref) {
  final week = ref.watch(currentCurriculumWeekProvider);
  final games =
      ref.watch(thinkingGamesProvider).value ?? const <ThinkingGame>[];
  return thinkingGamesForWeek(games, week);
});

/// The single thinking game underneath an RPG [systemId] (avatar, skills,
/// weather, …), or null if none. The character-sheet sections link to it.
ThinkingGame? thinkingGameForSystem(
  List<ThinkingGame> games,
  String systemId,
) {
  if (systemId.isEmpty) return null;
  for (final g in games) {
    if (g.system == systemId) return g;
  }
  return null;
}

/// Every system-tied game (one per RPG system), for the deck's own section.
List<ThinkingGame> systemThinkingGames(List<ThinkingGame> games) => [
  for (final g in games)
    if (g.system.isNotEmpty) g,
];

/// The game under one RPG system, resolved from the loaded deck.
// ignore: specify_nonobvious_property_types — family provider, no stable name
final systemThinkingGameProvider = Provider.family<ThinkingGame?, String>((
  ref,
  systemId,
) {
  final games =
      ref.watch(thinkingGamesProvider).value ?? const <ThinkingGame>[];
  return thinkingGameForSystem(games, systemId);
});
