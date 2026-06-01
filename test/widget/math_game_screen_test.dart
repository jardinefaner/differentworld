// Widget test for the Math game screen (docs/ACTIVITY_RUNTIME.md). The
// mechanic ORDER is deterministic (choose → type → …) even though the
// numbers are random, so the flow is testable without a seed.

import 'package:differentworld/features/activity_runtime/math_game_screen.dart';
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
      routes: [GoRoute(path: '/', builder: (_, _) => const MathGameScreen())],
    );
    return ProviderScope(child: MaterialApp.router(routerConfig: router));
  }

  testWidgets('opens on question 1 with choice buttons', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.textContaining('Question 1 / 8'), findsOneWidget);
    // The first mechanic is "choose" → 4 answer buttons.
    expect(find.byType(FilledButton), findsNWidgets(4));
  });

  testWidgets('answering shows feedback + advances to the next question', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    await tester.tap(find.byType(FilledButton).first);
    await tester.pump();

    // Feedback appeared (correct or not) + a Next button.
    expect(find.widgetWithText(FilledButton, 'Next'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16)); // post-frame focus

    expect(find.textContaining('Question 2 / 8'), findsOneWidget);
    // The second mechanic is "type" → a text field.
    expect(find.byType(TextField), findsOneWidget);
  });
}
