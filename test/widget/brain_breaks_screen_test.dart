// Widget test for the Brain Breaks deck (docs/ACTIVITY_RUNTIME.md). The
// deck renders an e-card per activity; tapping one launches it.

import 'package:differentworld/features/activity_runtime/brain_breaks_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Widget harness() {
    final router = GoRouter(
      initialLocation: '/breaks',
      routes: [
        GoRoute(path: '/breaks', builder: (_, _) => const BrainBreaksScreen()),
        GoRoute(
          path: '/activity/this-or-that',
          builder: (_, _) => const Scaffold(body: Text('this-or-that-screen')),
        ),
      ],
    );
    return ProviderScope(child: MaterialApp.router(routerConfig: router));
  }

  // Pinned to Android because the deck is platform-dependent (Photo
  // Studio only exists where isMobileCapturePlatform is true) AND the
  // list is a memoized static — first access freezes its composition
  // for this whole isolate. The desktop/absence case lives in
  // brain_breaks_platform_test.dart (its own isolate) for that reason;
  // don't add a desktop-variant test to THIS file.
  testWidgets(
    'the deck shows a card for each brain break',
    (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      expect(find.text('Brain Breaks'), findsOneWidget);
      expect(find.text('Quick Picks'), findsOneWidget);
      expect(find.text('Act It Out'), findsOneWidget);
      expect(find.text('Beat the Letter'), findsOneWidget);
      expect(find.text('Many Paths'), findsOneWidget);
      expect(find.text('Photo Studio'), findsOneWidget);
      expect(find.text('Role Cards'), findsOneWidget);
      expect(find.text('Make a Pattern'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('tapping a card launches that activity', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Quick Picks'));
    await tester.pumpAndSettle();

    expect(find.text('this-or-that-screen'), findsOneWidget);
  });
}
