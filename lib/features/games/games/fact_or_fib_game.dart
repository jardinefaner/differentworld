import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
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
  GameVibe get vibe => const GameVibe(accent: Color(0xFF66BB6A));

  @override
  String? get liveRoute => '/live/fact-or-fib';

  @override
  Map<String, dynamic> initialState(ContentSource content) {
    final picked = (content.take(ContentKind.factOrFib, 1000)..shuffle())
        .take(10)
        .toList();
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
    final theme = Theme.of(context);
    if (s.done) {
      return _Recap(count: s.items.length);
    }
    final (statement, isTrue, note) = s.current;
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
                  statement,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  s.revealed ? '' : 'True, or fib? Vote with your hands',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white38,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Verdict(
                      label: 'True',
                      highlight: s.revealed && isTrue,
                      dim: s.revealed && !isTrue,
                    ),
                    const SizedBox(width: 16),
                    _Verdict(
                      label: 'Fib',
                      highlight: s.revealed && !isTrue,
                      dim: s.revealed && isTrue,
                    ),
                  ],
                ),
                if (s.revealed) ...[
                  const SizedBox(height: 20),
                  Text(
                    note,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Verdict extends StatelessWidget {
  const _Verdict({
    required this.label,
    required this.highlight,
    required this.dim,
  });

  final String label;
  final bool highlight;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      decoration: BoxDecoration(
        color: highlight
            ? Colors.greenAccent
            : Colors.white.withValues(alpha: dim ? 0.04 : 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: highlight
              ? Colors.black87
              : (dim ? Colors.white24 : Colors.white),
          fontSize: 22,
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
            const Text('🤔', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              'Fact-checked!',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$count claims, together.',
              style: const TextStyle(color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }
}
