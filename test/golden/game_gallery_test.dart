import 'dart:convert';
import 'dart:io';

import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/app/theme.dart';
import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/facilitation/run_script_view.dart';
import 'package:differentworld/features/games/cards/card_tile.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_controller.dart';
import 'package:differentworld/features/games/game_registry.dart';
import 'package:differentworld/features/games/game_scaffold.dart';
import 'package:differentworld/features/games/game_stage.dart';
import 'package:differentworld/features/games/games/charades_game.dart';
import 'package:differentworld/features/games/games/grid_reveal_game.dart';
import 'package:differentworld/features/games/games/memory_match_game.dart';
import 'package:differentworld/features/games/games/name_it_game.dart';
import 'package:differentworld/features/games/games/odd_one_out_game.dart';
import 'package:differentworld/features/games/games/whats_missing_game.dart';
import 'package:differentworld/features/games/grid_game.dart';
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
  final manifest =
      json.decode(
            await rootBundle.loadString('FontManifest.json'),
          )
          as List<dynamic>;
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
  _scene(
    'games/atom_hero',
    width: 480,
    height: 150,
    (c) => _gamePlate(GameStage.hero(c, 'A group of flamingos')),
  );
  _scene(
    'games/atom_eyebrow',
    width: 420,
    height: 110,
    (c) => _gamePlate(GameStage.eyebrow(c, 'True, or fib?')),
  );
  _scene(
    'games/atom_option',
    width: 480,
    height: 240,
    (c) => _gamePlate(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              GameStage.option(c, 'True', accent: GameAccents.teal),
              GameStage.option(
                c,
                'Fib',
                accent: GameAccents.teal,
                selected: true,
              ),
              GameStage.option(
                c,
                'Maybe',
                accent: GameAccents.teal,
                dimmed: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 300,
            child: GameStage.option(
              c,
              'Outside',
              accent: GameAccents.teal,
              trailing: '7',
            ),
          ),
        ],
      ),
    ),
  );
  _scene(
    'games/atom_counter',
    width: 320,
    height: 170,
    (c) => _gamePlate(
      GameStage.counter(
        c,
        value: '3',
        caption: 'found',
        accent: GameAccents.teal,
      ),
    ),
  );
  _scene(
    'games/atom_card_tile',
    width: 280,
    height: 300,
    (c) => _gamePlate(
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
    ),
  );
  _scene(
    'games/atom_vibe',
    width: 620,
    height: 150,
    (c) => _gamePlate(
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
              decoration: BoxDecoration(
                color: col,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
        ],
      ),
    ),
  );

  // THE GAME MOLECULES — one plate per molecule (the stage shapes the atoms
  // compose into: a vote, a poll, a card board, a tally bar).
  _scene(
    'games/molecule_vote',
    width: 480,
    height: 320,
    (c) => _gamePlate(
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
              GameStage.option(
                c,
                'True',
                accent: GameAccents.teal,
                selected: true,
              ),
              const SizedBox(width: 12),
              GameStage.option(c, 'Fib', accent: GameAccents.teal),
            ],
          ),
        ],
      ),
    ),
  );
  _scene(
    'games/molecule_poll',
    width: 440,
    height: 260,
    (c) => _gamePlate(
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
                child: GameStage.option(
                  c,
                  l,
                  accent: GameAccents.deepTeal,
                  selected: s,
                  trailing: n,
                ),
              ),
            ),
        ],
      ),
    ),
  );
  _scene(
    'games/molecule_card_board',
    width: 360,
    height: 200,
    (c) => _gamePlate(
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
                decoration: BoxDecoration(
                  color: col,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white70, size: 26),
              ),
            ),
        ],
      ),
    ),
  );
  _scene(
    'games/molecule_tally',
    width: 420,
    height: 200,
    (c) => _gamePlate(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GameStage.option(
            c,
            'Someone said it',
            accent: GameAccents.teal,
            selected: true,
          ),
          const SizedBox(height: 9),
          // A Wrap, not a Row: this is the plate's own scaffolding, and at
          // 200% text two pills are wider than a small phone. The app's real
          // tally bar (tally_controls.dart) sizes itself in text units.
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              GameStage.option(c, 'New word', accent: GameAccents.teal),
              GameStage.option(
                c,
                'Reset',
                accent: GameAccents.teal,
                dimmed: true,
              ),
            ],
          ),
        ],
      ),
    ),
  );

  // The vibe palette — every game's signature colour DNA (accent on its own
  // dark surface). The most "atomic" view of the games: their identity at a
  // glance, sourced live from the `liveGames` registry.
  _scene(
    'games/vibe_palette',
    width: 760,
    height: 640,
    (_) => const _VibePalette(),
  );

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

  // THE CLASSICS — every GridGame, dealt over a bank that carries pictures
  // (the picture-fed ones read the deck; the bank has none by itself). They
  // are `seedsFromContentBank == false`, so the two loops above skip them —
  // which is how nineteen boards shipped with no plate at all, and why the
  // renderer's dead-tap defect was never SEEN: the gallery had nothing to
  // look at.
  // Real deck art, listed from disk so the plates show the bundled cards
  // rather than broken-image glyphs.
  final deckFiles =
      Directory('assets/card_games/everyday')
          .listSync()
          .whereType<File>()
          .map((f) => f.path.split('/').last)
          .where((n) => n.endsWith('.png'))
          .toList()
        ..sort();
  final classicsBank = LocalContentBank.seededWith([
    ...curatedSeeds,
    for (final (i, name) in deckFiles.indexed)
      ContentItem(
        kind: ContentKind.picture,
        fingerprint: 'plate-pic$i',
        payload: {
          'image': 'assets/card_games/everyday/$name',
          'label': name
              .replaceAll(RegExp(r'^\d+-|\.png$'), '')
              .replaceAll('-', ' '),
        },
      ),
  ]);
  for (final game in liveGames.whereType<GridGame>()) {
    _scene('games/stage_${game.id}', width: 440, height: 560, (ctx) {
      // A few moves in, so the plate shows a board being PLAYED, not dealt:
      // a disc dropped, a square uncovered, a pad lit.
      var wire = game.initialState(classicsBank);
      for (final cell in const [0, 1, 7, 8]) {
        wire = game.reduce(wire, GameIntent.pick, {'cell': cell});
      }
      return ColoredBox(
        color: game.vibe.surface,
        child: game.buildStage(ctx, game.decode(wire)),
      );
    });
    _organismScene(
      'games/organism_${game.id}',
      game,
      game.initialState(classicsBank),
    );
  }

  // The card games are deck-seeded (seedsFromContentBank=false) — hand them a
  // sample board of real deck art so the stage shows its true layout.
  const deck = 'assets/card_games/everyday';
  // The run-script — what the ROOM is told before the board appears. Plated
  // because it is the first thing a room sees for any scripted game, and
  // because the organism plates deliberately show the BOARD (they build
  // initialState directly, without the runner's cursor seeding).
  _scene('games/run_script', width: 440, height: 560, (ctx) {
    const g = CharadesGame();
    return RunScriptView(
      script: g.howToPlay,
      index: 1,
      title: g.title,
      surface: g.vibe.surface,
      onLine: AppColors.onAccent(g.vibe.surface),
      onNext: () {},
      onBack: () {},
    );
  });

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

