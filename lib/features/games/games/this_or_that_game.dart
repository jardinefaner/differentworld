import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_stage.dart';
import 'package:flutter/material.dart';

/// This-or-That on the unified framework (docs/GAMES.md Wave 0b). Two
/// colored halves + an OR; the host advances slides and reveals a "why?"
/// discussion prompt. The reducer is the exact logic that lived in
/// `LiveState.reduce` (which is why This-or-That was the chosen first port —
/// it was already reducer-shaped); the stage is the old `_presentation`.
///
/// The resolved pairs ride INSIDE the wire-state (`'pairs'`), so the state
/// is self-describing — the same bytes that drive a single device will, on
/// the live path (0c), let a controller render the pair with no assumption
/// about content ordering matching across devices.
class ThisOrThatState {
  const ThisOrThatState({
    required this.index,
    required this.revealed,
    required this.done,
    required this.pairs,
  });

  factory ThisOrThatState.fromMap(Map<String, dynamic> m) => ThisOrThatState(
    index: (m['i'] as num?)?.toInt() ?? 0,
    revealed: m['r'] == true,
    done: m['d'] == true,
    pairs: [
      for (final p in (m['pairs'] as List? ?? const []))
        ((p as List)[0] as String, p[1] as String),
    ],
  );

  final int index;
  final bool revealed;
  final bool done;
  final List<(String, String)> pairs;

  (String, String) get current =>
      pairs.isEmpty ? ('', '') : pairs[index % pairs.length];
}

class ThisOrThatGame extends GameDefinition<ThisOrThatState> {
  const ThisOrThatGame();

  @override
  String get id => 'this-or-that';

  @override
  String get title => 'This or That';

  @override
  GameVibe get vibe => const GameVibe(accent: GameAccents.teal);

  @override
  String revealLabel({required bool revealed}) => revealed ? 'Hide' : 'Discuss';

  @override
  Map<String, dynamic> initialState(ContentSource content) {
    final pairs = [
      for (final c in content.take(ContentKind.thisOrThat, 8))
        [c.payload['a']! as String, c.payload['b']! as String],
    ];
    return {'i': 0, 'r': false, 'd': false, 'n': pairs.length, 'pairs': pairs};
  }

  @override
  ThisOrThatState decode(Map<String, dynamic> state) =>
      ThisOrThatState.fromMap(state);

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
      case GameIntent.reveal:
        s['r'] = !(s['r'] == true);
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
  Set<GameIntent> activeIntents(ThisOrThatState s) {
    if (s.done) return {GameIntent.back, GameIntent.reset};
    return {
      GameIntent.reveal,
      GameIntent.next,
      if (s.index > 0) GameIntent.back,
    };
  }

  @override
  Widget buildStage(BuildContext context, ThisOrThatState s) {
    if (s.done) return const _WrapSlide();
    final (a, b) = s.current;
    final theme = Theme.of(context);
    return GameStage.frame(
      context,
      eyebrow: 'This, or that?',
      hero: _Choice(text: a, accent: vibe.accent),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 14),
          Text(
            'or',
            style: theme.textTheme.titleMedium?.copyWith(color: Colors.white38),
          ),
          const SizedBox(height: 14),
          _Choice(text: b, accent: vibe.accent),
          if (s.revealed) ...[
            const SizedBox(height: 22),
            Text(
              'Why? Turn to a partner and tell them.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white60,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One side of the comparison — a large accent-tinted card on the dark stage
/// (was a full-bleed colour half; now joins the family).
class _Choice extends StatelessWidget {
  const _Choice({required this.text, required this.accent});

  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 22),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.displaySmall?.copyWith(
          color: AppColors.readableOnDark(accent),
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

class _WrapSlide extends StatelessWidget {
  const _WrapSlide();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF1B1B2F),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🎉', style: TextStyle(fontSize: 56)),
            SizedBox(height: 12),
            Text(
              "That's a wrap!",
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
