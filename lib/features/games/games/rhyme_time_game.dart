import 'dart:math';

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/facilitation/room_beat.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_settings.dart';
import 'package:differentworld/features/games/game_stage.dart';
import 'package:differentworld/features/games/games/tally_controls.dart';
import 'package:flutter/material.dart';

/// Rhyme Time on the unified framework (game.dart names it as an intended
/// game). A word shows big; the room shouts rhymes ALOUD; the teacher taps the
/// tally. Teacher-paced, no typing, no grading. Now present/live for free.
class RhymeState {
  const RhymeState({
    this.index = 0,
    this.found = 0,
    this.total = 0,
    this.done = false,
    this.round = 0,
    this.words = const [],
  });

  factory RhymeState.fromMap(Map<String, dynamic> m) => RhymeState(
    index: (m['i'] as num?)?.toInt() ?? 0,
    found: (m['f'] as num?)?.toInt() ?? 0,
    total: (m['t'] as num?)?.toInt() ?? 0,
    done: m['d'] == true,
    round: (m['n'] as num?)?.toInt() ?? 0,
    words: [for (final w in (m['words'] as List? ?? const [])) w.toString()],
  );

  final int index;

  /// Rhymes found for the CURRENT word.
  final int found;

  /// Rhymes found over the whole round — what the recap reports.
  final int total;
  final bool done;

  /// How many words make a round.
  final int round;
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
  RunScript get howToPlay => const [
    RoomBeat('We are playing Rhyme Time'),
    RoomBeat('A word comes up big'),
    RoomBeat('Shout words that rhyme', detail: 'As many as you can find'),
  ];

  @override
  GameVibe get vibe => const GameVibe(accent: GameAccents.teal);

  /// A round is this many words. The bank holds fifty-odd; a round that ran
  /// through all of them was a round with no ending, which is not a game.
  static const int defaultRounds = 8;

  @override
  Map<String, dynamic> initialState(ContentSource content) =>
      initialStateFor(content, defaultSettingValues(settings));

  @override
  List<GameSetting> get settings => [
    roundLength(label: 'How many words'),
  ];

  @override
  Map<String, dynamic> initialStateFor(
    ContentSource content,
    Map<String, Object?> values,
  ) {
    final rounds = roundsFrom(values, fallback: defaultRounds);
    final words = [
      for (final c in (content.take(ContentKind.rhymeWord, 1000)..shuffle()))
        c.payload['word']! as String,
    ];
    return {
      'i': 0,
      'f': 0,
      't': 0,
      'd': false,
      'n': min(rounds, words.length),
      'words': words,
    };
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
    final t = (s['t'] as num?)?.toInt() ?? 0;
    final n = (s['n'] as num?)?.toInt() ?? 0;
    final done = s['d'] == true;
    switch (intent) {
      case GameIntent.tally: // Someone rhymed it.
        if (done) break;
        s['f'] = f + 1;
        s['t'] = t + 1;
      case GameIntent.next: // New word — or, past the last one, the end.
        // It used to wrap: `(i + 1) % n` sent the room silently back to word
        // one with no signal that anything had happened. A round ENDS now,
        // and says how many rhymes it found on the way.
        if (done) break;
        if (n > 0 && i >= n - 1) {
          s['d'] = true;
        } else {
          s['i'] = i + 1;
        }
        s['f'] = 0;
      case GameIntent.reset: // Start over.
        s['i'] = 0;
        s['f'] = 0;
        s['t'] = 0;
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
  Set<GameIntent> activeIntents(RhymeState s) => s.done
      ? {GameIntent.reset}
      : {GameIntent.tally, GameIntent.next, GameIntent.reset};

  @override
  Widget buildStage(BuildContext context, RhymeState s) {
    final theme = Theme.of(context);
    if (s.done) {
      return GameStage.recap(
        context,
        emoji: '🎶',
        title: s.total == 0 ? 'That was Rhyme Time' : '${s.total} rhymes!',
        caption: '${s.round} words, together.',
      );
    }
    return GameStage.frame(
      context,
      eyebrow: 'Rhyme with',
      hero: Text(
        s.word,
        textAlign: TextAlign.center,
        style: theme.textTheme.displayMedium?.copyWith(
          color: vibe.accent,
          fontWeight: FontWeight.w400,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 24),
        child: GameStage.counter(
          context,
          value: '${s.found}',
          caption: 'found',
          accent: vibe.accent,
        ),
      ),
    );
  }

  @override
  Widget? buildControls(
    BuildContext context,
    RhymeState state,
    void Function(GameIntent intent, [Map<String, dynamic> args]) send,
  ) => state.done
      ? playAgainControls(send)
      : tallyControls(
          send: send,
          tallyLabel: 'Someone rhymed it!',
          nextLabel: 'New word',
        );
}
