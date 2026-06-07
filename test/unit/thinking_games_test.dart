import 'dart:convert';
import 'dart:io';

import 'package:differentworld/features/action_words/thinking_games.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<ThinkingGame> load() {
    final raw =
        File('assets/curriculum/thinking_games.json').readAsStringSync();
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

  test('thinkingGameForDay rotates deterministically + covers the deck', () {
    final games = load();
    final a = thinkingGameForDay(games, DateTime(2026, 7, 14, 9));
    final b = thinkingGameForDay(games, DateTime(2026, 7, 14, 18));
    expect(a?.id, b?.id); // same day → same game
    final hit = <String>{};
    for (var d = 0; d < games.length; d++) {
      final g = thinkingGameForDay(games, DateTime(2026, 7, 2).add(Duration(days: d)));
      if (g != null) hit.add(g.id);
    }
    expect(hit.length, games.length);
    expect(thinkingGameForDay(const [], DateTime(2026, 7, 14)), isNull);
  });
}
