// The Brain Breaks deck and the slash-command list are platform-
// dependent: camera-backed affordances exist only where
// isMobileCapturePlatform is true (docs/PLATFORM_RUBRIC.md P1 — never
// advertise a dead capture affordance).
//
// This lives in its OWN file because both lists are memoized statics —
// the first access freezes their composition for the whole isolate. A
// desktop-platform case can't share an isolate with the mobile case
// (brain_breaks_screen_test.dart), so each gets its own file and
// `flutter test`'s one-isolate-per-file model keeps them honest.

import 'package:differentworld/features/activity_runtime/brain_breaks_screen.dart';
import 'package:differentworld/features/omnibox/slash_commands.dart';
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
      ],
    );
    return ProviderScope(child: MaterialApp.router(routerConfig: router));
  }

  testWidgets(
    'camera affordances are absent on a desktop platform',
    (tester) async {
      // Both memoized lists are first-touched HERE, under the macOS
      // override, so they build their desktop composition.
      expect(
        allSlashCommands.any((c) => c.name == 'photo'),
        isFalse,
        reason: '/photo must not exist where there is no in-app camera',
      );

      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      expect(find.text('Photo Studio'), findsNothing);
      // The rest of the deck is intact.
      expect(find.text('Quick Picks'), findsOneWidget);
      expect(find.text('Role Cards'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );
}
