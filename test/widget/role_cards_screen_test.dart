// Widget test for the Role Cards deck (docs/ROLES_SMART_PRACTICE.md). The
// catalog renders a tile per role; tapping one flips to its card face — the
// "Today I am ___" header + the 3 daily habits.

import 'package:differentworld/features/activity_runtime/role_cards_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Widget harness() {
    final router = GoRouter(
      initialLocation: '/activity/roles',
      routes: [
        GoRoute(
          path: '/activity/roles',
          builder: (_, _) => const RoleCardsScreen(),
        ),
      ],
    );
    return ProviderScope(child: MaterialApp.router(routerConfig: router));
  }

  testWidgets('shows the catalog with role tiles', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('Role Cards'), findsOneWidget);
    expect(find.text('Ant'), findsOneWidget);
    expect(find.text('Bee'), findsOneWidget);
    expect(find.text('Dolphin'), findsOneWidget);
  });

  testWidgets('tapping a role flips to its card face', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ant'));
    await tester.pumpAndSettle();

    expect(find.text('Today I am an Ant'), findsOneWidget);
    expect(find.text('I carry something heavy'), findsOneWidget);
  });

  testWidgets('switching to the People deck swaps the cards', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    // Animals are showing first.
    expect(find.text('Ant'), findsOneWidget);
    expect(find.text('Astronaut'), findsNothing);

    await tester.tap(find.text('🧑‍🚀  People & Jobs'));
    await tester.pumpAndSettle();

    expect(find.text('Astronaut'), findsOneWidget);
    expect(find.text('Ant'), findsNothing);

    await tester.tap(find.text('Astronaut'));
    await tester.pumpAndSettle();
    expect(find.text('Today I am an Astronaut'), findsOneWidget);
  });
}
