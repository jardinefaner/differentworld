import 'dart:math';

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/cards/card_tile.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:flutter/material.dart';

/// Memory / Match (docs/CARD_GAMES.md) — the classic concentration game over
/// the picture deck. Pairs go face-down; tap two; a match stays up, a miss
/// flips back on the next tap (host-paced, so the reducer needs no timer). The
/// big board is the `buildStage` (what the room sees / casts); a compact mirror
/// board is the `buildControls` "remote" the teacher taps — the app's
/// present/remote split, same as Reveal the Picture. Deck-seeded by
/// `MemoryMatchScreen`; the shuffled board rides the wire-state so a joined
/// controller taps the same layout.
class MemoryCard {
  const MemoryCard({required this.image, required this.label, required this.pair});

  factory MemoryCard.fromMap(Map<String, dynamic> m) => MemoryCard(
        image: m['image'] as String? ?? '',
        label: m['label'] as String? ?? '',
        pair: m['pair'] as String? ?? '',
      );

  final String image;
  final String label;

  /// The match key — both copies of a picture share it (the source card id).
  final String pair;
}

/// How a board position currently shows.
enum MemoryCellStatus { down, up, matched }

class MemoryState {
  const MemoryState({
    required this.cards,
    required this.flipped,
    required this.matched,
    required this.done,
  });

  factory MemoryState.fromMap(Map<String, dynamic> m) => MemoryState(
        cards: [
          for (final c in (m['cards'] as List? ?? const <dynamic>[]))
            MemoryCard.fromMap(Map<String, dynamic>.from(c as Map)),
        ],
        flipped: [
          for (final v in (m['flipped'] as List? ?? const <dynamic>[]))
            (v as num).toInt(),
        ],
        matched: {
          for (final v in (m['matched'] as List? ?? const <dynamic>[]))
            (v as num).toInt(),
        },
        done: m['d'] as bool? ?? false,
      );

  final List<MemoryCard> cards;

  /// The 0–2 positions currently face-up under evaluation.
  final List<int> flipped;

  /// Positions permanently matched (stay face-up).
  final Set<int> matched;
  final bool done;

  int get pairsTotal => cards.length ~/ 2;
  int get pairsFound => matched.length ~/ 2;

  MemoryCellStatus statusOf(int i) {
    if (matched.contains(i)) return MemoryCellStatus.matched;
    if (flipped.contains(i)) return MemoryCellStatus.up;
    return MemoryCellStatus.down;
  }
}

class MemoryMatchGame extends GameDefinition<MemoryState> {
  const MemoryMatchGame();

  // Deck-seeded by the wrapper (assets), not the content bank — hidden from the
  // cast launcher until cast can pass it a seed (same as Name It).
  @override
  bool get seedsFromContentBank => false;

  @override
  String get id => 'memory-match';

  @override
  String get title => 'Memory';

  @override
  GameVibe get vibe =>
      const GameVibe(accent: GameAccents.plum);

  @override
  String? get liveRoute => '/live/memory-match';

  @override
  Map<String, dynamic> initialState(ContentSource content) => {
        'cards': const <Map<String, dynamic>>[],
        'flipped': const <int>[],
        'matched': const <int>[],
        'd': false,
      };

  @override
  MemoryState decode(Map<String, dynamic> state) => MemoryState.fromMap(state);

  @override
  Map<String, dynamic> reduce(
    Map<String, dynamic> state,
    GameIntent intent,
    Map<String, dynamic> args,
  ) {
    final s = Map<String, dynamic>.from(state);
    final cards = [
      for (final c in (s['cards'] as List? ?? const <dynamic>[]))
        MemoryCard.fromMap(Map<String, dynamic>.from(c as Map)),
    ];
    final flipped = [
      for (final v in (s['flipped'] as List? ?? const <dynamic>[]))
        (v as num).toInt(),
    ];
    final matched = <int>{
      for (final v in (s['matched'] as List? ?? const <dynamic>[]))
        (v as num).toInt(),
    };
    switch (intent) {
      case GameIntent.pick:
        final i = (args['cell'] as num?)?.toInt();
        if (i == null || i < 0 || i >= cards.length) break;
        // Already settled or already showing → no-op.
        if (matched.contains(i) || flipped.contains(i)) break;
        if (flipped.length >= 2) {
          // The two showing are a resolved mismatch — clear them, start fresh.
          s['flipped'] = <int>[i];
        } else if (flipped.length == 1) {
          final a = flipped.first;
          if (cards[a].pair == cards[i].pair) {
            // A match — both lock face-up.
            matched
              ..add(a)
              ..add(i);
            s['matched'] = matched.toList()..sort();
            s['flipped'] = const <int>[];
            if (matched.length >= cards.length) s['d'] = true;
          } else {
            // A miss — both show; the next pick clears them.
            s['flipped'] = <int>[a, i];
          }
        } else {
          s['flipped'] = <int>[i];
        }
      case GameIntent.back:
        // Un-flip whatever's mid-pick (a mis-tap).
        if (flipped.isNotEmpty) s['flipped'] = const <int>[];
      case GameIntent.reset:
        // A real reshuffle: bump a generation counter and re-order the existing
        // cards by Random(gen). Deterministic (present + control derive the
        // same layout from the same gen), so "Shuffle" / "Play again" honestly
        // deals a new board — no timer, no cross-device drift.
        final gen = ((s['gen'] as num?)?.toInt() ?? 0) + 1;
        final shuffled = [...cards]..shuffle(Random(gen));
        s['cards'] = [
          for (final c in shuffled)
            {'image': c.image, 'label': c.label, 'pair': c.pair},
        ];
        s['gen'] = gen;
        s['flipped'] = const <int>[];
        s['matched'] = const <int>[];
        s['d'] = false;
      case GameIntent.next:
      case GameIntent.reveal:
      case GameIntent.tally:
      case GameIntent.capture:
      case GameIntent.submit:
        break;
    }
    return s;
  }

