// Pins the fix for the /play-today no-world dead-end: when no curriculum
// world is live, the screen must offer a real next step ("Set up your
// journey") AND a visible way out ("Close") — not just a raw message with
// the system back gesture as the only exit.

import 'package:differentworld/features/action_words/day_run_screen.dart';
import 'package:differentworld/features/action_words/world_schedule.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('no-world state offers a setup CTA + a way out', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [currentWorldProvider.overrideWithValue(null)],
        child: const MaterialApp(home: DayRunScreen()),
      ),
    );

    expect(find.text('No world is live yet'), findsOneWidget);
    // The fix: a real next step…
    expect(
      find.widgetWithText(FilledButton, 'Set up your journey'),
      findsOneWidget,
    );
    // …and a visible exit (not just the system back gesture).
    expect(find.widgetWithText(TextButton, 'Close'), findsOneWidget);
  });
}
