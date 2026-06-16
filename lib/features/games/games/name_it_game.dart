import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/cards/card_tile.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:flutter/material.dart';

/// Name It (docs/CARD_GAMES.md) — the picture goes up, the room says the word,
/// the teacher taps Reveal to show it (+ voiceover later). Pure Reveal over a
/// picture deck: the morning-vocabulary win, pre-reader-friendly. Deck-seeded
/// by `NameItScreen` (the deck loads from assets), so the cards ride in the
/// wire-state and a joined controller shows the same card. Follows the
/// `i/n/d/r` convention → inherits the standard Back / Reveal / Next / Again
/// bar for free.
class NameItCard {
  const NameItCard(this.image, this.label);
  final String image;
  final String label;
}

class NameItState {
  const NameItState({
    required this.cards,
    required this.index,
    required this.revealed,
    required this.done,
  });

  factory NameItState.fromMap(Map<String, dynamic> m) => NameItState(
        cards: [
          for (final c in (m['cards'] as List? ?? const []))
            NameItCard((c as Map)['image'] as String, c['label'] as String),
        ],
        index: (m['i'] as num?)?.toInt() ?? 0,
        revealed: m['r'] as bool? ?? false,
        done: m['d'] as bool? ?? false,
      );

  final List<NameItCard> cards;
  final int index;
  final bool revealed;
  final bool done;

  NameItCard? get current =>
      (index >= 0 && index < cards.length) ? cards[index] : null;
}

class NameItGame extends GameDefinition<NameItState> {
  const NameItGame();

  // Deck-seeded by the wrapper (assets), not the content bank — hidden from the
  // cast launcher until cast can pass it a seed (same as Now & Next).
  @override
  bool get seedsFromContentBank => false;

  @override
  String get id => 'name-it';

  @override
  String get title => 'Name It';

  @override
  GameVibe get vibe => const GameVibe(accent: Color(0xFF7C4DFF));

  @override
  String? get liveRoute => '/live/name-it';

  @override
  Map<String, dynamic> initialState(ContentSource content) => {
        'cards': const <Map<String, String>>[],
        'i': 0,
        'r': false,
        'd': false,
      };

  @override
  NameItState decode(Map<String, dynamic> state) => NameItState.fromMap(state);

  @override
  Map<String, dynamic> reduce(
    Map<String, dynamic> state,
    GameIntent intent,
    Map<String, dynamic> args,
  ) {
    final s = Map<String, dynamic>.from(state);
    final n = (s['cards'] as List? ?? const []).length;
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
  Set<GameIntent> activeIntents(NameItState s) => {
        if (s.index > 0) GameIntent.back,
        if (!s.revealed) GameIntent.reveal,
        if (s.index < s.cards.length - 1) GameIntent.next,
      };

  @override
  Widget buildStage(BuildContext context, NameItState s) {
    final theme = Theme.of(context);
    final card = s.current;
    if (card == null) {
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
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        child: Column(
          children: [
            Expanded(child: CardTile(image: card.image)),
            const SizedBox(height: 20),
            // The word — hidden until Reveal. Pre-readers say it; the teacher
            // confirms with a tap.
            AnimatedOpacity(
              opacity: s.revealed ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              child: Text(
                card.label,
                textAlign: TextAlign.center,
                style: theme.textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (!s.revealed)
              Text(
                'What is it?',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white54,
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
