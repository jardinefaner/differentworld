import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/cards/card_tile.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:flutter/material.dart';

/// What's Missing (docs/CARD_GAMES.md) — a working-memory game over the picture
/// deck. A set of pictures goes up; the room studies them; the teacher hides
/// one; the room calls what vanished; Reveal flips it back. Three beats per
/// round (study → quiz → reveal), so it overrides the standard bar with its own
/// phase-aware controls. Deck-seeded by `WhatsMissingScreen` (assets), so the
/// full set + which card hides ride the wire-state — a joined controller sees
/// the same board.
class MissingRound {
  const MissingRound({required this.cards, required this.missingIndex});

  factory MissingRound.fromMap(Map<String, dynamic> m) => MissingRound(
        cards: [
          for (final c in (m['cards'] as List? ?? const <dynamic>[]))
            (
              image: (c as Map)['image'] as String? ?? '',
              label: c['label'] as String? ?? '',
            ),
        ],
        missingIndex: (m['missing'] as num?)?.toInt() ?? 0,
      );

  /// The full set, in stable positions (the missing one is hidden in place
  /// during the quiz so kids can track where it was).
  final List<({String image, String label})> cards;
  final int missingIndex;

  ({String image, String label})? get missing =>
      (missingIndex >= 0 && missingIndex < cards.length)
          ? cards[missingIndex]
          : null;
}

/// The three beats of a round.
enum MissingPhase { study, quiz, revealed }

class WhatsMissingState {
  const WhatsMissingState({
    required this.rounds,
    required this.index,
    required this.phase,
    required this.done,
  });

  factory WhatsMissingState.fromMap(Map<String, dynamic> m) => WhatsMissingState(
        rounds: [
          for (final r in (m['rounds'] as List? ?? const <dynamic>[]))
            MissingRound.fromMap(Map<String, dynamic>.from(r as Map)),
        ],
        index: (m['i'] as num?)?.toInt() ?? 0,
        phase: MissingPhase
            .values[((m['phase'] as num?)?.toInt() ?? 0).clamp(0, 2)],
        done: m['d'] as bool? ?? false,
      );

  final List<MissingRound> rounds;
  final int index;
  final MissingPhase phase;
  final bool done;

  MissingRound? get current =>
      (index >= 0 && index < rounds.length) ? rounds[index] : null;
  bool get isLast => index >= rounds.length - 1;
}

class WhatsMissingGame extends GameDefinition<WhatsMissingState> {
  const WhatsMissingGame();

  // Deck-seeded by the wrapper (assets), not the content bank — hidden from the
  // cast launcher until cast can pass it a seed (same as Name It).
  @override
  bool get seedsFromContentBank => false;

  @override
  String get id => 'whats-missing';

  @override
  String get title => "What's Missing";

  @override
  GameVibe get vibe =>
      const GameVibe(accent: Color(0xFFEC407A), surface: Color(0xFF1A0A12));

  @override
  String? get liveRoute => '/live/whats-missing';

  @override
  Map<String, dynamic> initialState(ContentSource content) => {
        'rounds': const <Map<String, dynamic>>[],
        'i': 0,
        'phase': 0,
        'd': false,
      };

  @override
  WhatsMissingState decode(Map<String, dynamic> state) =>
      WhatsMissingState.fromMap(state);

