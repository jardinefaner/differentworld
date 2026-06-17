import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/cards/card_tile.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:flutter/material.dart';

/// Odd One Out (docs/CARD_GAMES.md) — four pictures go up; three share a
/// category, one is the stranger. The room calls the odd card out loud; the
/// teacher taps Reveal and it rings itself while the others dim. Pure
/// categorization over the picture deck — the "what goes together / what
/// doesn't" win. Deck-seeded by `OddOneOutScreen` (assets, not the content
/// bank), so each round rides the wire-state and a joined controller sees the
/// same four cards. Follows the `i/n/d/r` convention → inherits the standard
/// Back / Reveal / Next / Again bar for free.
class OddRound {
  const OddRound({required this.cards, required this.answer});

  factory OddRound.fromMap(Map<String, dynamic> m) => OddRound(
        cards: [
          for (final c in (m['cards'] as List? ?? const <dynamic>[]))
            (
              image: (c as Map)['image'] as String? ?? '',
              label: c['label'] as String? ?? '',
            ),
        ],
        answer: (m['answer'] as num?)?.toInt() ?? 0,
      );

  final List<({String image, String label})> cards;
  final int answer;

  ({String image, String label})? get odd =>
      (answer >= 0 && answer < cards.length) ? cards[answer] : null;
}

class OddOneOutState {
  const OddOneOutState({
    required this.rounds,
    required this.index,
    required this.revealed,
    required this.done,
  });

  factory OddOneOutState.fromMap(Map<String, dynamic> m) => OddOneOutState(
        rounds: [
          for (final r in (m['rounds'] as List? ?? const <dynamic>[]))
            OddRound.fromMap(Map<String, dynamic>.from(r as Map)),
        ],
        index: (m['i'] as num?)?.toInt() ?? 0,
        revealed: m['r'] as bool? ?? false,
        done: m['d'] as bool? ?? false,
      );

  final List<OddRound> rounds;
  final int index;
  final bool revealed;
  final bool done;

  OddRound? get current =>
      (index >= 0 && index < rounds.length) ? rounds[index] : null;
}

class OddOneOutGame extends GameDefinition<OddOneOutState> {
  const OddOneOutGame();

  // Deck-seeded by the wrapper (assets), not the content bank — hidden from the
  // cast launcher until cast can pass it a seed (same as Name It).
  @override
  bool get seedsFromContentBank => false;

  @override
  String get id => 'odd-one-out';

  @override
  String get title => 'Odd One Out';

  @override
  GameVibe get vibe =>
      const GameVibe(accent: GameAccents.coral);

  @override
  String? get liveRoute => '/live/odd-one-out';

  @override
  Map<String, dynamic> initialState(ContentSource content) => {
        'rounds': const <Map<String, dynamic>>[],
        'i': 0,
        'r': false,
        'd': false,
      };

  @override
  OddOneOutState decode(Map<String, dynamic> state) =>
      OddOneOutState.fromMap(state);

  @override
  Map<String, dynamic> reduce(
    Map<String, dynamic> state,
    GameIntent intent,
    Map<String, dynamic> args,
  ) {
    final s = Map<String, dynamic>.from(state);
    final n = (s['rounds'] as List? ?? const <dynamic>[]).length;
    final i = (s['i'] as num?)?.toInt() ?? 0;
    switch (intent) {
      case GameIntent.next:
        if (i < n - 1) {
          s['i'] = i + 1;
          s['r'] = false;
        } else {
          s['d'] = true;
        }
      case GameIntent.back:
        if (i > 0) {
          s['i'] = i - 1;
          s['r'] = false;
          s['d'] = false;
        }
      case GameIntent.reveal:
        s['r'] = true;
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
  Set<GameIntent> activeIntents(OddOneOutState s) => {
        if (s.index > 0) GameIntent.back,
        if (!s.revealed) GameIntent.reveal,
        if (s.index < s.rounds.length - 1) GameIntent.next,
      };

  @override
  Widget buildStage(BuildContext context, OddOneOutState s) {
    final round = s.current;
    if (round == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No cards yet.\nAdd a deck to play.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, fontSize: 18),
          ),
        ),
      );
    }
    return _OddStage(round: round, revealed: s.revealed, accent: vibe.accent);
  }
}

/// Four cards in a 2×2 grid. On Reveal the odd one rings in the game accent and
/// the three matching cards dim — the visual "this is the stranger" beat.
class _OddStage extends StatelessWidget {
  const _OddStage({
    required this.round,
    required this.revealed,
    required this.accent,
  });

  final OddRound round;
  final bool revealed;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Column(
          children: [
            Text(
              revealed ? 'It doesn’t belong!' : 'Which one doesn’t belong?',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Column(
                children: [
                  for (var row = 0; row < 2; row++)
                    Expanded(
                      child: Row(
                        children: [
                          for (var col = 0; col < 2; col++)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: _slot(row * 2 + col),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // The stranger's name lands when it's revealed — the teacher names
            // what the room spotted.
            AnimatedOpacity(
              opacity: revealed && (round.odd?.label.isNotEmpty ?? false) ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              child: Text(
                round.odd?.label ?? '',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _slot(int k) {
    if (k >= round.cards.length) return const SizedBox.shrink();
    return _OddCard(
      image: round.cards[k].image,
      isOdd: k == round.answer,
      revealed: revealed,
      accent: accent,
    );
  }
}

class _OddCard extends StatelessWidget {
  const _OddCard({
    required this.image,
    required this.isOdd,
    required this.revealed,
    required this.accent,
  });

  final String image;
  final bool isOdd;
  final bool revealed;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final highlight = revealed && isOdd;
    final dim = revealed && !isOdd;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 240),
      opacity: dim ? 0.35 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: highlight ? accent : Colors.white,
            width: 4,
          ),
        ),
        child: CardTile(image: image),
      ),
    );
  }
}
