import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_stage.dart';
import 'package:flutter/material.dart';

/// Riddle Me This on the framework (docs/GAMES.md Wave 1b). The reveal-game
/// template: one riddle big, the room shouts guesses aloud, the host taps
/// Reveal then Next. State is `{index, revealed, done}` over `{prompt,
/// answer}` content stashed in the wire-state (self-describing for live).
class RiddleState {
  const RiddleState({
    required this.index,
    required this.revealed,
    required this.done,
    required this.items,
  });

  factory RiddleState.fromMap(Map<String, dynamic> m) => RiddleState(
    index: (m['i'] as num?)?.toInt() ?? 0,
    revealed: m['r'] == true,
    done: m['d'] == true,
    items: [
      for (final it in (m['items'] as List? ?? const []))
        ((it as List)[0] as String, it[1] as String),
    ],
  );

  final int index;
  final bool revealed;
  final bool done;
  final List<(String, String)> items;

  (String, String) get current =>
      items.isEmpty ? ('', '') : items[index % items.length];
}

class RiddlesGame extends GameDefinition<RiddleState> {
  const RiddlesGame();

  @override
  String get id => 'riddles';

  @override
  String get title => 'Riddle Me This';

  @override
  GameVibe get vibe => const GameVibe(accent: GameAccents.slate);

  @override
  String? get liveRoute => '/live/riddles';

  @override
  Map<String, dynamic> initialState(ContentSource content) {
    final picked = content.take(ContentKind.riddle, 10);
    final items = [
      for (final c in picked)
        [c.payload['prompt']! as String, c.payload['answer']! as String],
    ];
    return {'i': 0, 'r': false, 'd': false, 'n': items.length, 'items': items};
  }

  @override
  RiddleState decode(Map<String, dynamic> state) => RiddleState.fromMap(state);

  @override
  Map<String, dynamic> reduce(
    Map<String, dynamic> state,
    GameIntent intent,
    Map<String, dynamic> args,
  ) => revealDeckReduce(state, intent);

  @override
  Set<GameIntent> activeIntents(RiddleState s) {
    if (s.done) return {GameIntent.back, GameIntent.reset};
    return {
      GameIntent.reveal,
      GameIntent.next,
      if (s.index > 0) GameIntent.back,
    };
  }

  @override
  Widget buildStage(BuildContext context, RiddleState s) {
    if (s.done) {
      return GameStage.recap(
        context,
        emoji: '🧠',
        title: 'Nice riddling!',
        caption: '${s.items.length} riddles, together.',
      );
    }
    final (prompt, answer) = s.current;
    return GameStage.frame(
      context,
      eyebrow: s.revealed ? 'There it is!' : 'Say your guess, then reveal',
      hero: GameStage.hero(context, prompt),
      body: Padding(
        padding: const EdgeInsets.only(top: 28),
        child: _AnswerCard(
          answer: answer,
          revealed: s.revealed,
          accent: vibe.accent,
        ),
      ),
    );
  }
}

/// The answer slot — a dim "?" until Reveal, then a celebratory glow (never
/// graded; the room already said it out loud).
class _AnswerCard extends StatelessWidget {
  const _AnswerCard({
    required this.answer,
    required this.revealed,
    required this.accent,
  });

  final String answer;
  final bool revealed;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 88),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: revealed ? accent : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: revealed
            ? null
            : Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        revealed ? answer : '?',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: revealed ? AppColors.onAccent(accent) : Colors.white24,
          fontSize: revealed ? 28 : 36,
          fontWeight: revealed ? FontWeight.w500 : FontWeight.w400,
        ),
      ),
    );
  }
}
