import 'dart:convert';

import 'package:differentworld/app/theme.dart';
import 'package:differentworld/features/games/game_registry.dart';
import 'package:differentworld/features/games/games/grid_reveal_game.dart';
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
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../../gallery/$name.png'),
      );
    },
    skip: !runGoldens,
  );
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
