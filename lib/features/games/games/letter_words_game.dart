import 'dart:math';

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/games/tally_controls.dart';
import 'package:flutter/material.dart';

/// "Name things that start with this letter" on the unified framework. The
/// room sees a big letter + a category and shouts answers ALOUD; the teacher
/// taps the tally. Teacher-paced, no typing, no grading. Now present/live.
class LetterWordsState {
  const LetterWordsState({
    this.index = 0,
    this.found = 0,
    this.rounds = const [],
  });

  factory LetterWordsState.fromMap(Map<String, dynamic> m) => LetterWordsState(
        index: (m['i'] as num?)?.toInt() ?? 0,
        found: (m['f'] as num?)?.toInt() ?? 0,
        rounds: [
          for (final r in (m['rounds'] as List? ?? const []))
            [for (final x in (r as List)) x.toString()],
        ],
      );

  final int index;
  final int found;

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
  String get title => 'Letter Words';

  @override
  GameVibe get vibe =>
      const GameVibe(accent: GameAccents.amber);

  @override
  String? get liveRoute => '/live/starts-with';

  @override
  Map<String, dynamic> initialState(ContentSource content) {
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
    for (var k = 0; k < 30; k++) {
      var pick = _letters[rng.nextInt(_letters.length)];
      while (pick == prev) {
        pick = _letters[rng.nextInt(_letters.length)];
      }
      prev = pick;
      rounds.add([pick, labels[k % labels.length]]);
    }
    return {'i': 0, 'f': 0, 'n': rounds.length, 'rounds': rounds};
  }

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
    final n = (s['n'] as num?)?.toInt() ?? 0;
    switch (intent) {
      case GameIntent.tally: // Someone said it.
        s['f'] = f + 1;
      case GameIntent.next: // New letter (resets the count).
        if (n > 0) s['i'] = (i + 1) % n;
        s['f'] = 0;
      case GameIntent.reset:
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
  Set<GameIntent> activeIntents(LetterWordsState s) =>
      {GameIntent.tally, GameIntent.next, GameIntent.reset};

  @override
  Widget buildStage(BuildContext context, LetterWordsState s) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(color: vibe.accent, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(
                s.letter,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 76,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Name ${s.category} that starts with ${s.letter}',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '${s.found}',
              style: theme.textTheme.displayMedium?.copyWith(
                color: vibe.accent,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Text('found', style: TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }

  @override
  Widget? buildControls(
    BuildContext context,
    LetterWordsState state,
    void Function(GameIntent intent, [Map<String, dynamic> args]) send,
  ) =>
      tallyControls(
        send: send,
        tallyLabel: 'Someone said it',
        nextLabel: 'New letter',
      );
}
