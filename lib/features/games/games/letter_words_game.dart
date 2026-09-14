import 'dart:math';

import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/facilitation/room_beat.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_settings.dart';
import 'package:differentworld/features/games/game_stage.dart';
import 'package:differentworld/features/games/games/tally_controls.dart';
import 'package:flutter/material.dart';

/// "Name things that start with this letter" on the unified framework. The
/// room sees a big letter + a category and shouts answers ALOUD; the teacher
/// taps the tally. Teacher-paced, no typing, no grading. Now present/live.
class LetterWordsState {
  const LetterWordsState({
    this.index = 0,
    this.found = 0,
    this.total = 0,
    this.done = false,
    this.roundLength = 0,
    this.rounds = const [],
  });

  factory LetterWordsState.fromMap(Map<String, dynamic> m) => LetterWordsState(
    index: (m['i'] as num?)?.toInt() ?? 0,
    found: (m['f'] as num?)?.toInt() ?? 0,
    total: (m['t'] as num?)?.toInt() ?? 0,
    done: m['d'] == true,
    roundLength: (m['n'] as num?)?.toInt() ?? 0,
    rounds: [
      for (final r in (m['rounds'] as List? ?? const []))
        [for (final x in (r as List)) x.toString()],
    ],
  );

  final int index;

  /// Words found for the CURRENT letter.
  final int found;

  /// Words found over the whole round — what the recap reports.
  final int total;
  final bool done;

  /// How many letters make a round.
  final int roundLength;

  /// `[letter, categoryLabel]` per round.
  final List<List<String>> rounds;

  List<String> get _round =>
      rounds.isEmpty ? const ['A', 'a word'] : rounds[index % rounds.length];
  String get letter => _round[0];
  String get category => _round[1];
}

class LetterWordsGame extends GameDefinition<LetterWordsState> {
  const LetterWordsGame();

  static const _letters = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', //
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
  ];

  @override
  String get id => 'letter-words';

  @override
  String get title => 'Beat the Letter';

  @override
  RunScript get howToPlay => const [
    RoomBeat('We are playing Beat the Letter'),
    RoomBeat('You get a letter and a kind of thing'),
    RoomBeat('Shout ones that start with it'),
  ];

  @override
  GameVibe get vibe => const GameVibe(accent: GameAccents.amber);

  @override
  Map<String, dynamic> initialState(ContentSource content) =>
      initialStateFor(content, defaultSettingValues(settings));

  @override
  List<GameSetting> get settings => [
    roundLength(label: 'How many letters'),
  ];

  @override
  Map<String, dynamic> initialStateFor(
    ContentSource content,
    Map<String, Object?> values,
  ) {
    // `count` not `rounds`: the list of [letter, category] pairs below is
    // already called rounds, and it is the better owner of the name.
    final count = roundsFrom(values, fallback: defaultRounds);
    final categories = [
      for (final c in content.take(ContentKind.category, 1000))
        c.payload['label']! as String,
    ];
    final labels = categories.isEmpty ? ['a word'] : categories;
    final rng = Random();
    // Pre-build a varied sequence so every device shows the same rounds (the
    // presenter broadcasts these). Cycle categories, fresh non-repeating
    // letter each round.
    final rounds = <List<String>>[];
    var prev = '';
    for (var k = 0; k < count; k++) {
      var pick = _letters[rng.nextInt(_letters.length)];
      while (pick == prev) {
        pick = _letters[rng.nextInt(_letters.length)];
      }
      prev = pick;
      rounds.add([pick, labels[k % labels.length]]);
    }
    return {
      'i': 0,
      'f': 0,
      't': 0,
      'd': false,
      'n': rounds.length,
      'rounds': rounds,
    };
  }

  /// A round is this many letters. It used to be thirty, wrapping back to
  /// the first with no signal — a round with no ending is not a game.
  static const int defaultRounds = 8;

  @override
  LetterWordsState decode(Map<String, dynamic> state) =>
      LetterWordsState.fromMap(state);

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
      case GameIntent.tally: // Someone said it.
        if (done) break;
        s['f'] = f + 1;
        s['t'] = t + 1;
      case GameIntent.next: // New letter — or, past the last, the end.
        if (done) break;
        if (n > 0 && i >= n - 1) {
          s['d'] = true;
        } else {
          s['i'] = i + 1;
        }
        s['f'] = 0;
      case GameIntent.reset:
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
  Set<GameIntent> activeIntents(LetterWordsState s) => s.done
      ? {GameIntent.reset}
      : {GameIntent.tally, GameIntent.next, GameIntent.reset};

  @override
  Widget buildStage(BuildContext context, LetterWordsState s) {
    final theme = Theme.of(context);
    if (s.done) {
      return GameStage.recap(
        context,
        emoji: '🔤',
        title: s.total == 0 ? 'That was Beat the Letter' : '${s.total} words!',
        caption: '${s.roundLength} letters, together.',
      );
    }
    return GameStage.frame(
      context,
      eyebrow: 'Starts with',
      hero: Container(
        width: 132,
        height: 132,
        decoration: BoxDecoration(color: vibe.accent, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(
          s.letter,
          style: TextStyle(
            color: AppColors.onAccent(vibe.accent),
            fontSize: 72,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 20),
          Text(
            'Name ${s.category} that starts with ${s.letter}',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 20),
          GameStage.counter(
            context,
            value: '${s.found}',
            caption: 'found',
            accent: vibe.accent,
          ),
        ],
      ),
    );
  }

  @override
  Widget? buildControls(
    BuildContext context,
    LetterWordsState state,
    void Function(GameIntent intent, [Map<String, dynamic> args]) send,
  ) => state.done
      ? playAgainControls(send)
      : tallyControls(
          send: send,
          tallyLabel: 'Someone said it',
          nextLabel: 'New letter',
        );
}
