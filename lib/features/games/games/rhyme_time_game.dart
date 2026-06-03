import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/games/tally_controls.dart';
import 'package:flutter/material.dart';

/// Rhyme Time on the unified framework (game.dart names it as an intended
/// game). A word shows big; the room shouts rhymes ALOUD; the teacher taps the
/// tally. Teacher-paced, no typing, no grading. Now present/live for free.
class RhymeState {
  const RhymeState({this.index = 0, this.found = 0, this.words = const []});

  factory RhymeState.fromMap(Map<String, dynamic> m) => RhymeState(
        index: (m['i'] as num?)?.toInt() ?? 0,
        found: (m['f'] as num?)?.toInt() ?? 0,
        words: [for (final w in (m['words'] as List? ?? const [])) w.toString()],
      );

  final int index;
  final int found;
  final List<String> words;

  String get word => words.isEmpty ? '' : words[index % words.length];
}

class RhymeTimeGame extends GameDefinition<RhymeState> {
  const RhymeTimeGame();

  @override
  String get id => 'rhyme-time';

  @override
  String get title => 'Rhyme Time';

  @override
  GameVibe get vibe =>
      const GameVibe(accent: Color(0xFF26A69A), surface: Color(0xFF06100F));

  @override
  String? get liveRoute => '/live/rhyme-time';

  @override
  Map<String, dynamic> initialState(ContentSource content) {
    final words = [
      for (final c in (content.take(ContentKind.rhymeWord, 1000)..shuffle()))
        c.payload['word']! as String,
    ];
    return {'i': 0, 'f': 0, 'n': words.length, 'words': words};
  }

  @override
  RhymeState decode(Map<String, dynamic> state) => RhymeState.fromMap(state);

  @override
  Map<String, dynamic> reduce(
    Map<String, dynamic> state,
    GameIntent intent,
    Map<String, dynamic> args,
  ) {
    final s = Map<String, dynamic>.from(state);
    final i = (s['i'] as num?)?.toInt() ?? 0;
    final f = (s['f'] as num?)?.toInt() ?? 0;
    final n = (s['n'] as num?)?.toInt() ?? 0;
    switch (intent) {
      case GameIntent.tally: // Someone rhymed it.
        s['f'] = f + 1;
      case GameIntent.next: // New word (resets the count for the new word).
        if (n > 0) s['i'] = (i + 1) % n;
        s['f'] = 0;
      case GameIntent.reset: // Start over.
        s['i'] = 0;
        s['f'] = 0;
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
  Set<GameIntent> activeIntents(RhymeState s) =>
      {GameIntent.tally, GameIntent.next, GameIntent.reset};

  @override
  Widget buildStage(BuildContext context, RhymeState s) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'RHYME WITH',
            style: TextStyle(
              color: Colors.white54,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            s.word,
            textAlign: TextAlign.center,
            style: theme.textTheme.displayMedium?.copyWith(
              color: vibe.accent,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '${s.found}',
            style: TextStyle(
              color: vibe.accent,
              fontSize: 64,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Text('found', style: TextStyle(color: Colors.white38)),
        ],
      ),
    );
  }

  @override
  Widget? buildControls(
    BuildContext context,
    RhymeState state,
    void Function(GameIntent intent, [Map<String, dynamic> args]) send,
  ) =>
      tallyControls(
        send: send,
        tallyLabel: 'Someone rhymed it!',
        nextLabel: 'New word',
      );
}
