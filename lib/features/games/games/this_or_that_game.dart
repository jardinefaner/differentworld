import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
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

  // Per-pair palette — each slide gets its own two-tone split.
  static const _palette = <(Color, Color)>[
    (ActivityPalette.red, ActivityPalette.blue),
    (ActivityPalette.amber, ActivityPalette.teal),
    (ActivityPalette.purple, ActivityPalette.green),
    (ActivityPalette.indigo, ActivityPalette.yellow),
    (ActivityPalette.pink, ActivityPalette.lightBlue),
  ];

  @override
  String get id => 'this-or-that';

  @override
  String get title => 'This or That';

  @override
  GameVibe get vibe => const GameVibe(accent: GameAccents.teal);

  @override
  String? get liveRoute => '/live/this-or-that';

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
    final (colorA, colorB) = _palette[s.index % _palette.length];
    final (a, b) = s.current;
    return Stack(
      fit: StackFit.expand,
      children: [
        Column(
          children: [
            Expanded(child: _Half(text: a, color: colorA)),
            Expanded(child: _Half(text: b, color: colorB)),
          ],
        ),
        const Center(child: _OrBadge()),
        if (s.revealed)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: Colors.black.withValues(alpha: 0.75),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              child: const Text(
                'Why? Turn to a partner and tell them.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Half extends StatelessWidget {
  const _Half({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, Colors.black, 0.28)!],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: FittedBox(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w800,
                shadows: [Shadow(color: Colors.black38, blurRadius: 6)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrBadge extends StatelessWidget {
  const _OrBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12),
        ],
      ),
      alignment: Alignment.center,
      child: const Text(
        'OR',
        style: TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w900,
          fontSize: 16,
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
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
