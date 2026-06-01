// Widget test for "Beat the Letter" (docs/ACTIVITY_ROADMAP.md Wave 2).
// Teacher-paced, NO typing, NO grading: a big letter + category the room
// reads, and a tally the teacher taps. The letter is random per round, so
// these assert the FLOW, not a fixed letter.

import 'package:differentworld/features/activity_runtime/letter_words_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  Widget harness() {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const LetterWordsScreen()),
      ],
    );
    return ProviderScope(child: MaterialApp.router(routerConfig: router));
  }

  testWidgets('opens with a letter + category + a tally at 0 — no input', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.byType(TextField), findsNothing); // no typing
    expect(find.textContaining('that starts with'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Someone said it'), findsOneWidget);
    expect(find.text('0'), findsOneWidget); // the tally
  });

  testWidgets('tapping the tally increments the count (no right/wrong)', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Someone said it'));
    await tester.pump();

    expect(find.text('1'), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('Done recaps the room tally', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Someone said it'));
    await tester.pump();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Done'));
    await tester.pump();

    expect(find.text('The room found 1!'), findsOneWidget);
  });
}
