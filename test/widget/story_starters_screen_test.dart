// Widget test for Story Starters (more games). Host-present imagination:
// NO typing, NO grading — the room builds a story aloud, the teacher drops
// twists and moves to new starts.

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/activity_runtime/story_starters_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Widget harness() {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const StoryStartersScreen()),
      ],
    );
    return ProviderScope(child: MaterialApp.router(routerConfig: router));
  }

  testWidgets('opens on the first starter — no typing, has twist + new start', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('Story 1 / 8'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Add a twist'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'New start'), findsOneWidget);
  });

  testWidgets('Add a twist reveals a plot twist; New start advances', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.text('✨ PLOT TWIST'), findsNothing);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Add a twist'));
    await tester.pump();
    expect(find.text('✨ PLOT TWIST'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'New start'));
    await tester.pump();
    expect(find.text('Story 2 / 8'), findsOneWidget);
    expect(find.text('✨ PLOT TWIST'), findsNothing); // cleared on new start
  });

  test('story seed: starters and twists are present and non-empty', () {
    final bank = LocalContentBank.seeded();
    final starters = bank.take(ContentKind.storyStarter, 100);
    final twists = bank.take(ContentKind.storyTwist, 100);
    expect(starters.length, greaterThanOrEqualTo(8));
    expect(twists.length, greaterThanOrEqualTo(6));
    for (final s in [...starters, ...twists]) {
      expect((s.payload['text']! as String).trim(), isNotEmpty);
    }
  });
}
