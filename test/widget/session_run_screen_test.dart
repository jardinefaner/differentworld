// Widget test for the SESSION RUN PRESENTER — the beat-by-beat curriculum
// session runner. Verifies: it renders the first beat + sequence; Next advances;
// every one of the 17 Session-1 beats renders without throwing (covers the
// game / vocab / cooldown / closing kinds + their tinted cards); tap-to-expand
// reveals the full script; the timeline jumps; and an unknown slug shows the
// calm EmptyState instead of erroring.

import 'package:differentworld/features/curricula/photo_s1_script.dart';
import 'package:differentworld/features/curricula/session_run_screen.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  // A minimal shell-free router: the screen under test at '/', plus stub
  // destinations its taps push to (so a stray tap can't blow up the test).
  Widget harness({required String slug}) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => SessionRunScreen(slug: slug),
        ),
        GoRoute(
          path: '/activity/photo-turns',
          builder: (_, _) => const Scaffold(body: Text('turns')),
        ),
        GoRoute(
          path: '/settings/curricula/photo',
          builder: (_, _) => const Scaffold(body: Text('curriculum')),
        ),
      ],
    );
    return ProviderScope(child: MaterialApp.router(routerConfig: router));
  }

  testWidgets('renders the first beat + the sequence timeline', (tester) async {
    await tester.pumpWidget(harness(slug: photoSession1Script.slug));
    await tester.pump();

    // Session title (ContentHeader) + the first beat's title both visible.
    expect(find.text(photoSession1Script.title), findsWidgets);
    expect(find.text('Before they arrive'), findsWidgets);
    // The sequence header names the beat count.
    expect(find.textContaining('The sequence'), findsOneWidget);
    // The advance bar names the next beat.
    expect(find.textContaining('Next ·'), findsOneWidget);
  });

  testWidgets('Next advances to the following beat', (tester) async {
    await tester.pumpWidget(harness(slug: photoSession1Script.slug));
    await tester.pump();

    // Beat 1 is "Before they arrive"; beat 2 is "The Hook". The advance bar can
    // sit below the fold on a tall slide, so bring it into view before tapping.
    final nextButton = find.textContaining('Next ·');
    expect(nextButton, findsOneWidget);
    await tester.ensureVisible(nextButton);
    await tester.pumpAndSettle();
    await tester.tap(nextButton);
    await tester.pumpAndSettle();

    // The hook's key line should now be on screen (it's in the slide).
    expect(
      find.textContaining('I need to test your eyes'),
      findsWidgets,
    );
  });

  testWidgets('every Session-1 beat renders without throwing', (tester) async {
    await tester.pumpWidget(harness(slug: photoSession1Script.slug));
    await tester.pump();

    // Walk the whole run via the Next button; each tap rebuilds the slide for a
    // new beat kind (game / cooldown / partner / vocab / closing / doorway /
    // after). If any slide threw on build, pumpAndSettle would surface it.
    for (var i = 0; i < photoSession1Script.beats.length - 1; i++) {
      final next = find.textContaining('Next ·');
      expect(next, findsOneWidget, reason: 'Next missing at beat $i');
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();
    }
    // On the last beat the button reads the terminal label, disabled.
    expect(find.text("That's the last beat"), findsOneWidget);
    expect(find.textContaining('Next ·'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tap-to-expand reveals the full script', (tester) async {
    await tester.pumpWidget(harness(slug: photoSession1Script.slug));
    await tester.pump();

    // Collapsed: the expand affordance reads "Read the full script".
    final toggle = find.text('Read the full script');
    expect(toggle, findsOneWidget);
    // A "note" line from beat 1's full script is NOT shown in the calm view.
    expect(
      find.textContaining('Curiosity is your opening energy'),
      findsNothing,
    );

    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    // Expanded: the toggle flips + a full-script-only line appears.
    expect(find.text('Hide the full script'), findsOneWidget);
    expect(
      find.textContaining('Curiosity is your opening energy'),
      findsOneWidget,
    );
  });

  testWidgets('tapping a timeline row jumps to that beat', (tester) async {
    await tester.pumpWidget(harness(slug: photoSession1Script.slug));
    await tester.pump();

    // The vocabulary beat ("The Vocabulary Wall") sits near the end; its row is
    // in the timeline below the fold. Bring it into view, then tap to jump.
    final vocabRow = find.text('The Vocabulary Wall');
    expect(vocabRow, findsWidgets);
    await tester.ensureVisible(vocabRow.first);
    await tester.pumpAndSettle();
    await tester.tap(vocabRow.first);
    await tester.pumpAndSettle();

    // The vocab beat renders its word cards (Composition / Close-up / Subject).
    expect(find.text('Words for the wall'), findsOneWidget);
    expect(find.text('Composition'), findsWidgets);
  });

  testWidgets('an unknown slug shows the EmptyState, not an error', (
    tester,
  ) async {
    await tester.pumpWidget(harness(slug: 'photo.s9.does-not-exist'));
    await tester.pump();

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text("This session isn't scripted yet."), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
