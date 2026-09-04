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

import 'package:differentworld/features/action_words/world_blocks.dart';
import 'package:differentworld/features/action_words/world_schedule.dart';
import 'package:differentworld/features/cockpit/cockpit_beat.dart';
import 'package:differentworld/features/cockpit/now_cockpit_screen.dart';
import 'package:differentworld/features/schedule/live_block_provider.dart';
import 'package:differentworld/features/today/context_lead.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _lead = ContextLead(
  eyebrow: 'Right now',
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

/// A live block in `groupId`, for driving the "what's next" cohort resolution.
LiveBlock _live(String groupId) => LiveBlock(
  blockId: 'b-live',
  groupId: groupId,
  title: 'ABC Time',
  kind: 'on_site',
  isOutdoor: false,
  startAt: DateTime(2026, 1, 1, 9),
  endAt: DateTime(2026, 1, 1, 10),
);

Future<void> _pump(
  WidgetTester tester, {
  required CockpitBeat beat,
  ContextLead? lead,
  LiveBlock? liveBlock,
  NextBlock? nextBlock,
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
        '/action-words',
        '/action-words/send',
        '/arc',
        '/activity/photo',
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
        // No curriculum world running → the reveal launch must stay hidden,
        // and the morning card falls back to "A new day".
        currentWorldProvider.overrideWith((ref) => null),
        seasonPositionProvider.overrideWith((ref) => null),
        // The live cohort + its next block drive the "what's next" line.
        liveBlockProvider.overrideWith((ref) => liveBlock),
        if (liveBlock != null)
          nextScheduledBlockProvider(
            liveBlock.groupId,
          ).overrideWith((ref) => nextBlock),
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

    testWidgets('"Start the reveal" is hidden when no world is running', (
      tester,
    ) async {
      await _pump(tester, beat: CockpitBeat.now, lead: _lead);
      // The reveal launch would drop the teacher into a dead-end /play-today
      // when there's no curriculum world — so it must not appear.
      expect(find.text('Start the reveal'), findsNothing);
    });

    testWidgets('the live beat shows a "what\'s next" line + launches it', (
      tester,
    ) async {
      final nextBlock = NextBlock(
        blockId: 'b-next',
        groupId: 'g1',
        title: 'Story Circle',
        startAt: DateTime(2026, 1, 1, 10, 30),
        runnerSlug: null,
        runTopic: 'Story Circle',
      );
      await _pump(
        tester,
        beat: CockpitBeat.now,
        lead: _lead,
        liveBlock: _live('g1'),
        nextBlock: nextBlock,
      );
      // The advance cue: "Next · 10:30  Story Circle" (RichText spans, so the
      // finder must descend into rich text).
      expect(
        find.textContaining('Next · 10:30', findRichText: true),
        findsOneWidget,
      );

      // Tapping it launches the run (no runner slug → the generic /arc arc).
      await tester.tap(find.textContaining('Next · 10:30', findRichText: true));
      await tester.pumpAndSettle();
      expect(find.text('pushed'), findsOneWidget);
    });

    testWidgets('the "what\'s next" line is absent off the program beat', (
      tester,
    ) async {
      // Pickup has its own forward chain — the next-block cue is `now`-only.
      final nextBlock = NextBlock(
        blockId: 'b-next',
        groupId: 'g1',
        title: 'Story Circle',
        startAt: DateTime(2026, 1, 1, 10, 30),
        runnerSlug: null,
        runTopic: 'Story Circle',
      );
      await _pump(
        tester,
        beat: CockpitBeat.pickup,
        lead: _lead,
        liveBlock: _live('g1'),
        nextBlock: nextBlock,
      );
      expect(
        find.textContaining('Next · 10:30', findRichText: true),
        findsNothing,
      );
    });

    testWidgets('the after-pickup send beat renders its authored card', (
      tester,
    ) async {
      await _pump(tester, beat: CockpitBeat.send);
      expect(find.text('Send today home'), findsOneWidget);
      expect(find.text('Send home'), findsOneWidget);
    });

    testWidgets('the closed beat renders the rest state, no send button', (
      tester,
    ) async {
      await _pump(tester, beat: CockpitBeat.closed);
      expect(find.text('All done for today'), findsOneWidget);
      expect(find.text('Send home'), findsNothing);
    });

    testWidgets('the morning beat leads with the verb pick', (tester) async {
      await _pump(tester, beat: CockpitBeat.goodMorning, lead: _lead);
      expect(find.text('Good morning'), findsOneWidget);
      expect(find.text("Pick today's verbs"), findsOneWidget);
      // The arrival lead's move rides alongside as a secondary chip.
      expect(find.text('Run the session'), findsOneWidget);
    });

    testWidgets('the reveal beat offers the closing launch + an escape', (
      tester,
    ) async {
      await _pump(tester, beat: CockpitBeat.reveal);
      expect(find.text('Reveal the day'), findsOneWidget);
      expect(find.text('Start the reveal'), findsOneWidget);
      // Never cage: a way back to the live program is always present.
      expect(find.text('Not yet — stay in program'), findsOneWidget);
    });

    testWidgets('the curiosity bar toggles open to reveal Layer-2 places', (
      tester,
    ) async {
      await _pump(tester, beat: CockpitBeat.now, lead: _lead);
      // Collapsed: the curiosity destinations aren't built yet. Assert on
      // 'Patterns' — it is UNIQUE to the curiosity bar. ('Schedule' also renders
      // in the always-present tools section below the beat, so it's ambiguous.)
      expect(find.text('Patterns'), findsNothing);
      await tester.tap(find.text('More places'));
      await tester.pumpAndSettle();
      expect(find.text('Patterns'), findsOneWidget);
    });
  });
}
