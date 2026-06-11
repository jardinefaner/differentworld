// Widget test for Group Discussions (docs/VISION.md dream #6). Host-present:
// pick a topic + age (no typing), present prompts one at a time, wrap up.
// NO TextField anywhere — the teacher paces it, the room talks aloud.

import 'package:differentworld/features/activity_runtime/discussions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Widget harness() {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const GroupDiscussionScreen()),
      ],
    );
    return ProviderScope(child: MaterialApp.router(routerConfig: router));
  }

  testWidgets('opens on setup — topic + age picker, no typing', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('GROUP DISCUSSION'), findsOneWidget);
    expect(find.text('✨  Any topic'), findsOneWidget);
    expect(find.textContaining('Start —'), findsOneWidget);
  });

  testWidgets('Start presents a prompt with host controls, no typing', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Start —'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    // The advance control is present (Next prompt, or Wrap up on a 1-deck).
    final advancing =
        find.widgetWithText(FilledButton, 'Next prompt').evaluate().isNotEmpty ||
        find.widgetWithText(FilledButton, 'Wrap up').evaluate().isNotEmpty;
    expect(advancing, isTrue);
    expect(find.text('Back'), findsOneWidget);
  });

  testWidgets('advancing to the end reaches the wrap-up', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Start —'));
    await tester.pumpAndSettle();

    // Tap through however many prompts the session has.
    for (var i = 0; i < 12; i++) {
      final next = find.widgetWithText(FilledButton, 'Next prompt');
      if (next.evaluate().isEmpty) break;
      await tester.tap(next);
      await tester.pump();
    }
    await tester.tap(find.widgetWithText(FilledButton, 'Wrap up'));
    await tester.pumpAndSettle();

    expect(find.text('Great talk!'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'New discussion'), findsOneWidget);
  });
}
