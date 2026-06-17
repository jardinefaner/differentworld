import 'dart:convert';

import 'package:differentworld/app/theme.dart';
import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/cards/card_tile.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_controller.dart';
import 'package:differentworld/features/games/game_registry.dart';
import 'package:differentworld/features/games/game_scaffold.dart';
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

  // THE GAME ATOMS — one plate per atom, so each can be seen + tweaked on its
  // own (the shared vocabulary every game's stage composes from). teal stands
  // in for "the game's accent"; the vibe atom shows the full accent set.
  _scene('games/atom_hero', width: 480, height: 150,
      (c) => _gamePlate(GameStage.hero(c, 'A group of flamingos')));
  _scene('games/atom_eyebrow', width: 420, height: 110,
      (c) => _gamePlate(GameStage.eyebrow(c, 'True, or fib?')));
  _scene('games/atom_option', width: 480, height: 240, (c) => _gamePlate(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                GameStage.option(c, 'True', accent: GameAccents.teal),
                GameStage.option(c, 'Fib', accent: GameAccents.teal, selected: true),
                GameStage.option(c, 'Maybe', accent: GameAccents.teal, dimmed: true),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 300,
              child: GameStage.option(c, 'Outside', accent: GameAccents.teal, trailing: '7'),
            ),
          ],
        ),
      ));
  _scene('games/atom_counter', width: 320, height: 170,
      (c) => _gamePlate(GameStage.counter(c, value: '3', caption: 'found', accent: GameAccents.teal)));
  _scene('games/atom_card_tile', width: 280, height: 300, (c) => _gamePlate(
        SizedBox(
          width: 150,
          height: 190,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: CardTile(image: 'assets/card_games/everyday/04-banana.png'),
            ),
          ),
        ),
      ));
  _scene('games/atom_vibe', width: 620, height: 150, (c) => _gamePlate(
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            for (final col in const [
              GameAccents.teal,
              GameAccents.deepTeal,
              GameAccents.amber,
              GameAccents.coral,
              GameAccents.plum,
              GameAccents.slate,
              GameAccents.rose,
              GameAccents.sage,
            ])
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(12)),
              ),
          ],
        ),
      ));

  // THE GAME MOLECULES — one plate per molecule (the stage shapes the atoms
  // compose into: a vote, a poll, a card board, a tally bar).
  _scene('games/molecule_vote', width: 480, height: 320, (c) => _gamePlate(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GameStage.eyebrow(c, 'True, or fib?'),
            const SizedBox(height: 12),
            GameStage.hero(c, 'A flock of crows is a “murder”', maxLines: 2),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GameStage.option(c, 'True', accent: GameAccents.teal, selected: true),
                const SizedBox(width: 12),
                GameStage.option(c, 'Fib', accent: GameAccents.teal),
              ],
            ),
          ],
        ),
      ));
  _scene('games/molecule_poll', width: 440, height: 260, (c) => _gamePlate(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (l, n, s) in const [
              ('Outside', '7', true),
              ('Gym', '4', false),
              ('Reading', '2', false),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: SizedBox(
                  width: 300,
                  child: GameStage.option(c, l, accent: GameAccents.deepTeal, selected: s, trailing: n),
                ),
              ),
          ],
        ),
      ));
  _scene('games/molecule_card_board', width: 360, height: 200, (c) => _gamePlate(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (col, icon) in const [
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
                  decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: Colors.white70, size: 26),
                ),
              ),
          ],
        ),
      ));
  _scene('games/molecule_tally', width: 420, height: 200, (c) => _gamePlate(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GameStage.option(c, 'Someone said it', accent: GameAccents.teal, selected: true),
            const SizedBox(height: 9),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GameStage.option(c, 'New word', accent: GameAccents.teal),
                const SizedBox(width: 10),
                GameStage.option(c, 'Reset', accent: GameAccents.teal, dimmed: true),
              ],
            ),
          ],
        ),
      ));

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

  // THE GAME ORGANISMS — the FULL assembled surface (stage + control bar +
  // chrome) via GameScaffold: the complete game a teacher/kid actually sees,
  // one tier above the bare stage. Phone-sized, so it shows the big remote.
  for (final game in liveGames.where(
    (g) => g.seedsFromContentBank && g.id != 'grid-reveal',
  )) {
    _organismScene(
      'games/organism_${game.id}',
      game,
      game.initialState(LocalContentBank.seeded()),
    );
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

/// Render one full game ORGANISM — GameScaffold (stage + control bar + chrome)
/// driven by a seeded LocalGameController. Phone-sized so it shows the big
/// remote panel: the complete game surface, one tier above the bare stage.
void _organismScene(
  String name,
  GameDefinition<dynamic> def,
  Map<String, dynamic> wire, {
  double width = 400,
  double height = 840,
}) {
  testWidgets(
    name,
    (tester) async {
      await tester.binding.setSurfaceSize(Size(width, height));
      tester.view.physicalSize = Size(width, height);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = LocalGameController(initial: wire, reduce: def.reduce);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildDarkTheme(),
            debugShowCheckedModeBanner: false,
            home: GameScaffold<dynamic>(def: def, controller: controller),
          ),
        ),
      );
      await tester.runAsync(() async {
        for (final element in find.byType(Image).evaluate()) {
          await precacheImage((element.widget as Image).image, element);
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

/// Centres one atom or molecule on the dark game surface — one plate each.
Widget _gamePlate(Widget child) => ColoredBox(
      color: kGameSurface,
      child: Center(
        child: Padding(padding: const EdgeInsets.all(28), child: child),
      ),
    );

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
