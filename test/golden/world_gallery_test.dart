import 'dart:convert';

import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/app/theme.dart';
import 'package:differentworld/features/action_words/verbs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '_helpers.dart';

/// THE WORLDS tier of the component bible — the curriculum's visual atoms
/// (the Action Words / Different World content layer, docs/ACTION_WORDS.md +
/// docs/PRIMITIVES.md). Unlike the games (a `GameDefinition` + `buildStage`),
/// most world surfaces are immersive screens coupled to real world content, so
/// they catalogue gradually. This file STARTS the tier with the foundational
/// atom — the twelve **Verbs** ("everything else is combinations of verbs") —
/// and the gold world-accent.
///
/// Caveat: the verbs carry an emoji, which goldens can't rasterise (no colour-
/// emoji font in the test bundle) — so the glyph shows as a placeholder box;
/// the LABEL + LENS (the substance) render for real.
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

  // The Verb primitive — the canonical twelve, each with its LENS (the "how"
  // that personalizes every activity). The atom the whole curriculum is built
  // from.
  _scene('worlds/verbs', width: 760, height: 540, (_) => const _VerbsBoard());

  // The gold world-accent (AppColors.gold) — the signature colour of the
  // Different World / Action Words surfaces, tuned per brightness.
  _scene(
    'worlds/gold_accent',
    width: 440,
    height: 260,
    (_) => const _GoldAccent(),
  );

  // The world ATOMS — one plate per atom (the action-words vocabulary).
  _scene('worlds/atom_verb', width: 480, height: 150, (c) {
    final gold = AppColors.dark.gold;
    final theme = Theme.of(c);
    return _worldPlate(
      Wrap(
        spacing: 22,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: [
          for (final w in const ['explore', 'share', 'create'])
            Text(
              w,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: gold,
                fontWeight: FontWeight.w400,
              ),
            ),
        ],
      ),
    );
  });
  _scene('worlds/atom_gold', width: 320, height: 170, (c) {
    final gold = AppColors.dark.gold;
    return _worldPlate(
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: gold,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '#${gold.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
    );
  });
  _scene('worlds/atom_intention', width: 360, height: 180, (c) {
    final gold = AppColors.dark.gold;
    final theme = Theme.of(c);
    return _worldPlate(
      Container(
        width: 230,
        decoration: BoxDecoration(
          color: gold.withValues(alpha: 0.08),
          border: Border(left: BorderSide(color: gold, width: 3)),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'explore',
              style: theme.textTheme.titleLarge?.copyWith(
                color: gold,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 3),
            const Text(
              'try something new today',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  });

  // The world MOLECULES — one plate per molecule.
  _scene('worlds/molecule_cue_card', width: 360, height: 240, (c) {
    final theme = Theme.of(c);
    const cueColor = Color(0xFF5784A8);
    final cueFg = AppColors.onAccent(cueColor);
    return _worldPlate(
      Container(
        width: 240,
        decoration: BoxDecoration(
          color: cueColor,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.visibility_outlined, color: cueFg, size: 40),
            const SizedBox(height: 10),
            Text(
              'Eyes up',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: cueFg,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  });
  _scene('worlds/molecule_intention_picker', width: 320, height: 260, (c) {
    final gold = AppColors.dark.gold;
    final theme = Theme.of(c);
    return _worldPlate(
      SizedBox(
        width: 240,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (w, on) in const [
              ('explore', true),
              ('share', true),
              ('create', false),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: on
                        ? gold.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.04),
                    border: Border(
                      left: BorderSide(
                        color: on ? gold : Colors.white24,
                        width: 3,
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  child: Text(
                    w,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: on ? gold : Colors.white38,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  });
}

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

class _VerbsBoard extends StatelessWidget {
  const _VerbsBoard();

  @override
  Widget build(BuildContext context) {
    final gold = AppColors.dark.gold;
    final theme = Theme.of(context);
    return ColoredBox(
      color: const Color(0xFF0B0B0F),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final v in kVerbs)
              Container(
                width: 168,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF15151B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: gold.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(v.emoji, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 8),
                        Text(
                          v.label,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: gold,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      v.lens,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GoldAccent extends StatelessWidget {
  const _GoldAccent();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF0B0B0F),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'World accent · gold',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _Swatch('on dark', AppColors.dark.gold),
                const SizedBox(width: 12),
                _Swatch('on light', AppColors.light.gold),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 150,
          height: 70,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$label · #${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }
}

/// Centres one atom or molecule on the dark world surface — one plate each.
Widget _worldPlate(Widget child) => ColoredBox(
  color: const Color(0xFF10100F),
  child: Center(
    child: Padding(padding: const EdgeInsets.all(28), child: child),
  ),
);
