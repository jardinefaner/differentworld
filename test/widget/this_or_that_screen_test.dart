// Widget test for the host-run This or That (game-show-host model).
// The teacher drives slides; the room sees the pair. Default test surface
// is 800x600 → the wide (presentation + control bar) layout.

import 'package:differentworld/features/activity_runtime/this_or_that_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget harness() =>
      const ProviderScope(child: MaterialApp(home: ThisOrThatScreen()));

  testWidgets('presents the first pair with host controls', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('Pizza'), findsOneWidget);
    expect(find.text('Tacos'), findsOneWidget);
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
    expect(find.text('Summer'), findsOneWidget);
    expect(find.text('Winter'), findsOneWidget);
  });

  testWidgets('Discuss reveals the prompt for the room', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.textContaining('Why?'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Discuss'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Why?'), findsOneWidget);
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
