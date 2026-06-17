import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
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
    this.lines = const [],
    this.asifs = const [],
  });

  factory AsIfState.fromMap(Map<String, dynamic> m) => AsIfState(
        li: (m['li'] as num?)?.toInt() ?? 0,
        ai: (m['ai'] as num?)?.toInt() ?? 0,
        performed: (m['p'] as num?)?.toInt() ?? 0,
        lines: [for (final x in (m['lines'] as List? ?? const [])) x.toString()],
        asifs: [for (final x in (m['asifs'] as List? ?? const [])) x.toString()],
      );

  final int li;
  final int ai;
  final int performed;
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
  String get title => 'As If';

  @override
  GameVibe get vibe =>
      const GameVibe(accent: GameAccents.coral);

  @override
  String? get liveRoute => '/live/as-if';

  @override
  Map<String, dynamic> initialState(ContentSource content) {
    final lines = [
      for (final c in content.take(ContentKind.line, 999))
        c.payload['text']! as String,
    ];
    final asifs = [
      for (final c in content.take(ContentKind.asIf, 999))
        c.payload['text']! as String,
    ];
    return {'li': 0, 'ai': 0, 'p': 0, 'lines': lines, 'asifs': asifs};
  }

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
    switch (intent) {
      case GameIntent.tally: // I did it! — count + new challenge.
        s['p'] = p + 1;
        s['li'] = li + 1;
        s['ai'] = ai + 1;
      case GameIntent.next: // Another one — new challenge, no count.
        s['li'] = li + 1;
        s['ai'] = ai + 1;
      case GameIntent.reset:
        s['li'] = 0;
        s['ai'] = 0;
        s['p'] = 0;
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
  Set<GameIntent> activeIntents(AsIfState s) =>
      {GameIntent.tally, GameIntent.next, GameIntent.reset};

  @override
  Widget buildStage(BuildContext context, AsIfState s) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.theater_comedy, color: vibe.accent, size: 44),
              const SizedBox(height: 12),
              const Text(
                'SAY IT…',
                style: TextStyle(
                  color: Colors.white60,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '“${s.line}”',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'AS IF',
                style: TextStyle(
                  color: Colors.white60,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: vibe.accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: vibe.accent.withValues(alpha: 0.6)),
                ),
                child: Text(
                  s.asIf,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: vibe.accent,
                    fontWeight: FontWeight.w800,
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
        ),
      ),
    );
  }

  @override
  Widget? buildControls(
    BuildContext context,
    AsIfState state,
    void Function(GameIntent intent, [Map<String, dynamic> args]) send,
  ) =>
      tallyControls(
        send: send,
        tallyLabel: 'I did it!',
        nextLabel: 'Another one',
      );
}