/// Plates that CANNOT be stable, with the reason — same discipline as
/// screens_gallery_test's map: they still render (the overflow sweep still
/// sees them), only the pixel comparison is skipped. Every entry is a game
/// whose deal calls `Random()` with no seed, and seeding it would change what
/// a room actually gets. Measured, not guessed: the first version of this
/// list was the eight plates that failed twice — and the letter games passed
/// twice only because their labels rendered invisible.
const Map<String, String> _unstableByDesign = <String, String>{
  'games/stage_bingo': 'shuffles the card and draws a random first call',
  'games/organism_bingo': 'shuffles the card and draws a random first call',
  'games/stage_guess-who': 'a random secret; the faces draw from the deck',
  'games/organism_guess-who': 'a random secret; the faces draw from the deck',
  'games/stage_lights-out': 'scrambled by playing random taps backwards',
  'games/organism_lights-out': 'scrambled by playing random taps backwards',
  'games/stage_whack-a-mole': 'the mole starts on a random square',
  'games/organism_whack-a-mole': 'the mole starts on a random square',
  'games/stage_battleship': 'random ships, uncovered by the plate’s picks',
  'games/stage_minesweeper': 'random mines; the plate uncovers four squares',
  'games/organism_minesweeper': 'random mines',
  'games/stage_scavenger': 'shuffles its list every deal',
  'games/organism_scavenger': 'shuffles its list every deal',
  'games/stage_boggle': 'sixteen dice, rolled',
  'games/organism_boggle': 'sixteen dice, rolled',
  'games/stage_word-search': 'random word placement and filler letters',
  'games/organism_word-search': 'random word placement and filler letters',
  'games/stage_scattergories': 'a random letter, shuffled categories',
  'games/organism_scattergories': 'a random letter, shuffled categories',
  'games/stage_crossword': 'one of three puzzles, at random',
  'games/organism_crossword': 'one of three puzzles, at random',
  'games/stage_hangman': 'a random word — the masked line changes length',
  'games/organism_hangman': 'a random word — the masked line changes length',
  'games/stage_four-corners': 'a random question on the pads',
  'games/organism_four-corners': 'a random question on the pads',
  'games/stage_spot-difference': 'a random square is the different one',
  'games/stage_snakes-ladders': 'the plate’s picks are dice rolls',
};

