import 'dart:convert';

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
      );

  final String id;
  final String emoji;

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
  final raw =
      await rootBundle.loadString('assets/curriculum/thinking_games.json');
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
  final day = DateTime(now.year, now.month, now.day)
      .difference(DateTime(2026))
      .inDays;
  return games[day.abs() % games.length];
}
