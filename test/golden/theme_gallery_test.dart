import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/app/theme.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/feature_card.dart';
import 'package:differentworld/shared/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '_helpers.dart';

/// A visual reference for the design-token system — NOT a screen in the
/// app. It renders the type ramp, the palette (incl. the [AppColors] gold
/// extension), the themed components, and the real composition primitives
/// under [buildLightTheme] / [buildDarkTheme], so a `RUN_GOLDENS=1` pass
/// produces a single before/after-able PNG of the whole vocabulary.
///
/// Loads the bundled fonts (Fraunces + Space Grotesk) so the ramp renders
/// for real — the default test environment has no font data and paints
/// every glyph as a box (which is why the other goldens look "masked").
void main() {
  group('theme gallery', () {
    setUpAll(() async {
      await ensureGoldenBootstrap();
      for (final family in const ['Jost']) {
        final loader = FontLoader(family)
          ..addFont(rootBundle.load('assets/fonts/$family.ttf'));
        await loader.load();
      }
    });

    testWidgets(
      'light',
      (tester) async {
        await pumpAt(
          tester,
          app: ProviderScope(
            child: MaterialApp(
              theme: buildLightTheme(),
              debugShowCheckedModeBanner: false,
              home: const _Gallery(),
            ),
          ),
          size: const Size(440, 2020),
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/theme_gallery__after.png'),
        );
      },
      skip: !runGoldens,
    );

    testWidgets(
      'dark',
      (tester) async {
        await pumpAt(
          tester,
          app: ProviderScope(
            child: MaterialApp(
              theme: buildDarkTheme(),
              debugShowCheckedModeBanner: false,
              home: const _Gallery(),
            ),
          ),
          size: const Size(440, 2020),
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/theme_gallery__after-dark.png'),
        );
      },
      skip: !runGoldens,
    );
  });
}

class _Gallery extends StatelessWidget {
  const _Gallery();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final gold = theme.extension<AppColors>()!.gold;
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DIFFERENT WORLD',
              style: theme.textTheme.displaySmall?.copyWith(
                letterSpacing: AppType.tracking,
              ),
            ),
            const SizedBox(height: Insets.xs),
            Text(
              'DESIGN TOKENS · JOST',
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Insets.xl),

            const _Label('TYPE RAMP'),
            Text('Headline small', style: theme.textTheme.headlineSmall),
            Text('Title large', style: theme.textTheme.titleLarge),
            Text('Title medium — a card row', style: theme.textTheme.titleMedium),
            Text(
              'Body large. The quick brown fox jumps over the lazy dog.',
              style: theme.textTheme.bodyLarge,
            ),
            Text(
              'Body medium. The quick brown fox jumps over the lazy dog.',
              style: theme.textTheme.bodyMedium,
            ),
            Text('LABEL SMALL', style: theme.textTheme.labelSmall),
            const SizedBox(height: Insets.xl),

            const _Label('PALETTE'),
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.sm,
              children: [
                _Swatch('primary', scheme.primary, scheme.onPrimary),
                _Swatch('secondary', scheme.secondary, scheme.onSecondary),
                _Swatch('tertiary', scheme.tertiary, scheme.onTertiary),
                _Swatch('gold', gold, scheme.surface),
                _Swatch('error', scheme.error, scheme.onError),
              ],
            ),
            const SizedBox(height: Insets.xl),

            const _Label('BUTTONS'),
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton(onPressed: () {}, child: const Text('Filled')),
                FilledButton.tonal(onPressed: () {}, child: const Text('Tonal')),
                OutlinedButton(onPressed: () {}, child: const Text('Outlined')),
                TextButton(onPressed: () {}, child: const Text('Text')),
              ],
            ),
            const SizedBox(height: Insets.lg),

            const _Label('INPUT + CHIPS'),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Child name',
                hintText: 'e.g. Maya',
              ),
            ),
            const SizedBox(height: Insets.md),
            const Wrap(
              spacing: Insets.sm,
              children: [
                Chip(label: Text('Explore')),
                Chip(label: Text('Share')),
                Chip(label: Text('Create')),
              ],
            ),
            const SizedBox(height: Insets.xl),

            const _Label('PRIMITIVES IN CONTEXT'),
            const ContentHeader(
              title: 'Today',
              subtitle: 'Sunny Room · 12 children',
            ),
            FeatureCard(
              leading: CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                child: Text('M', style: theme.textTheme.titleMedium),
              ),
              title: 'Maya Okonkwo',
              subtitle: 'Checked in · 8:42 AM',
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
            const SizedBox(height: Insets.sm),
            FeatureCard(
              tone: FeatureCardTone.danger,
              leading: const Icon(Icons.warning_amber_rounded),
              title: 'Allergy note needs review',
              subtitle: 'Updated by a guardian yesterday',
              onTap: () {},
            ),
            const SizedBox(height: Insets.md),
            SectionCard(
              icon: Icons.forum_outlined,
              title: '2 unread messages',
              tone: SectionCardTone.featured,
              child: Padding(
                padding: const EdgeInsets.only(bottom: Insets.md),
                child: Text(
                  'Devon’s mom: “Will pick up at 5 today.”',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
            SizedBox(
              height: 340,
              child: EmptyState(
                icon: Icons.photo_camera_outlined,
                title: 'No photos yet',
                message: 'Snap a moment to share with families.',
                action: FilledButton(
                  onPressed: () {},
                  child: const Text('Add a photo'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.name, this.color, this.on);
  final String name;
  final Color color;
  final Color on;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 56,
      padding: const EdgeInsets.all(Insets.sm),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      alignment: Alignment.bottomLeft,
      child: Text(
        name,
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: on),
      ),
    );
  }
}
