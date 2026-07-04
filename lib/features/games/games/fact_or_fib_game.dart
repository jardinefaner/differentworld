import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_stage.dart';
import 'package:flutter/material.dart';

/// Fact or Fib on the framework (docs/GAMES.md Wave 1b). A claim shows big,
/// the room votes True/Fib with hands, the host Reveals (the verdict glows +
/// the real note appears) then Next. Same reveal shape as Riddles; different
/// stage. Content payload: {statement, isTrue, note}.
class FactState {
  const FactState({
    required this.index,
    required this.revealed,
    required this.done,
    required this.items,
  });

  factory FactState.fromMap(Map<String, dynamic> m) => FactState(
    index: (m['i'] as num?)?.toInt() ?? 0,
    revealed: m['r'] == true,
    done: m['d'] == true,
    items: [
      for (final it in (m['items'] as List? ?? const []))
        (
          (it as List)[0] as String,
          it[1] == true,
          it[2] as String,
        ),
    ],
  );

  final int index;
  final bool revealed;
  final bool done;
  final List<(String, bool, String)> items;

  (String, bool, String) get current =>
      items.isEmpty ? ('', false, '') : items[index % items.length];
}

class FactOrFibGame extends GameDefinition<FactState> {
  const FactOrFibGame();

  @override
  String get id => 'fact-or-fib';

  @override
  String get title => 'Fact or Fib';

  @override
  GameVibe get vibe => const GameVibe(accent: GameAccents.sage);

  @override
  String? get liveRoute => '/live/fact-or-fib';

  @override
  Map<String, dynamic> initialState(ContentSource content) {
    final picked = content.take(ContentKind.factOrFib, 10);
    final items = [
      for (final c in picked)
        [
          c.payload['statement']! as String,
          c.payload['isTrue']! as bool,
          c.payload['note']! as String,
        ],
    ];
    return {'i': 0, 'r': false, 'd': false, 'n': items.length, 'items': items};
  }

  @override
  FactState decode(Map<String, dynamic> state) => FactState.fromMap(state);

  @override
  Map<String, dynamic> reduce(
    Map<String, dynamic> state,
    GameIntent intent,
    Map<String, dynamic> args,
  ) => revealDeckReduce(state, intent);

  @override
  Set<GameIntent> activeIntents(FactState s) {
    if (s.done) return {GameIntent.back, GameIntent.reset};
    return {
      GameIntent.reveal,
      GameIntent.next,
      if (s.index > 0) GameIntent.back,
    };
  }

  @override
  Widget buildStage(BuildContext context, FactState s) {
    if (s.done) {
      return GameStage.recap(
        context,
        emoji: '🤔',
        title: 'Fact-checked!',
        caption: '${s.items.length} claims, together.',
      );
    }
    final (statement, isTrue, note) = s.current;
    return GameStage.frame(
      context,
      eyebrow: s.revealed ? null : 'True, or fib?',
      hero: GameStage.hero(context, statement),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GameStage.option(
                context,
                'True',
                accent: vibe.accent,
                selected: s.revealed && isTrue,
                dimmed: s.revealed && !isTrue,
                fontSize: 19,
              ),
              const SizedBox(width: 12),
              GameStage.option(
                context,
                'Fib',
                accent: vibe.accent,
                selected: s.revealed && !isTrue,
                dimmed: s.revealed && isTrue,
                fontSize: 19,
              ),
            ],
          ),
          if (s.revealed) ...[
            const SizedBox(height: 24),
            Text(
              note,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white70,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
