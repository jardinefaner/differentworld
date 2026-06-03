import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
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
  GameVibe get vibe => const GameVibe(accent: Color(0xFF7E57C2));

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
  ) {
    final s = Map<String, dynamic>.from(state);
    final i = (s['i'] as num?)?.toInt() ?? 0;
    final n = (s['n'] as num?)?.toInt() ?? 1;
    final done = s['d'] == true;
    switch (intent) {
      case GameIntent.reveal:
        if (!done) s['r'] = !(s['r'] == true);
      case GameIntent.next:
        if (done) break;
        if (i >= n - 1) {
          s['d'] = true;
        } else {
          s['i'] = i + 1;
          s['r'] = false;
        }
      case GameIntent.back:
        if (done) {
          s['d'] = false;
        } else if (i > 0) {
          s['i'] = i - 1;
          s['r'] = false;
        }
      case GameIntent.reset:
        s['i'] = 0;
        s['r'] = false;
        s['d'] = false;
      case GameIntent.pick:
      case GameIntent.tally:
      case GameIntent.capture:
      case GameIntent.submit:
        break;
    }
    return s;
  }

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
    final theme = Theme.of(context);
    if (s.done) {
      return _Recap(count: s.items.length);
    }
    final (prompt, answer) = s.current;
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  prompt,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  s.revealed ? 'There it is!' : 'Say your guess — then Reveal',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white38,
                  ),
                ),
                const SizedBox(height: 28),
                _AnswerCard(answer: answer, revealed: s.revealed),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The answer slot — a dim "?" until Reveal, then a celebratory glow (never
/// graded; the room already said it out loud).
class _AnswerCard extends StatelessWidget {
  const _AnswerCard({required this.answer, required this.revealed});

  final String answer;
  final bool revealed;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 88),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: revealed
            ? Colors.greenAccent
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        revealed ? answer : '?',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: revealed ? Colors.black87 : Colors.white24,
          fontSize: revealed ? 30 : 40,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Recap extends StatelessWidget {
  const _Recap({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🧠', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              'Nice riddling!',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$count riddles, together.',
              style: const TextStyle(color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }
}
