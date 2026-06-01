// Widget test for the "starts with a letter" word game
// (docs/ACTIVITY_RUNTIME.md). Deterministic: the first category is the
// seed order's first ("an animal"), the first letter is 'C'.

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

  testWidgets('opens with the letter C and the first category', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.text('C'), findsOneWidget); // the letter chip
    expect(find.text('Name an animal that starts with C'), findsOneWidget);
  });

  testWidgets('validates the starting letter live', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Dog');
    await tester.pump();
    expect(find.text('Oops — it needs to start with C'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    await tester.enterText(find.byType(TextField), 'Cat');
    await tester.pump();
    expect(find.text('Nice! tap Add it'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('adding banks the word as a chip and rejects a repeat', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Cat');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Add it'));
    await tester.pump();

    expect(find.widgetWithText(Chip, 'Cat'), findsOneWidget);
    expect(find.text("I'm done (1)"), findsOneWidget);

    // Same word again → not novel.
    await tester.enterText(find.byType(TextField), 'Cat');
    await tester.pump();
    expect(find.text('You already have that one!'), findsOneWidget);
  });
}
