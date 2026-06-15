import 'dart:io';
import 'dart:ui' as ui;

import 'package:differentworld/shared/widgets/horizon_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// One-shot brand-asset generator. Paints the Horizon mark (the SAME
/// `paintHorizon` the app draws) to `assets/brand/icon.png` — the 1024² source
/// that `flutter_launcher_icons` + `flutter_native_splash` consume. So the
/// launcher icon can never drift from the in-app mark, and no external
/// rasterizer is needed (it rides the test engine's `Picture.toImage`).
///
/// `runAsync` is required — `toImage` / `toByteData` do real (GPU) async work
/// that the default fake-async test zone won't drive.
///
/// Re-run after the mark changes:
///   flutter test tool/render_brand_assets.dart
void main() {
  testWidgets('render brand icon', (tester) async {
    await tester.runAsync(() async {
      const size = Size(1024, 1024);
      final recorder = ui.PictureRecorder();
      paintHorizon(Canvas(recorder), size, field: kBrandTeal);
      final image = await recorder.endRecording().toImage(1024, 1024);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('assets/brand/icon.png')
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    expect(File('assets/brand/icon.png').lengthSync(), greaterThan(1000));
  });
}
