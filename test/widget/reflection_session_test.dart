import 'package:differentworld/features/reflections/reflection_providers.dart';
import 'package:differentworld/features/reflections/reflection_session_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Mounts the screen the proven way (MaterialApp.router + GoRouter, the
/// go_router context an EdgeScaffold needs), with the growth strip stubbed
/// empty so the test isolates the session card — no real database.
Widget _host() {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const ReflectionSessionScreen()),
    ],
  );
  return ProviderScope(
    overrides: [
      recentReflectionsProvider.overrideWith((ref) async* {
        yield const <ReflectionView>[];
      }),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(400 * 3, 900 * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('counts up; a short session can save without a face', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_host());
    await tester.pump();
    // Before any time passes the clock reads zero…
    expect(find.text('00:00'), findsOneWidget);
    // …and it counts UP on its own (a stopwatch, not a countdown box).
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('00:00'), findsNothing);

    await tester.tap(find.text('Stop & reflect'));
    await tester.pump();
    expect(find.text('How did it go?'), findsOneWidget);

    // Below the 2-minute threshold → Save is enabled even with no face.
    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save reflection'),
    );
    expect(save.onPressed, isNotNull);

    // Dispose so the periodic ticker is cancelled (no pending-timer error).
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a long session requires a face before saving', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(seconds: 121));

    await tester.tap(find.text('Stop & reflect'));
    await tester.pump();

    FilledButton saveButton() => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save reflection'),
    );

    // Past the threshold → can't save until a face is chosen.
    expect(saveButton().onPressed, isNull);

    await tester.tap(find.text('Great'));
    await tester.pump();
    expect(saveButton().onPressed, isNotNull);

    await tester.pumpWidget(const SizedBox());
  });
}
