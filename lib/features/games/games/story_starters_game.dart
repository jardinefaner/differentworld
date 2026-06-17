import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:flutter/material.dart';

/// Story Starters on the unified framework. An opener shows big; the room
/// builds the story aloud, one line each around the circle; the teacher drops
/// a "Plot twist!" any time, then moves to a new start. No typing, no grading.
/// Now present/live for free.
class StoryState {
  const StoryState({
    this.index = 0,
    this.twistCursor = 0,
    this.twist = '',
    this.done = false,
    this.starters = const [],
    this.twists = const [],
  });

  factory StoryState.fromMap(Map<String, dynamic> m) => StoryState(
        index: (m['i'] as num?)?.toInt() ?? 0,
        twistCursor: (m['ti'] as num?)?.toInt() ?? 0,
        twist: (m['tw'] as String?) ?? '',
        done: m['d'] == true,
        starters: [
          for (final x in (m['starters'] as List? ?? const [])) x.toString(),
        ],
        twists: [
          for (final x in (m['twists'] as List? ?? const [])) x.toString(),
        ],
      );

  final int index;
  final int twistCursor;
  final String twist;
  final bool done;
  final List<String> starters;
  final List<String> twists;

  int get total => starters.length;
  bool get atEnd => index >= starters.length - 1;
  String get starter =>
      starters.isEmpty ? '' : starters[index.clamp(0, starters.length - 1)];
  bool get hasTwist => twist.isNotEmpty;
}

class StoryStartersGame extends GameDefinition<StoryState> {
  const StoryStartersGame();

  @override
  String get id => 'story';

  @override
  String get title => 'Story Starters';

  @override
  GameVibe get vibe =>
      const GameVibe(accent: GameAccents.amber);

  @override
  String? get liveRoute => '/live/story';

  @override
  Map<String, dynamic> initialState(ContentSource content) {
    // 8 fresh openers from the generator (≈51k combinations; the engine skips
    // recently-served ones), then all twists to cycle through.
    final starters = [
      for (final c in content.take(ContentKind.storyStarter, 8))
        c.payload['text']! as String,
    ];
    final twists = [
      for (final c in content.take(ContentKind.storyTwist, 1000))
        c.payload['text']! as String,
    ];
    return {
      'i': 0,
      'ti': 0,
      'tw': '',
      'd': false,
      'n': starters.length,
      'starters': starters,
      'twists': twists,
    };
  }

  @override
  StoryState decode(Map<String, dynamic> state) => StoryState.fromMap(state);

  @override
  Map<String, dynamic> reduce(
    Map<String, dynamic> state,
    GameIntent intent,
    Map<String, dynamic> args,
  ) {
    final s = Map<String, dynamic>.from(state);
    final i = (s['i'] as num?)?.toInt() ?? 0;
    final ti = (s['ti'] as num?)?.toInt() ?? 0;
    final n = (s['n'] as num?)?.toInt() ?? 0;
    final twists = s['twists'] as List? ?? const [];
    switch (intent) {
      case GameIntent.reveal: // Drop a plot twist (cycles).
        if (twists.isNotEmpty) {
          s['tw'] = twists[ti % twists.length].toString();
          s['ti'] = ti + 1;
        }
      case GameIntent.next: // New start (or finish at the end).
        if (i >= n - 1) {
          s['d'] = true;
        } else {
          s['i'] = i + 1;
          s['tw'] = '';
        }
      case GameIntent.reset:
        s['i'] = 0;
        s['ti'] = 0;
        s['tw'] = '';
        s['d'] = false;
      case GameIntent.back:
      case GameIntent.tally:
      case GameIntent.pick:
      case GameIntent.capture:
      case GameIntent.submit:
        break;
    }
    return s;
  }

  @override
  Set<GameIntent> activeIntents(StoryState s) =>
      s.done ? {GameIntent.reset} : {GameIntent.reveal, GameIntent.next};

  @override
  Widget buildStage(BuildContext context, StoryState s) {
    final theme = Theme.of(context);
    if (s.done) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📖', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              'What a story!',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${s.total} stories, all yours.',
              style: const TextStyle(color: Colors.white60),
            ),
          ],
        ),
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Story ${s.index + 1} / ${s.total}',
                style: const TextStyle(
                  color: Colors.white54,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                s.starter,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Build it together — one line each, around the circle.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white38,
                ),
              ),
              if (s.hasTwist) ...[
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: vibe.accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(18),
                    border:
                        Border.all(color: vibe.accent.withValues(alpha: 0.6)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '✨ PLOT TWIST',
                        style: TextStyle(
                          color: Color(0xFFFFCA62),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        s.twist,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
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
    StoryState state,
    void Function(GameIntent intent, [Map<String, dynamic> args]) send,
  ) {
    if (state.done) {
      return Row(
        children: [
          const Spacer(),
          FilledButton.icon(
            onPressed: () => send(GameIntent.reset),
            icon: const Icon(Icons.replay),
            label: const Text('Play again'),
          ),
        ],
      );
    }
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: () => send(GameIntent.reveal),
          style: OutlinedButton.styleFrom(
            foregroundColor: vibe.accent,
            side: BorderSide(color: vibe.accent.withValues(alpha: 0.6)),
          ),
          icon: const Icon(Icons.auto_awesome),
          label: Text(state.hasTwist ? 'Another twist' : 'Add a twist'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.icon(
            onPressed: () => send(GameIntent.next),
            icon: Icon(state.atEnd ? Icons.emoji_events : Icons.arrow_forward),
            label: Text(
              state.atEnd ? 'See the round' : 'New start',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}
