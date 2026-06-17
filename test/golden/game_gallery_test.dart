import 'dart:convert';

import 'package:differentworld/app/theme.dart';
import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_registry.dart';
import 'package:differentworld/features/games/game_stage.dart';
import 'package:differentworld/features/games/games/grid_reveal_game.dart';
import 'package:differentworld/features/games/games/memory_match_game.dart';
import 'package:differentworld/features/games/games/name_it_game.dart';
import 'package:differentworld/features/games/games/odd_one_out_game.dart';
import 'package:differentworld/features/games/games/whats_missing_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '_helpers.dart';

/// THE GAMES tier of the component bible — the EXPERIENCE layer's visual atoms
/// (docs/VERTICALS.md). Unlike the shared widgets (the engine's domain-agnostic
/// layer), these are the game surfaces: each game's signature vibe (accent +
/// dark surface) and its hero STAGE, rendered by seeding a `GameDefinition`'s
/// wire-state and calling `buildStage` — the same way a screen would.
///
/// Renders to `gallery/games/<name>.png` (games define their own dark surface,
/// so there's no light/dark pair — one render each). Regenerate:
///   RUN_GOLDENS=1 flutter test --update-goldens test/golden/game_gallery_test.dart
Future<void> _loadFonts() async {
  final manifest = json.decode(
    await rootBundle.loadString('FontManifest.json'),
  ) as List<dynamic>;
  for (final entry in manifest) {
    final family = (entry as Map<String, dynamic>)['family'] as String;
    final loader = FontLoader(family);
    for (final font in entry['fonts'] as List<dynamic>) {
      loader.addFont(rootBundle.load((font as Map)['asset'] as String));
    }
    await loader.load();
  }
}