  @override
  Map<String, dynamic> reduce(
    Map<String, dynamic> state,
    GameIntent intent,
    Map<String, dynamic> args,
  ) {
    final s = Map<String, dynamic>.from(state);
    final n = (s['rounds'] as List? ?? const <dynamic>[]).length;
    final i = (s['i'] as num?)?.toInt() ?? 0;
    final phase = (s['phase'] as num?)?.toInt() ?? 0;
    switch (intent) {
      case GameIntent.reveal:
        // Advance the beat: study → quiz (hide one) → revealed (show it).
        s['phase'] = (phase + 1).clamp(0, 2);
      case GameIntent.next:
        if (i < n - 1) {
          s['i'] = i + 1;
          s['phase'] = 0;
        } else {
          s['d'] = true;
        }
      case GameIntent.back:
        if (i > 0) {
          s['i'] = i - 1;
          s['phase'] = 0;
          s['d'] = false;
        } else {
          // Within the first round, Back steps the beat down (un-hide).
          s['phase'] = (phase - 1).clamp(0, 2);
        }
      case GameIntent.reset:
        s['i'] = 0;
        s['phase'] = 0;
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
  Set<GameIntent> activeIntents(WhatsMissingState s) => {
        if (s.index > 0 || s.phase != MissingPhase.study) GameIntent.back,
        if (s.phase != MissingPhase.revealed) GameIntent.reveal,
        if (!s.isLast) GameIntent.next,
        GameIntent.reset,
      };

  @override
  Widget buildStage(BuildContext context, WhatsMissingState s) {
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
    return _MissingStage(round: round, phase: s.phase, accent: vibe.accent);
  }

  // Three beats need three control layouts — the standard Reveal/Next bar can't
  // express study → quiz → revealed, so the game owns its controls.
  @override
  Widget? buildControls(
    BuildContext context,
    WhatsMissingState state,
    void Function(GameIntent intent, [Map<String, dynamic> args]) send,
  ) =>
      _MissingControls(state: state, accent: vibe.accent, send: send);
}

/// The board: the full set of cards in stable positions. During the quiz the
/// missing card's slot shows a "?"; on reveal it flips back with an accent ring.
class _MissingStage extends StatelessWidget {
  const _MissingStage({
    required this.round,
    required this.phase,
    required this.accent,
  });

  final MissingRound round;
  final MissingPhase phase;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = switch (phase) {
      MissingPhase.study => 'Remember these…',
      MissingPhase.quiz => "What's missing?",
      MissingPhase.revealed => round.missing?.label.isNotEmpty ?? false
          ? 'It was the ${round.missing!.label}!'
          : 'There it is!',
    };
    final cols = round.cards.length <= 4 ? 2 : 3;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Column(
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 16),
            // Fractional Column-of-Rows (not GridView) so the board can't
            // RenderFlex-overflow in landscape on a phone — every cell is an
            // exact fraction of the bounded Expanded.
            Expanded(
              child: Column(
                children: [
                  for (var row = 0; row * cols < round.cards.length; row++)
                    Expanded(
                      child: Row(
                        children: [
                          for (var col = 0; col < cols; col++)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: _slot(row * cols + col),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
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
    return _MissingCard(
      image: round.cards[k].image,
      // Hidden only during the quiz beat.
      hidden: phase == MissingPhase.quiz && k == round.missingIndex,
      highlight: phase == MissingPhase.revealed && k == round.missingIndex,
      accent: accent,
    );
  }
}

class _MissingCard extends StatelessWidget {
  const _MissingCard({
    required this.image,
    required this.hidden,
    required this.highlight,
    required this.accent,
  });

  final String image;
  final bool hidden;
  final bool highlight;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (hidden) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent, width: 2),
        ),
        child: Center(
          child: Text(
            '?',
            style: TextStyle(
              color: accent,
              fontSize: 56,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlight ? accent : Colors.white,
          width: 4,
        ),
      ),
      child: CardTile(image: image),
    );
  }
}

/// Phase-aware controls: study → "Hide one", quiz → "Reveal it" / "Peek again",
/// revealed → "Next set" / "Play again". The done state lands on "Play again".
class _MissingControls extends StatelessWidget {
  const _MissingControls({
    required this.state,
    required this.accent,
    required this.send,
  });

  final WhatsMissingState state;
  final Color accent;
  final void Function(GameIntent intent, [Map<String, dynamic> args]) send;

  @override
  Widget build(BuildContext context) {
    if (state.done) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => send(GameIntent.reset),
          icon: const Icon(Icons.replay),
          label: const Text('Play again'),
        ),
      );
    }
    return switch (state.phase) {
      MissingPhase.study => SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => send(GameIntent.reveal),
            icon: const Icon(Icons.visibility_off_outlined),
            label: const Text('Hide one'),
          ),
        ),
      MissingPhase.quiz => Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => send(GameIntent.back),
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Peek again'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => send(GameIntent.reveal),
                icon: const Icon(Icons.lightbulb_outline),
                label: const Text('Reveal it'),
              ),
            ),
          ],
        ),
      MissingPhase.revealed => Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => send(GameIntent.reset),
                icon: const Icon(Icons.replay),
                label: const Text('Start over'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => send(GameIntent.next),
                icon: const Icon(Icons.arrow_forward),
                label: Text(state.isLast ? 'Finish' : 'Next set'),
              ),
            ),
          ],
        ),
    };
  }
}
