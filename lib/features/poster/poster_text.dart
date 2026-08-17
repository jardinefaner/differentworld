import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Render a big text sign to PNG bytes — the "make a sign" path into the
/// poster pipeline (welcome posters, room names, the dinner question).
/// Warm paper ground + warm-charcoal Fraunces, the brand's raw-canvas
/// palette (print surfaces are allowlisted hardcodes —
/// docs/THEME_ADHERENCE.md).
Future<Uint8List> renderTextPoster(
  String text, {
  int width = 2400,
  int height = 1800,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final w = width.toDouble();
  final h = height.toDouble();
  canvas.drawRect(
    Rect.fromLTWH(0, 0, w, h),
    Paint()..color = const Color(0xFFF4F1EA), // raw-canvas
  );

  // Fit the text: binary-search the largest font size that fits the safe
  // area (10% margin all round) in at most 6 lines.
  final safeW = w * 0.8;
  final safeH = h * 0.8;
  TextPainter painterFor(double size) {
    final p = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Fraunces',
          fontSize: size,
          height: 1.15,
          color: const Color(0xFF2D2820), // raw-canvas
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 6,
    )..layout(maxWidth: safeW);
    return p;
  }

  var lo = 24.0;
  var hi = h;
  while (hi - lo > 2) {
    final mid = (lo + hi) / 2;
    final p = painterFor(mid);
    final fits = p.height <= safeH && !p.didExceedMaxLines;
    if (fits) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  final p = painterFor(lo);
  p.paint(canvas, Offset((w - p.width) / 2, (h - p.height) / 2));

  final image = await recorder.endRecording().toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}
