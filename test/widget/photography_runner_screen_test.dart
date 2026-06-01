// Widget tests for the Photography activity (docs/ACTIVITY_RUNTIME.md §5).
// The camera capture loop is device-only; here we cover the parts that
// AREN'T the camera: the activity shape, the gallery rendering, and that
// the screen mounts + degrades gracefully where no camera exists (test,
// web, desktop).

import 'dart:convert';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:differentworld/features/activity_runtime/activity_script.dart';
import 'package:differentworld/features/activity_runtime/photography.dart';
import 'package:differentworld/features/activity_runtime/photography_runner_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A valid 1×1 transparent PNG — so Image.memory decodes without error.
final Uint8List _png1x1 = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  test('photographyActivity is shoot → gallery, prompt on the shoot phase', () {
    final a = photographyActivity(prompt: 'find a shadow');
    expect(
      a.phases.map((p) => p.mode).toList(),
      [ActivityMode.shoot, ActivityMode.present],
    );
    expect(a.phases.first.prompt, 'find a shadow');
  });

  testWidgets('PhotoGalleryView renders one tile per photo', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PhotoGalleryView(photos: [_png1x1, _png1x1, _png1x1]),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(Image), findsNWidgets(3));
  });

  testWidgets('screen mounts and degrades gracefully without a camera', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              const PhotographyRunnerScreen(prompt: 'find a shadow'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pump(); // kid-mode microtask
    await tester.pump(const Duration(milliseconds: 50)); // camera init future

    // The point: mounting a camera screen where no camera exists must not
    // crash, and must not show a live preview — it shows a fallback
    // (permission-denied or unavailable, depending on the host).
    expect(tester.takeException(), isNull);
    expect(find.byType(PhotographyRunnerScreen), findsOneWidget);
    expect(find.byType(CameraPreview), findsNothing);
  });
}
