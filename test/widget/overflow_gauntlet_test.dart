import 'package:differentworld/app/theme.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/activity_runtime/brain_breaks_screen.dart';
import 'package:differentworld/features/auth/login_screen.dart';
import 'package:differentworld/features/captures/capture_inbox_screen.dart';
import 'package:differentworld/features/captures/captures_providers.dart';
import 'package:differentworld/features/insights/insights_providers.dart';
import 'package:differentworld/features/insights/insights_screen.dart';
import 'package:differentworld/shared/widgets/async_loading.dart'
    show LoadingSlot, LoadingVariant;
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/feature_card.dart';
import 'package:differentworld/shared/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../golden/_helpers.dart' show ensureGoldenBootstrap;

/// Overflow gauntlet — SIMULATES large-text + tight-viewport layout stress and
/// fails if any screen/primitive produces a `RenderFlex overflowed`.
///
/// Unlike the goldens (env-sensitive, opt-in), this is a DETERMINISTIC layout
/// check — it asserts on overflow geometry, not pixels — so it runs in the
/// default `flutter test` suite. Real fonts are loaded so text metrics match
/// the device (Jost is wider than the test fallback; loading it makes the
/// overflow verdicts trustworthy).
///
/// Coverage is bounded by what can be built without a live DB: the screens
/// with a known minimal provider-override set, plus the shared composition
/// primitives (which appear on every screen). Add a screen by dropping one
/// entry into the `screens` map with its overrides.
void main() {
  setUpAll(() async {
    await ensureGoldenBootstrap();
    for (final family in const ['Jost', 'Fraunces', 'SpaceGrotesk', 'Anton']) {
      final loader = FontLoader(family)
        ..addFont(rootBundle.load('assets/fonts/$family.ttf'));
      await loader.load();
    }
  });

  // Tight viewports: a small phone (narrow) + landscape (SHORT height, the
  // worst case for vertically-stacked Columns).
  const sizes = <String, Size>{
    'phone-portrait': Size(360, 800),
    'phone-landscape': Size(720, 360),
  };
  // 1.5x = the app's "Extra large" floor; 2.0x = the 200% ceiling it claims to
  // support. Overflows almost always surface in this band.
  const scales = <double>[1.5, 2];

  // ── Screens (built with their minimal provider overrides) ──────────────
  final screens = <String, Widget Function(double scale)>{
    'login': (s) => ProviderScope(child: _scaledApp(s, const LoginScreen())),
    'captures': (s) => ProviderScope(
          overrides: [
            capturesProvider(CaptureFilter.open).overrideWith(
              (_) => Stream<List<Capture>>.value(const <Capture>[]),
            ),
            capturesProvider(CaptureFilter.all).overrideWith(
              (_) => Stream<List<Capture>>.value(const <Capture>[]),
            ),
          ],
          child: _scaledApp(s, const CaptureInboxScreen()),
        ),
    // NOTE: data-gated screens (tasks, today, attendance, …) can't be
    // rendered to their data/empty state in isolation — their providers need
    // a viewer + space + DB this harness doesn't mock, so they stall on the
    // (scroll-safe) loading skeleton. Their real states ARE covered below as
    // primitives (EmptyState / ErrorState / LoadingSlot). Add such a screen
    // here only once there's a viewer/DB mock to resolve it.
    'insights': (s) => ProviderScope(
          overrides: [
            insightsProvider.overrideWith(
              (_) => const AsyncValue<List<Insight>>.data(<Insight>[]),
            ),
          ],
          child: _scaledApp(s, const InsightsScreen()),
        ),
    // Provider-free (static deck); the card grid's fixed-height cells are
    // exactly the "fixed-height container around text" a11y trap, so the
    // deck earns a permanent gauntlet slot.
    'breaks': (s) =>
        ProviderScope(child: _scaledApp(s, const BrainBreaksScreen())),
  };

  for (final scale in scales) {
    for (final sz in sizes.entries) {
      group('${sz.key} @ ${scale}x', () {
        for (final sc in screens.entries) {
          testWidgets(sc.key, (tester) async {
            final overflows =
                await _collectOverflows(tester, () => sc.value(scale), sz.value);
            expect(
              overflows,
              isEmpty,
              reason: '${sc.key} @ ${sz.key} @ ${scale}x overflowed:\n'
                  '${overflows.join('\n')}',
            );
          });
        }
      });
    }
  }

  // ── Composition primitives with adversarial (long, unbroken) content ────
  // These are reused on every feature surface, so an overflow here is systemic.
  group('primitives @ 2.0x', () {
    const long =
        'Maximiliana Featherstone-Worthington the Extraordinarily Long Named';
    const longer =
        'A subtitle that simply will not stop describing things in great and '
        'unrelenting detail across many words';

    Widget host(Widget child) => _scaledApp(
          2,
          Scaffold(
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [child],
              ),
            ),
          ),
        );

    testWidgets('FeatureCard (long title + subtitle + trailing)',
        (tester) async {
      final o = await _collectOverflows(
        tester,
        // FeatureCard is now a ConsumerWidget (reads displayStyleProvider),
        // so it needs a ProviderScope ancestor.
        () => host(
          const ProviderScope(
            child: FeatureCard(
              leading: CircleAvatar(child: Text('M')),
              title: long,
              subtitle: longer,
              trailing: Icon(Icons.chevron_right),
            ),
          ),
        ),
        const Size(320, 800),
      );
      expect(o, isEmpty, reason: o.join('\n'));
    });

    testWidgets('SectionCard (long title + trailing)', (tester) async {
      final o = await _collectOverflows(
        tester,
        () => host(
          const SectionCard(
            icon: Icons.forum_outlined,
            title: long,
            trailing: Text('+12 more'),
            child: Padding(padding: EdgeInsets.only(bottom: 12), child: Text(longer)),
          ),
        ),
        const Size(320, 800),
      );
      expect(o, isEmpty, reason: o.join('\n'));
    });

    testWidgets('ContentHeader (long uppercased title + subtitle + trailing)',
        (tester) async {
      final o = await _collectOverflows(
        tester,
        () => host(
          const ContentHeader(
            title: long,
            subtitle: longer,
            trailing: Icon(Icons.sync),
          ),
        ),
        const Size(320, 800),
      );
      expect(o, isEmpty, reason: o.join('\n'));
    });

    testWidgets('EmptyState (long title + message + action)', (tester) async {
      final o = await _collectOverflows(
        tester,
        () => host(
          SizedBox(
            height: 700,
            child: EmptyState(
              icon: Icons.inbox_outlined,
              title: long,
              message: longer,
              action: FilledButton(onPressed: () {}, child: const Text('Do the thing')),
            ),
          ),
        ),
        const Size(320, 800),
      );
      expect(o, isEmpty, reason: o.join('\n'));
    });

    testWidgets('ErrorState (long title + detail)', (tester) async {
      final o = await _collectOverflows(
        tester,
        () => host(
          SizedBox(
            height: 700,
            child: ErrorState(title: long, detail: longer, onRetry: () {}),
          ),
        ),
        const Size(320, 800),
      );
      expect(o, isEmpty, reason: o.join('\n'));
    });

    testWidgets('LoadingSlot (list + cards + spinner)', (tester) async {
      for (final v in LoadingVariant.values) {
        final o = await _collectOverflows(
          tester,
          () => _scaledApp(2, Scaffold(body: LoadingSlot(variant: v))),
          const Size(320, 700),
        );
        expect(o, isEmpty, reason: 'LoadingSlot.$v: ${o.join('\n')}');
      }
    });
  });
}

