// Widget test for the This or That activity (docs/ACTIVITY_RUNTIME.md +
// CONTENT_BANK.md). Drives the full loop: present a pair → pick → advance
// → recap. Content order is the curated seed order, so it's deterministic.

import 'package:differentworld/features/activity_runtime/this_or_that_screen.dart';
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
      routes: [GoRoute(path: '/', builder: (_, _) => const ThisOrThatScreen())],
    );
    return ProviderScope(child: MaterialApp.router(routerConfig: router));
  }

  testWidgets('opens on the first pair with progress', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.text('Pizza'), findsOneWidget);
    expect(find.text('Tacos'), findsOneWidget);
    expect(find.text('1 / 8'), findsOneWidget);
    expect(find.text('OR'), findsOneWidget);
  });

  testWidgets('picking advances to the next pair', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    await tester.tap(find.text('Pizza'));
    await tester.pump();

    expect(find.text('2 / 8'), findsOneWidget);
    expect(find.text('Summer'), findsOneWidget);
    expect(find.text('Winter'), findsOneWidget);
  });

  testWidgets('after the last pair, the recap shows the picks', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    // The 'a' option of each seed pair, in order — tap through the round.
    const firstOptions = [
      'Pizza',
      'Summer',
      'Dogs',
      'Be able to fly',
      'Mountains',
      'Draw it',
      'Morning',
      'Chocolate',
    ];
    for (final opt in firstOptions) {
      expect(find.text(opt), findsOneWidget);
      await tester.tap(find.text(opt));
      await tester.pump();
    }

    expect(find.text('Your picks'), findsOneWidget);
    expect(find.text('Play again'), findsOneWidget);
  });
}
