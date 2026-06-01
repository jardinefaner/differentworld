// Widget test for the "As If" acting game (docs/ACTIVITY_RUNTIME.md).
// Deterministic: the first challenge is the seed order's first line ×
// first as-if.

import 'package:differentworld/features/activity_runtime/as_if_screen.dart';
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
      routes: [GoRoute(path: '/', builder: (_, _) => const AsIfScreen())],
    );
    return ProviderScope(child: MaterialApp.router(routerConfig: router));
  }

  testWidgets('opens on the first challenge (line × as-if)', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.text('“I lost my keys”'), findsOneWidget);
    expect(find.text("you're terrified"), findsOneWidget);
    expect(find.text('Finish (0)'), findsOneWidget);
  });

  testWidgets('"I did it!" counts it and advances to a new challenge', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'I did it!'));
    await tester.pump();

    expect(find.text('Finish (1)'), findsOneWidget);
    expect(find.text('“Look at that!”'), findsOneWidget); // next line
    expect(find.text('you just won a prize'), findsOneWidget); // next as-if
  });

  testWidgets('Finish shows the recap of what was performed', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'I did it!'));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Finish (1)'));
    await tester.pump();

    expect(find.text('You acted out 1! 🎭'), findsOneWidget);
    expect(find.text('“I lost my keys”'), findsOneWidget); // in the recap
    expect(find.text('Play again'), findsOneWidget);
  });
}
