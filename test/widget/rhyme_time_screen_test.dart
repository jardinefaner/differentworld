// Widget test for Rhyme Time (more games). Host-present, NO typing, NO
// grading: a word + a tally the teacher taps as the room shouts rhymes.

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/activity_runtime/rhyme_time_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Widget harness() {
    final router = GoRouter(
      initialLocation: '/',
      routes: [GoRoute(path: '/', builder: (_, _) => const RhymeTimeScreen())],
    );
    return ProviderScope(child: MaterialApp.router(routerConfig: router));
  }

  testWidgets('opens with a word + a tally at 0 — no typing', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('RHYME WITH'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Someone rhymed it!'),
      findsOneWidget,
    );
  });

  testWidgets('tally increments, Done recaps the count', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Someone rhymed it!'));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Done'));
    await tester.pump();
    expect(find.text('The room found 1!'), findsOneWidget);
  });

  test('rhyme seed has words, all non-empty', () {
    final bank = LocalContentBank.seeded();
    final words = bank.take(ContentKind.rhymeWord, 100);
    expect(words.length, greaterThanOrEqualTo(12));
    for (final w in words) {
      expect((w.payload['word']! as String).trim(), isNotEmpty);
    }
  });
}
