import 'package:differentworld/features/world/draw_self_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression test for the kid-mode escape fix: `draw_self_screen` shipped with
/// only the kidModeLockedRoute pin (which catches go_router nav) and NO
/// PopScope — so a child could tap the OS back button and land on the staff
/// screen underneath, chrome stripped. The fix added `PopScope(canPop: false)`.
/// This pins it: the system back must NOT pop the locked draw-self screen.
void main() {
  testWidgets(
    'draw-self swallows the system back-button in kid mode '
    '(only Cancel/Done leave)',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const DrawSelfScreen(subjectId: 's1'),
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(DrawSelfScreen), findsOneWidget);

      // Simulate the Android system back. PopScope(canPop: false) must swallow
      // it — the kid stays on draw-self instead of escaping to the screen
      // underneath. Without the fix this pops the route and the expectation
      // below fails.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(
        find.byType(DrawSelfScreen),
        findsOneWidget,
        reason: 'system back must not pop the kid-locked draw-self screen',
      );
    },
  );
}
