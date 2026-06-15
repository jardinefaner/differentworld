// Widget tests for the /now cockpit (slice 1).
//
// Coverage:
// * Live beat renders the ContextLead it delegates to (title + primary).
// * "Start the reveal" is GATED on a running world — absent when none (the
//   Council's dead-end fix: /play-today is a dead end with no world).
// * After-pickup `send` beat (lead == null) renders its authored card.
// * The curiosity bar toggles open and reveals the Layer-2 destinations.
//
// Providers are overridden so the screen renders deterministically without
// the live clock / schedule / Drift stack.

import 'package:differentworld/features/action_words/world_schedule.dart';
import 'package:differentworld/features/cockpit/cockpit_beat.dart';
import 'package:differentworld/features/cockpit/now_cockpit_screen.dart';
import 'package:differentworld/features/today/context_lead.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _lead = ContextLead(
  eyebrow: 'RIGHT NOW',
  title: 'ABC Time',
  line: 'In World of Water — full-screen, step by step.',
  icon: Icons.play_circle_outline,
  tone: ContextTone.go,
  primary: ContextMove(
    icon: Icons.slideshow_outlined,
    label: 'Run the session',
    route: '/play-today',
  ),
);

Future<void> _pump(
  WidgetTester tester, {
  required CockpitBeat beat,
  ContextLead? lead,
}) async {
  tester.view.physicalSize = const Size(400 * 3, 800 * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final router = GoRouter(
    initialLocation: '/now',
    routes: [
      GoRoute(path: '/now', builder: (_, _) => const NowCockpitScreen()),
      // Stub destinations so a stray tap doesn't error mid-test.
      for (final p in <String>[
        '/',
        '/schedule',
        '/tools',
        '/program',
        '/insights',
        '/play-today',
        '/messages',
      ])
        GoRoute(
          path: p,
          builder: (_, _) => const Scaffold(body: Text('pushed')),
        ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        cockpitBeatProvider.overrideWith((ref) => beat),
        contextLeadProvider.overrideWith((ref) => lead),
        // No curriculum world running → the reveal launch must stay hidden.
        currentWorldProvider.overrideWith((ref) => null),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('NowCockpitScreen', () {
    testWidgets('a live beat renders the lead it delegates to', (tester) async {
      await _pump(tester, beat: CockpitBeat.now, lead: _lead);
      expect(find.text('ABC Time'), findsOneWidget);
      expect(find.text('Run the session'), findsOneWidget);
    });

    testWidgets('"Start the reveal" is hidden when no world is running',
        (tester) async {
      await _pump(tester, beat: CockpitBeat.now, lead: _lead);
      // The reveal launch would drop the teacher into a dead-end /play-today
      // when there's no curriculum world — so it must not appear.
      expect(find.text('Start the reveal'), findsNothing);
    });

    testWidgets('the after-pickup send beat renders its authored card',
        (tester) async {
      await _pump(tester, beat: CockpitBeat.send);
      expect(find.text('Send today home'), findsOneWidget);
      expect(find.text('Open messages'), findsOneWidget);
    });

    testWidgets('the closed beat renders the rest state, no send button',
        (tester) async {
      await _pump(tester, beat: CockpitBeat.closed);
      expect(find.text('All done for today'), findsOneWidget);
      expect(find.text('Open messages'), findsNothing);
    });

    testWidgets('the curiosity bar toggles open to reveal Layer-2 places',
        (tester) async {
      await _pump(tester, beat: CockpitBeat.now, lead: _lead);
      // Collapsed: the destinations aren't in the tree yet.
      expect(find.text('Schedule'), findsNothing);
      await tester.tap(find.text('More places'));
      await tester.pumpAndSettle();
      expect(find.text('Schedule'), findsOneWidget);
      expect(find.text('Patterns'), findsOneWidget);
    });
  });
}