  @override
  Set<GameIntent> activeIntents(MemoryState s) => {
        if (s.flipped.isNotEmpty) GameIntent.back,
        GameIntent.reset,
      };

  // The board lays out in this many columns (4 → a 4×3 board for 12 cards).
  static int columnsFor(int count) => count <= 6 ? 3 : 4;

  @override
  Widget buildStage(BuildContext context, MemoryState s) {
    if (s.cards.isEmpty) {
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
    final theme = Theme.of(context);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Column(
          children: [
            Text(
              s.done ? 'You found them all!' : 'Find the matching pairs',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${s.pairsFound} / ${s.pairsTotal} pairs',
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _MemoryBoard(state: s, accent: vibe.accent),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // The teacher's remote: a compact tappable mirror of the board + Shuffle.
  @override
  Widget? buildControls(
    BuildContext context,
    MemoryState state,
    void Function(GameIntent intent, [Map<String, dynamic> args]) send,
  ) =>
      _MemoryControls(state: state, accent: vibe.accent, send: send);
}

/// The big read-only board (the stage / cast view). Fractional rows so it can't
/// RenderFlex-overflow.
class _MemoryBoard extends StatelessWidget {
  const _MemoryBoard({required this.state, required this.accent});

  final MemoryState state;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final cols = MemoryMatchGame.columnsFor(state.cards.length);
    return Column(
      children: [
        for (var row = 0; row * cols < state.cards.length; row++)
          Expanded(
            child: Row(
              children: [
                for (var col = 0; col < cols; col++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: (row * cols + col) < state.cards.length
                          ? _MemoryCell(
                              card: state.cards[row * cols + col],
                              status: state.statusOf(row * cols + col),
                              accent: accent,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// One board position — a face-down back, a flipped face (accent ring), or a
/// matched face (dimmed + check). [compact] tightens it for the remote.
class _MemoryCell extends StatelessWidget {
  const _MemoryCell({
    required this.card,
    required this.status,
    required this.accent,
    this.onTap,
    this.compact = false,
  });

  final MemoryCard card;
  final MemoryCellStatus status;
  final Color accent;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final radius = compact ? 10.0 : 16.0;
    final Widget face;
    switch (status) {
      case MemoryCellStatus.down:
        face = DecoratedBox(
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Center(
            child: Icon(
              Icons.style_outlined,
              color: Colors.white.withValues(alpha: 0.35),
              size: compact ? 16 : 30,
            ),
          ),
        );
      case MemoryCellStatus.up:
        face = AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.all(compact ? 5 : 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: accent, width: compact ? 2 : 4),
          ),
          child: CardTile(image: card.image),
        );
      case MemoryCellStatus.matched:
        face = Opacity(
          opacity: 0.55,
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.all(compact ? 5 : 10),
                child: ColoredBox(
                  color: Colors.white,
                  child: CardTile(image: card.image),
                ),
              ),
              Positioned(
                top: compact ? 2 : 4,
                right: compact ? 2 : 4,
                child: Icon(
                  Icons.check_circle,
                  color: const Color(0xFF66BB6A),
                  size: compact ? 14 : 22,
                ),
              ),
            ],
          ),
        );
    }
    final tile = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: ColoredBox(
        color: status == MemoryCellStatus.down ? Colors.transparent : Colors.white,
        child: face,
      ),
    );
    if (onTap == null) return tile;
    // Material + InkWell for a tap ripple (matches Reveal the Picture's
    // _CellButton) — tactile confirmation the remote registered the tap.
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: tile,
      ),
    );
  }
}

/// The remote: a compact tappable mirror grid (centered, fixed cells so it
/// sits slim in the control bar) + a Shuffle / Play-again button.
class _MemoryControls extends StatelessWidget {
  const _MemoryControls({
    required this.state,
    required this.accent,
    required this.send,
  });

  final MemoryState state;
  final Color accent;
  final void Function(GameIntent intent, [Map<String, dynamic> args]) send;

  @override
  Widget build(BuildContext context) {
    final cols = MemoryMatchGame.columnsFor(state.cards.length);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (state.cards.isNotEmpty)
          LayoutBuilder(
            builder: (context, constraints) {
              // Fixed small cells so the remote stays a slim bar regardless of
              // card count.
              const gap = 6.0;
              final maxCell = (constraints.maxWidth - (cols - 1) * gap) / cols;
              final cell = maxCell.clamp(28.0, 52.0);
              return Wrap(
                alignment: WrapAlignment.center,
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (var i = 0; i < state.cards.length; i++)
                    SizedBox(
                      width: cell,
                      height: cell,
                      child: _MemoryCell(
                        card: state.cards[i],
                        status: state.statusOf(i),
                        accent: accent,
                        compact: true,
                        onTap: () => send(GameIntent.pick, {'cell': i}),
                      ),
                    ),
                ],
              );
            },
          ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: state.flipped.isEmpty
                    ? null
                    : () => send(GameIntent.back),
                icon: const Icon(Icons.undo),
                label: const Text('Flip back'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => send(GameIntent.reset),
                icon: Icon(state.done ? Icons.replay : Icons.shuffle),
                label: Text(state.done ? 'Play again' : 'Shuffle'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
