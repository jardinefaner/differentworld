// Widget test for Fact or Fib (more games). Host-present: NO typing, NO
// grading — the room votes True/Fib, the teacher Reveals then advances.

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/activity_runtime/fact_or_fib_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Widget harness() {
    final router = GoRouter(
      initialLocation: '/',
      routes: [GoRoute(path: '/', builder: (_, _) => const FactOrFibScreen())],
    );
    return ProviderScope(child: MaterialApp.router(routerConfig: router));
  }

  testWidgets('opens on the first claim with True/Fib + a Reveal — no typing', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('1 / 10'), findsOneWidget);
    expect(find.text('True'), findsOneWidget);
    expect(find.text('Fib'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Reveal'), findsOneWidget);
  });

  testWidgets('Reveal then Next advances', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Reveal'));
    await tester.pump();
    expect(find.widgetWithText(FilledButton, 'Next'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pump();
    expect(find.text('2 / 10'), findsOneWidget);
  });

  test('fact-or-fib seed: every item has a statement, bool verdict, and note', () {
    final bank = LocalContentBank.seeded();
    final claims = bank.take(ContentKind.factOrFib, 100);
    expect(claims.length, greaterThanOrEqualTo(12));
    for (final c in claims) {
      expect((c.payload['statement']! as String).trim(), isNotEmpty);
      expect(c.payload['isTrue'], isA<bool>());
      expect((c.payload['note']! as String).trim(), isNotEmpty);
    }
  });
}
