// Pins the back-origin invariant (docs/NAV_MIGRATION.md): the floating
// back pill returns you to the screen you ACTUALLY came from whenever a
// pop is possible. The fallbackRoute is ONLY for cold (deep-link)
// entries with no stack — if a change ever makes back land on the
// fallback while a real origin exists, these tests fail.

import 'package:differentworld/shared/widgets/floating_back.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  GoRouter buildRouter({required String initial}) => GoRouter(
        initialLocation: initial,
        routes: [
          GoRoute(
            path: '/origin',
            builder: (_, _) => Scaffold(
              body: Builder(
                builder: (context) => Column(
                  children: [
                    const Text('origin-screen'),
                    TextButton(
                      onPressed: () => context.push('/detail'),
                      child: const Text('open detail'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/detail',
            builder: (_, _) => const Scaffold(
              body: Stack(
                children: [
                  Text('detail-screen'),
                  // Fallback deliberately points AWAY from /origin so a
                  // pop that lands on /elsewhere would expose a regression.
                  FloatingBack(fallbackRoute: '/elsewhere'),
                ],
              ),
            ),
          ),
          GoRoute(
            path: '/elsewhere',
            builder: (_, _) =>
                const Scaffold(body: Text('elsewhere-screen')),
          ),
        ],
      );

  testWidgets('back pops to the actual origin, not the fallback',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: buildRouter(initial: '/origin')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open detail'));
    await tester.pumpAndSettle();
    expect(find.text('detail-screen'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('origin-screen'), findsOneWidget);
    expect(find.text('elsewhere-screen'), findsNothing);
  });

  testWidgets('cold entry (nothing to pop) goes to the fallback',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: buildRouter(initial: '/detail')),
    );
    await tester.pumpAndSettle();
    expect(find.text('detail-screen'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('elsewhere-screen'), findsOneWidget);
  });

  testWidgets('onPressed override replaces pop/fallback entirely',
      (tester) async {
    var called = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FloatingBack(onPressed: () => called = true),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();

    expect(called, isTrue);
  });
}
