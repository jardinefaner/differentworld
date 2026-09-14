import 'dart:math';

import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/facilitation/room_beat.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_settings.dart';
import 'package:differentworld/features/games/game_stage.dart';
import 'package:differentworld/features/games/games/tally_controls.dart';
import 'package:flutter/material.dart';

/// As-If on the unified framework (game.dart names it as an intended game).
/// A line + an "as if" show big; a learner performs it aloud — "Say 'I lost my
/// keys' AS IF you're a robot." The teacher taps "I did it!" for a new
/// challenge. Lines + as-ifs cycle at different lengths so pairings stay
/// fresh. Now present/live for free.
class AsIfState {
  const AsIfState({
    this.li = 0,
    this.ai = 0,
    this.performed = 0,
    this.done = false,
    this.roundLength = 0,
    this.lines = const [],
    this.asifs = const [],
  });

  factory AsIfState.fromMap(Map<String, dynamic> m) => AsIfState(
    li: (m['li'] as num?)?.toInt() ?? 0,
    ai: (m['ai'] as num?)?.toInt() ?? 0,
    performed: (m['p'] as num?)?.toInt() ?? 0,
    done: m['d'] == true,
    roundLength: (m['n'] as num?)?.toInt() ?? 0,
    lines: [for (final x in (m['lines'] as List? ?? const [])) x.toString()],
    asifs: [for (final x in (m['asifs'] as List? ?? const [])) x.toString()],
  );

  final int li;
  final int ai;
  final int performed;
  final bool done;

  /// How many prompts make a round.
  final int roundLength;
  final List<String> lines;
  final List<String> asifs;

  String get line => lines.isEmpty ? '' : lines[li % lines.length];
  String get asIf => asifs.isEmpty ? '' : asifs[ai % asifs.length];
}

class AsIfGame extends GameDefinition<AsIfState> {
  const AsIfGame();

  @override
  String get id => 'as-if';

  @override
  String get title => 'Say It As If';

  @override
  RunScript get howToPlay => const [
    RoomBeat('We are playing Say It As If'),
    RoomBeat('You get a line to say'),
    RoomBeat('Say it the way the screen says', detail: 'Big and silly'),
    RoomBeat('Everyone else listens'),
  ];

  @override
  GameVibe get vibe => const GameVibe(accent: GameAccents.coral);

  @override
  Map<String, dynamic> initialState(ContentSource content) =>
      initialStateFor(content, defaultSettingValues(settings));

  @override
  List<GameSetting> get settings => [
    roundLength(label: 'How many prompts'),
  ];

  @override
  Map<String, dynamic> initialStateFor(
    ContentSource content,
    Map<String, Object?> values,
  ) {
    final rounds = roundsFrom(values, fallback: defaultRounds);
    final lines = [
      for (final c in content.take(ContentKind.line, 999))
        c.payload['text']! as String,
    ];
    final asifs = [
      for (final c in content.take(ContentKind.asIf, 999))
        c.payload['text']! as String,
    ];
    return {
      'li': 0,
      'ai': 0,
      'p': 0,
      'd': false,
      'n': lines.isEmpty ? 0 : min(rounds, lines.length),
      'lines': lines,
      'asifs': asifs,
    };
  }

  /// A round is this many prompts. It used to cycle forever; a round that
  /// ends is one a substitute can see the end of.
  static const int defaultRounds = 8;

  @override
  AsIfState decode(Map<String, dynamic> state) => AsIfState.fromMap(state);

  @override
  Map<String, dynamic> reduce(
    Map<String, dynamic> state,
    GameIntent intent,
    Map<String, dynamic> args,
  ) {
    final s = Map<String, dynamic>.from(state);
    final li = (s['li'] as num?)?.toInt() ?? 0;
    final ai = (s['ai'] as num?)?.toInt() ?? 0;
    final p = (s['p'] as num?)?.toInt() ?? 0;
    // A fixture without 'n' (the tests, an older wire) is an endless round,
    // exactly as before; a seeded round ends after its n-th prompt.
    final n = (s['n'] as num?)?.toInt() ?? 0;
    final done = s['d'] == true;
    switch (intent) {
      case GameIntent.tally: // I did it! — count + new challenge.
        if (done) break;
        s['p'] = p + 1;
        s['li'] = li + 1;
        s['ai'] = ai + 1;
        if (n > 0 && li + 1 >= n) s['d'] = true;
      case GameIntent.next: // Another one — new challenge, no count.
        if (done) break;
        s['li'] = li + 1;
        s['ai'] = ai + 1;
        if (n > 0 && li + 1 >= n) s['d'] = true;
      case GameIntent.reset:
        s['li'] = 0;
        s['ai'] = 0;
        s['p'] = 0;
        s['d'] = false;
      case GameIntent.tick:
      case GameIntent.back:
      case GameIntent.reveal:
      case GameIntent.pick:
      case GameIntent.capture:
      case GameIntent.submit:
        break;
    }
    return s;
  }

  @override
  Set<GameIntent> activeIntents(AsIfState s) => s.done
      ? {GameIntent.reset}
      : {GameIntent.tally, GameIntent.next, GameIntent.reset};

  @override
  Widget buildStage(BuildContext context, AsIfState s) {
    final theme = Theme.of(context);
    if (s.done) {
      return GameStage.recap(
        context,
        emoji: '🎭',
        title: s.performed == 0
            ? 'That was Say It As If'
            : 'Acted out ${s.performed}!',
        caption: '${s.roundLength} lines, together.',
      );
    }
    return GameStage.frame(
      context,
      hero: GameStage.hero(context, '“${s.line}”'),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 24),
          GameStage.eyebrow(context, 'As if'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            decoration: BoxDecoration(
              color: vibe.accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: vibe.accent.withValues(alpha: 0.55)),
            ),
            child: Text(
              s.asIf,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: AppColors.readableOnDark(vibe.accent),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (s.performed > 0) ...[
            const SizedBox(height: 24),
            Text(
              'Acted out ${s.performed}',
              style: const TextStyle(color: Colors.white38),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget? buildControls(
    BuildContext context,
    AsIfState state,
    void Function(GameIntent intent, [Map<String, dynamic> args]) send,
  ) => state.done
      ? playAgainControls(send)
      : tallyControls(
          send: send,
          tallyLabel: 'I did it!',
          nextLabel: 'Another one',
        );
}
