// Widget test for the /conductor Layer-3 planning desk (slice 3): it shows
// the week's anchor actions, a roster linking to each child's Book, and — when
// the journey isn't set up — a nudge to set the start date.

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/action_words/world_blocks.dart';
import 'package:differentworld/features/cockpit/conductor_screen.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Subject _subject(String id, String first, String last) => Subject(
      id: id,
      spaceId: 'space-1',
      firstName: first,
      lastName: last,
      capabilities: '{}',
      createdAt: '2026-06-06T00:00:00Z',
      updatedAt: '2026-06-06T00:00:00Z',
    );

Future<void> _pump(WidgetTester tester, List<Subject> subjects) async {
  tester.view.physicalSize = const Size(1200 * 2, 1600 * 2);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final router = GoRouter(
    initialLocation: '/conductor',
    routes: [
      GoRoute(path: '/conductor', builder: (_, _) => const ConductorScreen()),
      for (final p in <String>[
        '/book/:id',
        '/program',
        '/action-words/send',
        '/this-week',
      ])
        GoRoute(
          path: p,
          builder: (_, _) => const Scaffold(body: Text('pushed')),
        ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        subjectsInSpaceProvider.overrideWith((ref) => Stream.value(subjects)),
        // Journey not set up → the overview becomes the setup nudge.
        seasonPositionProvider.overrideWith((ref) => null),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the week actions + a roster of book links',
      (tester) async {
    await _pump(tester, [
      _subject('s1', 'Leah', 'M'),
      _subject('s2', 'Marcus', 'B'),
    ]);

    // ContentHeader uppercases its title.
    expect(find.text('CONDUCTOR'), findsOneWidget);
    // The week's two anchor moves (FeatureCard titles — rendered as-is).
    expect(find.text('The week’s plan'), findsOneWidget);
    expect(find.text('Send home'), findsOneWidget);
    // Roster → each child (a tap opens their Book).
    expect(find.text('Leah M'), findsOneWidget);
    expect(find.text('Marcus B'), findsOneWidget);
    // Journey not set up → the setup nudge instead of a season header.
    expect(find.text('Set up the journey'), findsOneWidget);
  });

  testWidgets('empty roster shows the empty state', (tester) async {
    await _pump(tester, const []);
    // EmptyState uppercases its title (the semantics label keeps the original).
    expect(find.text('NO CHILDREN YET'), findsOneWidget);
  });
}