/// Wraps [home] in the app theme and FORCES text scaling to [scale] on every
/// route (injected above the Navigator via the MaterialApp builder).
MaterialApp _scaledApp(double scale, Widget home) => MaterialApp(
      theme: buildLightTheme(),
      debugShowCheckedModeBanner: false,
      home: home,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
        ),
        child: child!,
      ),
    );

/// Pumps [build] at [size], COLLECTING every RenderFlex overflow (instead of
/// aborting on the first) by temporarily intercepting `FlutterError.onError`.
/// Returns the overflow headlines — empty means the layout is clean.
Future<List<String>> _collectOverflows(
  WidgetTester tester,
  Widget Function() build,
  Size size,
) async {
  final found = <String>[];
  final prior = FlutterError.onError;
  FlutterError.onError = (details) {
    final msg = details.exceptionAsString();
    if (msg.contains('overflowed')) {
      // Capture the headline + the offending widget's creation site (the
      // ".dart:line" the framework records via debugCreator) so the failure
      // reason points straight at the file to fix.
      final loc = details
          .toString()
          .split('\n')
          .firstWhere((l) => l.contains('.dart:'), orElse: () => '')
          .trim();
      found.add('${msg.split('\n').first.trim()}  ←  $loc');
    } else {
      prior?.call(details); // surface real (non-overflow) errors as failures
    }
  };
  await tester.binding.setSurfaceSize(size);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  try {
    await tester.pumpWidget(build());
    await tester.pump(const Duration(milliseconds: 350));
  } finally {
    FlutterError.onError = prior;
  }
  return found;
}
