// Web-platform smoke test for the poster export pipeline. Run with:
//   flutter test --platform chrome test/web_smoke
// On the VM it exercises the isolate paths; on chrome it exercises the
// kIsWeb same-thread fallbacks. The regression this pins: buildPosterPdf
// called Isolate.run unguarded, which throws UnsupportedError on web and
// killed every web PDF export behind a generic error banner (2026-08-19).

import 'dart:typed_data';

import 'package:differentworld/features/poster/poster_engine.dart';
import 'package:differentworld/features/poster/poster_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  Uint8List solidPng(int w, int h) {
    final image = img.Image(width: w, height: h);
    img.fill(image, color: img.ColorRgb8(200, 140, 90));
    return Uint8List.fromList(img.encodePng(image));
  }

  test('the full PDF export pipeline completes on this platform', () async {
    final bytes = solidPng(400, 300);
    final layout = computePosterLayout(
      const PosterOptions(fitShape: false),
      400 / 300,
    );
    final pdf = await renderPosterPdf(bytes, layout, PosterFit.fill);
    expect(pdf, isNotEmpty);
    expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
  });

  test('the per-page tile render completes on this platform', () async {
    final bytes = solidPng(400, 300);
    final layout = computePosterLayout(
      const PosterOptions(fitShape: false),
      400 / 300,
    );
    final tiles = await renderPosterTiles(bytes, layout, PosterFit.fill);
    expect(tiles.length, layout.pageCount);
  });
}
