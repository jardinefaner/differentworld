// A new prompt has to ARRIVE, not just replace the old one.
//
// Nineteen board games have had motion since `ShapeStageView` shipped, because
// ONE renderer draws every board and it decides how a cell changes. The twelve
// PROMPT games had nobody to decide it for them, so all twelve cut: a new
// riddle, a new letter, a new question swapped in a single frame, which leaves
// a room unable to answer the only question a change raises — what moved?
//
// `GameStage.frame` decides it now, once. These check the decision reaches
// every game that shares the stage — including the ones whose hero is a
// picture rather than words, which are exactly the ones a shared default
// silently skips.

import 'dart:io';

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_motion.dart';
import 'package:differentworld/features/games/game_registry.dart';
import 'package:differentworld/features/games/game_stage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Games that draw their prompts through [GameStage.frame] and MUST show a
/// new one arriving. Derived from the source so a new prompt game joins by
/// existing, not by being remembered here.
const _stageFile = 'lib/features/games/games/';

/// The two that deliberately do NOT animate the frame, each with its reason
/// written at the call site.
const _exempt = <String, String>{
  'timer': 'its hero ticks four times a second — a strobe, not a clock',
  'picker': 'its own reveal is slower on purpose, and would lose the fight',
  'poll': 'one question per round — there is no next prompt to arrive',
};

final _bank = LocalContentBank.seededWith(curatedSeeds);

/// The key the frame's switcher is showing — the identity of THIS prompt.
Key? _promptKey(WidgetTester tester) {
  final switchers = find.byType(AnimatedSwitcher);
  if (switchers.evaluate().isEmpty) return null;
  // The frame's switcher wraps the whole column, so it is the outermost.
  return tester.widget<AnimatedSwitcher>(switchers.first).child?.key;
}

Future<Key?> _render(
  WidgetTester tester,
  GameDefinition<dynamic> def,
  Map<String, dynamic> wire,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Builder(
          builder: (context) => def.buildStage(context, def.decode(wire)),
        ),
      ),
    ),
  );
  await tester.pump();
  return _promptKey(tester);
}

/// Advance to the NEXT prompt, whatever verb this game uses for it.
Map<String, dynamic> _advance(
  GameDefinition<dynamic> def,
  Map<String, dynamic> wire,
) {
  var out = wire;
  for (final intent in [GameIntent.next, GameIntent.reveal, GameIntent.pick]) {
    out = def.reduce(out, intent, const {'choice': 0});
    if (out.toString() != wire.toString()) return out;
  }
  return out;
}

void main() {
  late List<GameDefinition<dynamic>> promptGames;

  setUpAll(() {
    final source = <String, String>{};
    for (final def in liveGames) {
      final f = File('$_stageFile${def.id.replaceAll('-', '_')}_game.dart');
      if (f.existsSync()) source[def.id] = f.readAsStringSync();
    }
    promptGames = [
      for (final def in liveGames)
        if (source[def.id]?.contains('GameStage.frame') ?? false) def,
    ];
  });

  testWidgets('enough of the deck draws its prompts here to be worth it', (
    tester,
  ) async {
    expect(
      promptGames.length,
      greaterThanOrEqualTo(8),
      reason: 'found ${promptGames.length} prompt games — the scan is broken',
    );
  });

  testWidgets('a new prompt arrives rather than replacing the old one', (
    tester,
  ) async {
    final silent = <String>[];
    for (final def in promptGames) {
      if (_exempt.containsKey(def.id)) continue;
      final first = def.initialState(_bank);
      final before = await _render(tester, def, first);
      final after = await _render(tester, def, _advance(def, first));
      if (before == null || before == after) silent.add(def.id);
    }
    expect(
      silent,
      isEmpty,
      reason:
          'these cut between prompts — a custom hero has no words to key on '
          'and needs `turn:` at its GameStage.frame call: $silent',
    );
  });

  testWidgets('motion off means motion off', (tester) async {
    // The setting and the OS reduce-animations flag both have to reach here,
    // or "calm" is a switch that does nothing on twelve screens.
    final def = promptGames.firstWhere((d) => !_exempt.containsKey(d.id));
    await tester.pumpWidget(
      MaterialApp(
        home: GameMotion(
          enabled: false,
          child: Scaffold(
            backgroundColor: Colors.black,
            body: Builder(
              builder: (context) =>
                  def.buildStage(context, def.decode(def.initialState(_bank))),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.byType(AnimatedSwitcher),
      findsNothing,
      reason: '${def.id} animates its prompt with motion switched off',
    );
  });
}
