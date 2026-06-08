import 'dart:convert';
import 'dart:io';

import 'package:differentworld/features/action_words/thinking_games.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<ThinkingGame> load() {
    final raw = File(
      'assets/curriculum/thinking_games.json',
    ).readAsStringSync();
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return [
      for (final g in decoded['games'] as List)
        ThinkingGame.fromJson(g as Map<String, dynamic>),
    ];
  }

  test('the deck has the six games, each fully formed', () {
    final games = load();
    final ids = games.map((g) => g.id).toList();
    expect(
      ids,
      containsAll(<String>[
        'dominoes',
        'telephone',
        'mirror',
        'blindfold',
        'sorting',
        'balance',
      ]),
    );
    expect(ids.toSet().length, ids.length);
    for (final g in games) {
      expect(g.concept, isNotEmpty, reason: '${g.id} concept');
      expect(g.meaning, isNotEmpty);
      expect(g.play, isNotEmpty, reason: '${g.id} play');
      expect(g.name, isNotEmpty, reason: '${g.id} name');
      expect(g.bridge.length, 3, reason: '${g.id} needs 3 bridge steps');
      expect(g.question, isNotEmpty, reason: '${g.id} question');
    }
  });

  test('every curriculum week 1-10 has at least one thinking game', () {
    final games = load();
    for (var w = 1; w <= 10; w++) {
      expect(
        games.where((g) => g.week == w),
        isNotEmpty,
        reason: 'week $w has no thinking game',
      );
    }
  });

  test('the six generic games are week 0 (anytime, not world-tied)', () {
    final games = load();
    const generic = {
      'dominoes',
      'telephone',
      'mirror',
      'blindfold',
      'sorting',
      'balance',
    };
    for (final g in games.where((g) => generic.contains(g.id))) {
      expect(g.week, 0, reason: '${g.id} should be anytime');
    }
  });

  test('every one of the 13 RPG systems has a game underneath it', () {
    final games = load();
    const systems = [
      'avatar',
      'name',
      'level',
      'abilities',
      'skills',
      'spells',
      'tools',
      'inventory',
      'allies',
      'quests',
      'collection',
      'lore',
      'weather',
    ];
    for (final sys in systems) {
      final game = thinkingGameForSystem(games, sys);
      expect(game, isNotNull, reason: 'no game under system "$sys"');
      expect(game!.concept, isNotEmpty);
      expect(game.bridge.length, 3, reason: '$sys bridge');
    }
    // systemThinkingGames returns exactly the system-tied ones.
    final sysGames = systemThinkingGames(games);
    expect(sysGames.length, systems.length);
    expect(thinkingGameForSystem(games, ''), isNull);
    expect(thinkingGameForSystem(games, 'not-a-system'), isNull);
  });

  test('thinkingGamesForWeek filters to that week; null/0 → empty', () {
    final games = load();
    expect(
      thinkingGamesForWeek(games, 4).map((g) => g.id),
      containsAll(<String>['adaptation', 'irreversible', 'diffusion']),
    );
    expect(
      thinkingGamesForWeek(games, 1).map((g) => g.id),
      containsAll(<String>['unique', 'container', 'perception']),
    );
    expect(thinkingGamesForWeek(games, null), isEmpty);
    expect(thinkingGamesForWeek(games, 0), isEmpty);
  });

  test('thinkingGameForDay rotates deterministically + covers the deck', () {
    final games = load();
    final a = thinkingGameForDay(games, DateTime(2026, 7, 14, 9));
    final b = thinkingGameForDay(games, DateTime(2026, 7, 14, 18));
    expect(a?.id, b?.id); // same day → same game
    final hit = <String>{};
    for (var d = 0; d < games.length; d++) {
      final g = thinkingGameForDay(
        games,
        DateTime(2026, 7, 2).add(Duration(days: d)),
      );
      if (g != null) hit.add(g.id);
    }
    expect(hit.length, games.length);
    expect(thinkingGameForDay(const [], DateTime(2026, 7, 14)), isNull);
  });
}
