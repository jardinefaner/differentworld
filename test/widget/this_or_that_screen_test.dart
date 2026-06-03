// Widget test for This or That — now running on the unified Game framework
// (docs/GAMES.md Wave 0b): GameRunner + LocalGameController + GameScaffold +
// ThisOrThatGame. These assertions are the behavioral LOCK on the port — the
// same expectations the bespoke screen met, so green here = equivalent.
// Default test surface is 800x600 → the wide (presentation + control bar)
// layout.

import 'package:differentworld/features/games/game_runner.dart';
import 'package:differentworld/features/games/games/this_or_that_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget harness() => const ProviderScope(
    child: MaterialApp(home: GameRunner(def: ThisOrThatGame())),
  );

  // Content is dynamic now (the ContentEngine generates + shuffles for
  // freshness), so these lock the framework BEHAVIOR — count, controls,
  // advancing, reveal — not specific seed words.
  testWidgets('presents the first pair with host controls', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('1 / 8'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Next'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Discuss'), findsOneWidget);
  });

  testWidgets('Next advances the slide', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();

    expect(find.text('2 / 8'), findsOneWidget);
  });

  testWidgets('Discuss reveals the prompt for the room', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.textContaining('Why?'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Discuss'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Why?'), findsOneWidget);
  });

  testWidgets('Back is inactive on slide 1, active after Next', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    // Wide layout's Back is a filledTonal IconButton (no text label).
    final back = find.widgetWithIcon(IconButton, Icons.arrow_back);
    expect(
      tester.widget<IconButton>(back).onPressed,
      isNull,
      reason: 'Back inactive on slide 1',
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<IconButton>(back).onPressed,
      isNotNull,
      reason: 'Back active after advancing',
    );
  });

  testWidgets('phone width shows the big control panel', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('Slide 1 of 8'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Next'), findsOneWidget);
  });
}
