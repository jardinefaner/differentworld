import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_stage.dart';
import 'package:flutter/material.dart';

/// Quick Poll — the first NON-game presentable (docs/VISION.md #18). Proves
/// the present/control engine isn't game-specific: a real group decision
/// ("What should we do next?"), options big on the screen, the room votes
/// with hands, the teacher taps each option's count from the phone, then
/// Reveal highlights the winner. Same engine, same remote — not a game.
///
/// First user of `buildControls` (per-option +1), so the bar is the game's,
/// not the standard Back/Reveal/Next. Default question for v1; a setup sheet
/// (custom question/options) is the obvious next enhancement.
class PollState {
  const PollState({
    required this.question,
    required this.options,
    required this.counts,
    required this.revealed,
  });

  factory PollState.fromMap(Map<String, dynamic> m) => PollState(
    question: m['q'] as String? ?? '',
    options: [for (final o in (m['options'] as List? ?? const [])) o as String],
    counts: [
      for (final c in (m['counts'] as List? ?? const [])) (c as num).toInt(),
    ],
    revealed: m['r'] == true,
  );

  final String question;
  final List<String> options;
  final List<int> counts;
  final bool revealed;

  int get maxCount =>
      counts.isEmpty ? 0 : counts.reduce((a, b) => a > b ? a : b);
  int get totalVotes => counts.fold(0, (a, b) => a + b);
  int get winnerIndex {
    if (counts.isEmpty) return -1;
    var best = 0;
    for (var i = 1; i < counts.length; i++) {
      if (counts[i] > counts[best]) best = i;
    }
    return best;
  }
}

class PollGame extends GameDefinition<PollState> {
  const PollGame();

  @override
  String get id => 'poll';

  @override
  String get title => 'Quick Poll';

  @override
  GameVibe get vibe => const GameVibe(accent: GameAccents.deepTeal);

  @override
  String? get liveRoute => '/live/poll';

  @override
  Map<String, dynamic> initialState(ContentSource content) => {
    'q': 'What should we do next?',
    'options': const ['Outside', 'Art', 'Building', 'Reading'],
    'counts': const [0, 0, 0, 0],
    'r': false,
  };

  @override
  PollState decode(Map<String, dynamic> state) => PollState.fromMap(state);

  @override
  Map<String, dynamic> reduce(
    Map<String, dynamic> state,
    GameIntent intent,
    Map<String, dynamic> args,
  ) {
    final s = Map<String, dynamic>.from(state);
    final counts = [
      for (final c in (s['counts'] as List? ?? const [])) (c as num).toInt(),
    ];
    switch (intent) {
      case GameIntent.tally:
        final choice = (args['choice'] as num?)?.toInt();
        if (choice != null && choice >= 0 && choice < counts.length) {
          counts[choice]++;
          s['counts'] = counts;
        }
      case GameIntent.reveal:
        s['r'] = !(s['r'] == true);
      case GameIntent.reset:
        s['counts'] = List<int>.filled(counts.length, 0);
        s['r'] = false;
      case GameIntent.next:
      case GameIntent.back:
      case GameIntent.pick:
      case GameIntent.capture:
      case GameIntent.submit:
        break;
    }
    return s;
  }

  @override
  Set<GameIntent> activeIntents(PollState s) => {
    GameIntent.reveal,
    GameIntent.reset,
  };

  @override
  Widget buildStage(BuildContext context, PollState s) {
    return GameStage.frame(
      context,
      hero: GameStage.hero(context, s.question, maxLines: 3),
      body: Padding(
        padding: const EdgeInsets.only(top: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < s.options.length; i++) ...[
              _OptionBar(
                label: s.options[i],
                count: s.counts[i],
                maxCount: s.maxCount,
                winner: s.revealed && s.maxCount > 0 && i == s.winnerIndex,
                accent: vibe.accent,
                showCount: s.totalVotes > 0,
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
            Text(
              s.totalVotes == 0
                  ? 'Vote with your hands'
                  : '${s.totalVotes} votes',
              style: const TextStyle(color: Colors.white38),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget? buildControls(
    BuildContext context,
    PollState state,
    void Function(GameIntent intent, [Map<String, dynamic> args]) send,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < state.options.length; i++)
          FilledButton.tonal(
            onPressed: () => send(GameIntent.tally, {'choice': i}),
            child: Text('${state.options[i]}  ${state.counts[i]}'),
          ),
        FilledButton.icon(
          onPressed: () => send(GameIntent.reveal),
          icon: Icon(
            state.revealed ? Icons.visibility_off : Icons.emoji_events,
          ),
          label: Text(state.revealed ? 'Hide' : 'Winner'),
        ),
        IconButton.filledTonal(
          onPressed: () => send(GameIntent.reset),
          icon: const Icon(Icons.replay),
          tooltip: 'Reset votes',
        ),
      ],
    );
  }
}

class _OptionBar extends StatelessWidget {
  const _OptionBar({
    required this.label,
    required this.count,
    required this.maxCount,
    required this.winner,
    required this.accent,
    required this.showCount,
  });

  final String label;
  final int count;
  final int maxCount;
  final bool winner;
  final Color accent;
  final bool showCount;

  @override
  Widget build(BuildContext context) {
    final frac = maxCount == 0 ? 0.0 : count / maxCount;
    final fg = winner ? AppColors.onAccent(accent) : Colors.white;
    return LayoutBuilder(
      builder: (context, constraints) {
        // A hairline row (like the option atom) whose accent WASH grows with the
        // vote share — invisible at 0, so an unvoted poll reads as clean rows,
        // not stacked grey slabs. The winner fills solid on reveal.
        return Container(
          height: 52,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOut,
                width: constraints.maxWidth * frac,
                color: winner ? accent : accent.withValues(alpha: 0.26),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    if (winner) ...[
                      Icon(Icons.emoji_events, color: fg, size: 18),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: fg,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (showCount)
                      Text(
                        '$count',
                        style: TextStyle(
                          color: winner ? fg : Colors.white54,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