void main() {
  setUpAll(() async {
    await ensureGoldenBootstrap();
    await _loadFonts();
  });

  // THE GAME ATOMS — the shared vocabulary every game's stage composes from
  // (GameStage.hero / eyebrow / option / counter). Rendered once, labelled, so
  // the deck's interactive parts read as ONE system, not 21 hand-rolled stages.
  _scene('games/atoms', width: 600, height: 860, (_) => const _GameAtoms());

  // THE GAME MOLECULES — the atoms composed into the four stage shapes every
  // game is one of: a vote stage, a poll, a card board, a tally bar.
  _scene('games/molecules', width: 600, height: 760, (_) => const _GameMolecules());

  // The vibe palette — every game's signature colour DNA (accent on its own
  // dark surface). The most "atomic" view of the games: their identity at a
  // glance, sourced live from the `liveGames` registry.
  _scene('games/vibe_palette', width: 760, height: 640, (_) => const _VibePalette());

  // One hero STAGE — Reveal the Picture, mid-reveal. Proves a game's stage
  // renders standalone from a seeded wire-state.
  _scene('games/grid_reveal_stage', width: 440, height: 520, (ctx) {
    const game = GridRevealGame();
    final wire = <String, dynamic>{
      'cols': 4,
      'rows': 4,
      'pic': '🦁',
      'lbl': 'Lion',
      'rev': const [
        true, false, true, false, //
        false, true, false, true, //
        true, false, false, true, //
        false, true, true, false, //
      ],
      'd': false,
      'n': 16,
    };
    return ColoredBox(
      color: game.vibe.surface,
      child: game.buildStage(ctx, game.decode(wire)),
    );
  });

  // Every bank-seeded game's hero stage — rendered from its OWN initialState
  // over the curated content bank, so the content is real, not faked.
  for (final game in liveGames.where(
    (g) => g.seedsFromContentBank && g.id != 'grid-reveal',
  )) {
    _scene('games/stage_${game.id}', width: 440, height: 560, (ctx) {
      final wire = game.initialState(LocalContentBank.seeded());
      return ColoredBox(
        color: game.vibe.surface,
        child: game.buildStage(ctx, game.decode(wire)),
      );
    });
  }

  // The card games are deck-seeded (seedsFromContentBank=false) — hand them a
  // sample board of real deck art so the stage shows its true layout.
  const deck = 'assets/card_games/everyday';
  _scene('games/stage_name-it', width: 440, height: 560, (ctx) {
    const game = NameItGame();
    final wire = <String, dynamic>{
      'cards': [
        {'image': '$deck/04-banana.png', 'label': 'banana'},
        {'image': '$deck/01-violin.png', 'label': 'violin'},
      ],
      'i': 0,
      'r': true,
      'd': false,
    };
    return ColoredBox(
      color: game.vibe.surface,
      child: game.buildStage(ctx, game.decode(wire)),
    );
  });
  _scene('games/stage_odd-one-out', width: 440, height: 560, (ctx) {
    const game = OddOneOutGame();
    final wire = <String, dynamic>{
      'rounds': [
        {
          'cards': [
            {'image': '$deck/04-banana.png', 'label': 'banana'},
            {'image': '$deck/08-teacup.png', 'label': 'teacup'},
            {'image': '$deck/05-candle.png', 'label': 'candle'},
            {'image': '$deck/06-basketball.png', 'label': 'basketball'},
          ],
          'answer': 3,
        },
      ],
      'i': 0,
      'r': false,
      'd': false,
    };
    return ColoredBox(
      color: game.vibe.surface,
      child: game.buildStage(ctx, game.decode(wire)),
    );
  });
  _scene('games/stage_whats-missing', width: 440, height: 560, (ctx) {
    const game = WhatsMissingGame();
    final wire = <String, dynamic>{
      'rounds': [
        {
          'cards': [
            {'image': '$deck/04-banana.png', 'label': 'banana'},
            {'image': '$deck/01-violin.png', 'label': 'violin'},
            {'image': '$deck/06-basketball.png', 'label': 'basketball'},
            {'image': '$deck/03-backpack.png', 'label': 'backpack'},
            {'image': '$deck/05-candle.png', 'label': 'candle'},
            {'image': '$deck/07-feather.png', 'label': 'feather'},
          ],
          'missing': 2,
        },
      ],
      'i': 0,
      'phase': 1,
      'd': false,
    };
    return ColoredBox(
      color: game.vibe.surface,
      child: game.buildStage(ctx, game.decode(wire)),
    );
  });
  _scene('games/stage_memory-match', width: 440, height: 560, (ctx) {
    const game = MemoryMatchGame();
    final wire = <String, dynamic>{
      'cards': [
        {'image': '$deck/04-banana.png', 'label': 'banana', 'pair': 'banana'},
        {'image': '$deck/01-violin.png', 'label': 'violin', 'pair': 'violin'},
        {'image': '$deck/04-banana.png', 'label': 'banana', 'pair': 'banana'},
        {'image': '$deck/06-basketball.png', 'label': 'ball', 'pair': 'ball'},
        {'image': '$deck/01-violin.png', 'label': 'violin', 'pair': 'violin'},
        {'image': '$deck/06-basketball.png', 'label': 'ball', 'pair': 'ball'},
      ],
      'flipped': [1],
      'matched': [0, 2],
      'd': false,
    };
    return ColoredBox(
      color: game.vibe.surface,
      child: game.buildStage(ctx, game.decode(wire)),
    );
  });
}

/// Render one game scene once (games own their surface — no light/dark pair).
void _scene(
  String name,
  Widget Function(BuildContext) build, {
  required double width,
  required double height,
}) {
  testWidgets(
    name,
    (tester) async {
      await tester.binding.setSurfaceSize(Size(width, height));
      tester.view.physicalSize = Size(width, height);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildDarkTheme(),
            debugShowCheckedModeBanner: false,
            home: Scaffold(body: Builder(builder: build)),
          ),
        ),
      );
      // Deck-art `Image.asset`s decode asynchronously — without this the
      // snapshot fires before they paint and the card stages render as empty
      // white mats. Precache every Image so the card games show real art.
      await tester.runAsync(() async {
        for (final element in find.byType(Image).evaluate()) {
          final image = element.widget as Image;
          await precacheImage(image.image, element);
        }
      });
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../../gallery/$name.png'),
      );
    },
    skip: !runGoldens,
  );
}

/// The game-atom set, labelled — the shared parts every stage is built from.
class _GameAtoms extends StatelessWidget {
  const _GameAtoms();

