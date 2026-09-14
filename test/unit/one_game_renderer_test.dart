// ONE thing draws a game.
//
// Four surfaces render a game from its wire-state — the single-device
// scaffold, the cast receiver, the cast cockpit and the live screen — and
// each used to decide for itself whether the wire was showing a briefing or a
// board. Two asked; two did not. The result was not cosmetic: casting a
// scripted board game put beat one on the television and a board on the
// phone, whose only live verbs are a tap the briefing swallows and a reset,
// so the room could never be moved past the first rule.
//
// This pins the property that fixes the CLASS: inside the game and
// live-session layers, only `game_view.dart` builds a `RunScriptView`.
// Anything else drawing its own briefing is a fifth answer to a question
// that has one.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Every .dart file under the two layers that draw games.
  List<File> gameLayerFiles() => [
    for (final dir in const [
      'lib/features/games',
      'lib/features/live_session',
    ])
      ...Directory(dir)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart')),
  ];

  test('the scan finds the game layers at all', () {
    // Without this the suite passes vacuously the day the folders move.
    expect(gameLayerFiles().length, greaterThan(30));
  });

  test('only game_view.dart draws a briefing', () {
    final offenders = <String>[];
    for (final f in gameLayerFiles()) {
      if (f.path.endsWith('game_view.dart')) continue;
      final src = f.readAsStringSync();
      if (src.contains('RunScriptView(')) offenders.add(f.path);
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'a surface drawing its own briefing is a fifth answer to a '
          'one-answer question — render GameView instead: '
          "${offenders.join(', ')}",
    );
  });

  test('only game_view.dart decides whether a wire is briefing', () {
    // `GameView.isBriefing` is the sanctioned read (a surface asking so it
    // can drop its own control bar). Reaching past it to the wire key is how
    // the four copies of this decision started.
    final offenders = <String>[];
    for (final f in gameLayerFiles()) {
      if (f.path.endsWith('game_view.dart')) continue;
      final src = f.readAsStringSync();
      if (src.contains('RunScriptWire.indexOf')) offenders.add(f.path);
    }
    expect(
      offenders,
      isEmpty,
      reason: "use GameView.isBriefing: ${offenders.join(', ')}",
    );
  });

  test('every audience is a real answer to whose screen this is', () {
    // A guard against the enum growing a value nobody renders: each one is
    // used by at least one surface.
    final src = [
      for (final f in gameLayerFiles()) f.readAsStringSync(),
    ].join();
    for (final a in const ['host', 'remote', 'room', 'presenter']) {
      expect(
        src.contains('GameAudience.$a'),
        isTrue,
        reason: 'GameAudience.$a is declared and never used',
      );
    }
  });
}