bool _comparable(String name) => !_unstableByDesign.containsKey(name);

/// Render one game scene once (games own their surface — no light/dark pair).
/// A fixed canvas — see `plateSize`. A `stage_` / `atom_` / `molecule_` plate
/// is a reference card for one piece of a game. The `organism_` plates are
/// different and deliberately NOT fixed: `_organismScene` renders the complete
/// surface a teacher and a room actually see, so it stands for a device and
/// must survive every viewport the sweep rotates it to.
void _scene(
  String name,
  Widget Function(BuildContext) build, {
  required double width,
  required double height,
}) {
  testWidgets(
    name,
    (tester) async {
      await tester.binding.setSurfaceSize(
        plateSize(Size(width, height), fixedCanvas: true),
      );
      tester.view.physicalSize = plateSize(
        Size(width, height),
        fixedCanvas: true,
      );
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
      // Pixels differ by design in a stress pass (rescaled or resized);
      // the overflow assertion already happened during pump.
      // An unstable plate is still WRITTEN on --update-goldens, so its PNG
      // follows the code; it is only never compared.
      if (!isStressRun && (_comparable(name) || autoUpdateGoldenFiles)) {
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('../../gallery/$name.png'),
        );
      }
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
      // NOT a fixed canvas, deliberately: this is the whole assembled game
      // surface, so it stands for a device and the viewport sweep must reach
      // it. `games/organism_as-if` overflowing by 32px at 320dp is a real
      // defect, and this is the plate that has to keep finding it.
      await tester.binding.setSurfaceSize(plateSize(Size(width, height)));
      tester.view.physicalSize = plateSize(Size(width, height));
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
      // Pixels differ by design in a stress pass (rescaled or resized);
      // the overflow assertion already happened during pump.
      // An unstable plate is still WRITTEN on --update-goldens, so its PNG
      // follows the code; it is only never compared.
      if (!isStressRun && (_comparable(name) || autoUpdateGoldenFiles)) {
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('../../gallery/$name.png'),
        );
      }
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
              _VibeChip(
                title: g.title,
                accent: g.vibe.accent,
                surface: g.vibe.surface,
              ),
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
    final tile = surface == const Color(0xFF000000)
        ? const Color(0xFF15151B)
        : surface;
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
