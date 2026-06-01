// Widget test for the conducted Math runner (docs/ACTIVITY_RUNTIME.md
// Slice 2). Exercises the phase walk + live validation through the real
// screen. Stops before the `ponder` phase on purpose — it arms a 20s timer
// that would hang pumpAndSettle.

import 'package:differentworld/features/activity_runtime/math_runner_screen.dart';
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

  Widget harness({int target = 12}) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => MathRunnerScreen(target: target),
        ),
      ],
    );
    return ProviderScope(child: MaterialApp.router(routerConfig: router));
  }

  testWidgets('opens on the present phase showing the target', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump(); // let the kid-mode microtask settle

    expect(find.text('12'), findsOneWidget);
    expect(find.text("Let's go"), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('advances to the create phase with a focused input', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    await tester.tap(find.text("Let's go"));
    await tester.pump(); // build create phase
    await tester.pump(const Duration(milliseconds: 16)); // post-frame focus

    expect(find.byType(TextField), findsOneWidget);
    expect(find.textContaining('Invent a question'), findsOneWidget);
  });

  testWidgets('a correct, novel expression enables "Add this path"', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pump();
    await tester.tap(find.text("Let's go"));
    await tester.pump();

    await tester.enterText(find.byType(TextField), '3 × 4');
    await tester.pump();

    expect(find.text('Yes! that makes 12'), findsOneWidget);
    final add = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Add this path'),
    );
    expect(add.onPressed, isNotNull);
  });

  testWidgets('a wrong-value expression is rejected with feedback', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pump();
    await tester.tap(find.text("Let's go"));
    await tester.pump();

    await tester.enterText(find.byType(TextField), '5 + 5');
    await tester.pump();

    expect(find.text('That makes 10, not 12'), findsOneWidget);
    final add = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Add this path'),
    );
    expect(add.onPressed, isNull, reason: 'cannot bank a wrong answer');
  });

  testWidgets('banking a path chips it and the reveal shows it', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pump();
    await tester.tap(find.text("Let's go"));
    await tester.pump();

    await tester.enterText(find.byType(TextField), '6 + 6');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Add this path'));
    await tester.pump();

    expect(find.widgetWithText(Chip, '6 + 6'), findsOneWidget);

    // Move to the reveal — it shows the learner's path back to them.
    await tester.tap(find.text("I'm done — show the paths"));
    await tester.pump();

    expect(find.text('Yours'), findsOneWidget);
    expect(find.widgetWithText(Chip, '6 + 6'), findsWidgets);
  });
}
