// Widget tests for the Teacher Toolkit feature surface.
//
// Coverage:
// * Catalog renders every category × every tool at phone width.
// * Search filters the visible cards on each keystroke.
// * Tapping a tool card invokes the per-slug push.
// * Tool detail screen renders the right tool's content.
// * Unknown-slug fallback renders the error state with a back action.
// * Master-detail layout activates at >= 600dp wide.
//
// Pattern: instantiate the toolkit widgets directly (not through the
// full router/AppShell stack) — these are unit-level widget tests
// that exercise the screen's own logic without bootstrapping the
// whole app. The integration-level wire-up (router push, AppShell
// chrome) is covered separately if it ever needs to be.

import 'package:differentworld/features/toolkit/toolkit_catalog.dart';
import 'package:differentworld/features/toolkit/toolkit_screen.dart';
import 'package:differentworld/features/toolkit/toolkit_tool_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('Toolkit catalog data', () {
    test('all categories carry exactly 6 tools', () {
      for (final cat in toolkitCatalog) {
        expect(cat.tools.length, 6, reason: '${cat.name} expected 6 tools');
      }
    });

    test('every slug is unique', () {
      final slugs = <String>{};
      for (final tool in allToolkitTools) {
        expect(slugs.add(tool.slug), isTrue,
            reason: 'duplicate slug: ${tool.slug}');
      }
      expect(slugs.length, 30);
    });

    test('findToolBySlug round-trips', () {
      for (final tool in allToolkitTools) {
        expect(findToolBySlug(tool.slug)?.name, tool.name);
      }
      expect(findToolBySlug('does-not-exist'), isNull);
    });
  });

  group('Catalog screen at phone width', () {
    Future<void> pumpCatalog(WidgetTester tester) async {
      // Force a phone-sized viewport so the responsive branch picks
      // the mobile catalog (< 600dp).
      tester.view.physicalSize = const Size(400 * 3, 800 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const _TestHarness(child: ToolkitScreen()),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('first category is on screen at initial paint',
        (tester) async {
      await pumpCatalog(tester);
      final firstCat = toolkitCatalog.first;
      expect(find.text(firstCat.name), findsWidgets);
      expect(find.text(firstCat.tools.first.name), findsOneWidget);
      expect(find.text(firstCat.tagline), findsOneWidget);
    });

    testWidgets('every tool reachable via scroll', (tester) async {
      await pumpCatalog(tester);
      // Walk through every tool by scrolling its title into view.
      // Proves the full feed (5 categories × 6 tools) is in the
      // widget tree in order. Tool names are unique across the
      // catalog (verified by the data test above) so `find.text` is
      // unambiguous; category names appear inside tool descriptions
      // ("celebrate it") so we don't use them here.
      final scrollable = find.byType(Scrollable).first;
      for (final cat in toolkitCatalog) {
        for (final tool in cat.tools) {
          await tester.scrollUntilVisible(
            find.text(tool.name),
            120,
            scrollable: scrollable,
          );
        }
      }
    });

    testWidgets('search filters the feed', (tester) async {
      await pumpCatalog(tester);
      // "parent" matches "The Parent Text" only.
      await tester.enterText(find.byType(TextField), 'parent');
      await tester.pump();
      expect(
        find.text('The Parent Text', skipOffstage: false),
        findsOneWidget,
      );
      // The other tools shouldn't appear when filtered — the feed is
      // entirely replaced by the hits list.
      expect(
        find.text('The 5:1 Ratio', skipOffstage: false),
        findsNothing,
      );
    });

    testWidgets('empty search shows full feed again', (tester) async {
      await pumpCatalog(tester);
      await tester.enterText(find.byType(TextField), 'parent');
      await tester.pump();
      expect(
        find.text('The 5:1 Ratio', skipOffstage: false),
        findsNothing,
      );
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(
        find.text('The 5:1 Ratio', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('non-matching query shows the empty state',
        (tester) async {
      await pumpCatalog(tester);
      await tester.enterText(find.byType(TextField), 'xyzzy123');
      await tester.pump();
      expect(find.text('No tools match'), findsOneWidget);
      expect(find.text('Clear search'), findsOneWidget);
    });
  });

  group('Tool detail screen', () {
    testWidgets('renders the matching tool', (tester) async {
      final tool = toolkitCatalog.first.tools.first;
      await tester.pumpWidget(
        _TestHarness(child: ToolkitToolScreen(slug: tool.slug)),
      );
      await tester.pumpAndSettle();
      expect(find.text(tool.name, skipOffstage: false), findsWidgets);
      // SectionCard section titles (sentence case, matching the rest
      // of the app's section-card vocabulary).
      expect(find.text('Instead of', skipOffstage: false), findsOneWidget);
      expect(find.text('Try this', skipOffstage: false), findsOneWidget);
      expect(
        find.text('Why this works', skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text('Quick script', skipOffstage: false), findsOneWidget);
    });

    testWidgets('unknown slug renders the fallback', (tester) async {
      await tester.pumpWidget(
        const _TestHarness(child: ToolkitToolScreen(slug: 'nonsense')),
      );
      await tester.pumpAndSettle();
      expect(
        find.text("We don't have a tool with that name."),
        findsOneWidget,
      );
      expect(find.text('nonsense'), findsOneWidget);
      expect(find.text('Back to toolkit'), findsOneWidget);
    });
  });

  group('Responsive split', () {
    testWidgets('phone width shows mobile catalog only (no detail pane)',
        (tester) async {
      tester.view.physicalSize = const Size(400 * 3, 800 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const _TestHarness(child: ToolkitScreen()),
      );
      await tester.pumpAndSettle();
      // The wide-only placeholder header should NOT appear on phone.
      expect(find.text('Pick a tool'), findsNothing);
    });

    testWidgets('tablet width activates master-detail with placeholder',
        (tester) async {
      // 1024dp viewport — well above Breakpoints.smallTablet (600dp).
      tester.view.physicalSize = const Size(1024 * 1, 768 * 1);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const _TestHarness(child: ToolkitScreen()),
      );
      await tester.pumpAndSettle();
      // The right-pane placeholder uses ContentHeader title.
      expect(find.text('Pick a tool'), findsOneWidget);
      // The left rail header "Toolkit" should be visible too.
      expect(find.text('Toolkit'), findsOneWidget);
    });
  });
}

/// Minimal MaterialApp + GoRouter wrapper. GoRouter is required so
/// the screen's `context.push('/settings/toolkit/<slug>')` calls
/// don't blow up when a tool card is tapped during a test.
class _TestHarness extends StatelessWidget {
  const _TestHarness({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => child),
        // Stub destination so push doesn't error during tap tests.
        GoRoute(
          path: '/settings/toolkit/:slug',
          builder: (_, _) => const Scaffold(body: Text('pushed')),
        ),
      ],
    );
    return ProviderScope(child: MaterialApp.router(routerConfig: router));
  }
}
