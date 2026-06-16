import 'dart:convert';

import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/app/theme.dart';
import 'package:differentworld/shared/widgets/cap_switch.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/destructive_button.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_banner.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/feature_card.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:differentworld/shared/widgets/primary_action_button.dart';
import 'package:differentworld/shared/widgets/secondary_action_button.dart';
import 'package:differentworld/shared/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '_helpers.dart';

/// THE COMPONENT BIBLE renderer (see gallery/README.md). Every catalogued
/// component is rendered — its variants, light + dark — to
/// `gallery/<tier>/<name>__<theme>.png`, so the whole vocabulary is browsable
/// and tweakable in ONE folder.
///
/// Regenerate (local, on-demand — goldens are environment-sensitive + OFF by
/// default; this is for VIEWING, not cross-machine CI):
/// ```sh
/// RUN_GOLDENS=1 flutter test --update-goldens test/golden/component_gallery_test.dart
/// open gallery/        # eyeball the PNGs
/// ```
///
/// Add a component: register a [_plate] below + add its row to
/// gallery/README.md. The `component-curator` agent reconciles the two and
/// flags anything in lib/shared/widgets/ that isn't catalogued yet.
///
/// Animated / blur components (StatusDot glow, Skeleton shimmer, GlassPill
/// BackdropFilter) are deferred — they need a fixed-pump variant so
/// `pumpAndSettle` can't hang on a forever-animation. Tracked in the README.
/// Load EVERY bundled font from FontManifest.json — the app faces (Jost,
/// Fraunces, Space Grotesk, Anton) AND `MaterialIcons`, so glyphs and icons
/// both render for real instead of as tofu boxes (the default test env ships
/// no font data).
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

void _noop(bool _) {}

void main() {
  setUpAll(() async {
    await ensureGoldenBootstrap();
    // Real type, not the box-glyph fallback — these PNGs are a design
    // reference, so the fonts have to render.
    await _loadFonts();
  });

  // ── ATOMS ──────────────────────────────────────────────────────────────
  _plate(
    'atoms/action_buttons',
    height: 220,
    (_) => Wrap(
      spacing: Insets.md,
      runSpacing: Insets.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        PrimaryActionButton(tooltip: 'Add', icon: Icons.add, onPressed: () {}),
        SecondaryActionButton(
          tooltip: 'Settings',
          icon: Icons.tune,
          onPressed: () {},
        ),
        FilledButton(onPressed: () {}, child: const Text('Filled')),
        FilledButton.tonal(onPressed: () {}, child: const Text('Tonal')),
        OutlinedButton(onPressed: () {}, child: const Text('Outlined')),
        TextButton(onPressed: () {}, child: const Text('Text')),
        DestructiveButton(label: 'Delete', onPressed: () {}),
      ],
    ),
  );

  _plate(
    'atoms/person_avatar',
    height: 180,
    (_) => const Wrap(
      spacing: Insets.lg,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        PersonAvatar(name: 'Maya Okonkwo'),
        PersonAvatar(name: 'Devon Lee', radius: 26),
        PersonAvatar(name: 'Sam', radius: 34),
      ],
    ),
  );

  // ── MOLECULES ────────────────────────────────────────────────────────────
  _plate(
    'molecules/feature_card',
    height: 460,
    (_) => Column(
      children: [
        FeatureCard(
          leading: const Icon(Icons.person_outline),
          title: 'Maya Okonkwo',
          subtitle: 'Checked in · 8:42 AM',
          trailing: const Icon(Icons.chevron_right),
          onTap: () {},
        ),
        const SizedBox(height: Insets.sm),
        FeatureCard(
          tone: FeatureCardTone.selected,
          leading: const Icon(Icons.play_arrow),
          title: 'Free play',
          subtitle: 'Blocks corner · right now',
          onTap: () {},
        ),
        const SizedBox(height: Insets.sm),
        FeatureCard(
          tone: FeatureCardTone.danger,
          leading: const Icon(Icons.warning_amber_rounded),
          title: 'Allergy note needs review',
          subtitle: 'Updated by a guardian',
          onTap: () {},
        ),
        const SizedBox(height: Insets.sm),
        FeatureCard(
          tone: FeatureCardTone.success,
          leading: const Icon(Icons.check_circle_outline),
          title: 'All checked out',
          subtitle: 'Every child signed out',
          onTap: () {},
        ),
      ],
    ),
  );

  _plate(
    'molecules/section_card',
    height: 240,
    (ctx) => SectionCard(
      icon: Icons.forum_outlined,
      title: '2 unread messages',
      tone: SectionCardTone.featured,
      child: Padding(
        padding: const EdgeInsets.only(bottom: Insets.md),
        child: Text(
          'Devon’s mom: “Will pick up at 5 today.”',
          style: Theme.of(ctx).textTheme.bodyMedium,
        ),
      ),
    ),
  );

  _plate(
    'molecules/content_header',
    height: 150,
    (_) => const ContentHeader(title: 'Today', subtitle: 'Sunny Room · 12 children'),
  );

  _plate(
    'molecules/empty_state',
    height: 380,
    (_) => EmptyState(
      icon: Icons.photo_camera_outlined,
      title: 'No photos yet',
      message: 'Snap a moment to share with families.',
      action: FilledButton(onPressed: () {}, child: const Text('Add a photo')),
    ),
  );

  _plate(
    'molecules/error_state',
    height: 380,
    (_) => ErrorState(
      title: 'Couldn’t load',
      detail: 'Check your connection and try again.',
      onRetry: () {},
    ),
  );

  _plate(
    'molecules/error_banner',
    height: 150,
    (_) => ErrorBanner(
      message: 'Couldn’t sync — we’ll retry automatically.',
      onRetry: () {},
      onDismiss: () {},
    ),
  );

  _plate(
    'molecules/cap_switch',
    height: 180,
    (_) => const Column(
      children: [
        CapSwitch(label: 'Attendance', value: true, onChanged: _noop),
        CapSwitch(
          label: 'Field trips',
          subtitle: 'Off for this room',
          value: false,
          enabled: false,
          onChanged: _noop,
        ),
      ],
    ),
  );
}

/// Render one component's plate (its variants) under light + dark, each written
/// to `gallery/<name>__<theme>.png`. [height] sizes the capture surface so the
/// plate isn't swimming in empty canvas. Skipped unless `RUN_GOLDENS=1`.
void _plate(
  String name,
  Widget Function(BuildContext) build, {
  double height = 360,
}) {
  for (final mode in const ['light', 'dark']) {
    testWidgets(
      '$name · $mode',
      (tester) async {
        await pumpAt(
          tester,
          app: ProviderScope(
            child: MaterialApp(
              theme: mode == 'dark' ? buildDarkTheme() : buildLightTheme(),
              debugShowCheckedModeBanner: false,
              home: Scaffold(
                body: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(Insets.lg),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Builder(builder: build),
                    ),
                  ),
                ),
              ),
            ),
          ),
          size: Size(440, height),
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('../../gallery/${name}__$mode.png'),
        );
      },
      skip: !runGoldens,
    );
  }
}