  @override
  Widget build(BuildContext context) {
    const accent = GameAccents.teal;
    return ColoredBox(
      color: kGameSurface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _AtomLabel('hero — the serif prompt'),
            GameStage.hero(context, 'A group of flamingos'),
            const _AtomGap(),
            const _AtomLabel('eyebrow — the instruction'),
            GameStage.eyebrow(context, 'True, or fib?'),
            const _AtomGap(),
            const _AtomLabel('option — default · selected · dimmed'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                GameStage.option(context, 'True', accent: accent),
                GameStage.option(context, 'Fib', accent: accent, selected: true),
                GameStage.option(context, 'Maybe', accent: accent, dimmed: true),
              ],
            ),
            const _AtomGap(),
            const _AtomLabel('option — with count (a poll row)'),
            SizedBox(
              width: 320,
              child: GameStage.option(context, 'Outside', accent: accent, trailing: '7'),
            ),
            const _AtomGap(),
            const _AtomLabel('counter — the score atom'),
            GameStage.counter(context, value: '3', caption: 'found', accent: accent),
          ],
        ),
      ),
    );
  }
}

/// A muted tracked-caps caption above each atom in the atoms scene.
class _AtomLabel extends StatelessWidget {
  const _AtomLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            color: Colors.white30,
            fontSize: 11,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

class _AtomGap extends StatelessWidget {
  const _AtomGap();
  @override
  Widget build(BuildContext context) => const SizedBox(height: 32);
}

/// The game-molecule set — atoms composed into the four stage shapes.
class _GameMolecules extends StatelessWidget {
  const _GameMolecules();

  @override
  Widget build(BuildContext context) {
    const accent = GameAccents.teal;
    return ColoredBox(
      color: kGameSurface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _AtomLabel('vote stage — eyebrow + hero + 2 options'),
            Center(
              child: Column(
                children: [
                  GameStage.eyebrow(context, 'True, or fib?'),
                  const SizedBox(height: 12),
                  GameStage.hero(
                    context,
                    'A flock of crows is a “murder”',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GameStage.option(context, 'True', accent: accent, selected: true),
                      const SizedBox(width: 12),
                      GameStage.option(context, 'Fib', accent: accent),
                    ],
                  ),
                ],
              ),
            ),
            const _AtomGap(),
            const _AtomLabel('poll — hero + option rows with counts'),
            for (final (label, n, sel) in const [
              ('Outside', '7', true),
              ('Gym', '4', false),
              ('Reading', '2', false),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: GameStage.option(
                  context,
                  label,
                  accent: accent,
                  selected: sel,
                  trailing: n,
                ),
              ),
            const _AtomGap(),
            const _AtomLabel('card board — a grid of card tiles'),
            Row(
              children: [
                for (final (c, icon) in const [
                  (Color(0xFF22413C), Icons.music_note),
                  (Color(0xFF3A3320), Icons.bolt),
                  (Color(0xFF3A2630), Icons.sports_basketball),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Container(
                      width: 70,
                      height: 90,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: Colors.white70, size: 26),
                    ),
                  ),
              ],
            ),
            const _AtomGap(),
            const _AtomLabel('tally bar — the control row'),
            GameStage.option(context, 'Someone said it', accent: accent, selected: true),
            const SizedBox(height: 9),
            Row(
              children: [
                GameStage.option(context, 'New word', accent: accent),
                const SizedBox(width: 10),
                GameStage.option(context, 'Reset', accent: accent, dimmed: true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A grid of every registered game's vibe — surface tile + accent bar + title.
class _VibePalette extends StatelessWidget {
  const _VibePalette();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF0B0B0F),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final g in liveGames)
              _VibeChip(title: g.title, accent: g.vibe.accent, surface: g.vibe.surface),
          ],
        ),
      ),
    );
  }
}

class _VibeChip extends StatelessWidget {
  const _VibeChip({
    required this.title,
    required this.accent,
    required this.surface,
  });

  final String title;
  final Color accent;
  final Color surface;

  @override
  Widget build(BuildContext context) {
    // If the game's surface is pure black (the default), show a near-black tile
    // so the chip reads as a card rather than blending into the canvas.
    final tile = surface == const Color(0xFF000000) ? const Color(0xFF15151B) : surface;
    return Container(
      width: 168,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tile,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '#${accent.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
