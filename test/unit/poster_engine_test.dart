// The poster tiling geometry. Seamless assembly (pages abut with no
// overlap/gap) depends entirely on these pure functions agreeing between
// the isolate renderer and the on-screen preview — so they're pinned here.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:differentworld/features/poster/poster_engine.dart';
import 'package:differentworld/features/poster/poster_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  const letterAspect = kLetterWidthIn / kLetterHeightIn; // 8.5 / 11

  group('posterPageCount', () {
    test('N×N pages', () {
      expect(posterPageCount(2), 4);
      expect(posterPageCount(3), 9);
      expect(posterPageCount(4), 16);
    });
  });

  group('posterCanvasAspect', () {
    test('a square grid keeps the single-page aspect at any N', () {
      // The whole point: the assembled poster is the same shape as one
      // page, so the preview can frame the image with one AspectRatio.
      expect(posterCanvasAspect(8.5, 11), closeTo(letterAspect, 1e-9));
    });
  });

  group('posterPageRect', () {
    test('row-major tiling, (0,0) top-left, pages exactly partition', () {
      // 2×2 over a 100×200 canvas → four 50×100 quadrants.
      expect(posterPageRect(2, 2, 0, 0, 100, 200), (0.0, 0.0, 50.0, 100.0));
      expect(posterPageRect(2, 2, 0, 1, 100, 200), (50.0, 0.0, 50.0, 100.0));
      expect(posterPageRect(2, 2, 1, 0, 100, 200), (0.0, 100.0, 50.0, 100.0));
      expect(posterPageRect(2, 2, 1, 1, 100, 200), (50.0, 100.0, 50.0, 100.0));
    });

    test('non-square grid (3 cols × 2 rows) partitions correctly', () {
      // 3 wide × 2 tall over 120×80 → 40×40 cells.
      expect(posterPageRect(3, 2, 0, 0, 120, 80), (0.0, 0.0, 40.0, 40.0));
      expect(posterPageRect(3, 2, 1, 2, 120, 80), (80.0, 40.0, 40.0, 40.0));
    });

    test('pages cover the canvas with no gap and no overlap', () {
      const cols = 3;
      const rows = 2;
      const cw = 99.0;
      const ch = 90.0;
      final (lastL, _, lastW, _) = posterPageRect(
        cols,
        rows,
        0,
        cols - 1,
        cw,
        ch,
      );
      expect(lastL + lastW, closeTo(cw, 1e-9));
      final (_, lastT, _, lastH) = posterPageRect(
        cols,
        rows,
        rows - 1,
        0,
        cw,
        ch,
      );
      expect(lastT + lastH, closeTo(ch, 1e-9));
    });
  });

  group('computePosterLayout', () {
    double mismatch(double a, double b) => a > b ? a / b : b / a;

    test('fitShape off → a plain square size×size of portrait pages', () {
      final l = computePosterLayout(
        const PosterOptions(size: 3, fitShape: false),
        2,
      );
      expect(l.cols, 3);
      expect(l.rows, 3);
      expect(l.landscape, isFalse);
    });

    test('the long edge == size; the minor edge stays >= 1', () {
      for (final asp in const [0.3, 0.8, 1.0, 1.5, 3.0]) {
        final l = computePosterLayout(const PosterOptions(size: 4), asp);
        expect(math.max(l.cols, l.rows), 4);
        expect(math.min(l.cols, l.rows), greaterThanOrEqualTo(1));
      }
    });

    test('a wide image yields a wider-than-tall poster', () {
      final l = computePosterLayout(const PosterOptions(size: 3), 2); // 2:1
      expect(l.canvasAspect, greaterThan(1.0));
      expect(l.assembledWidthIn, greaterThan(l.assembledHeightIn));
    });

    test('a tall image yields a taller-than-wide poster', () {
      final l = computePosterLayout(const PosterOptions(size: 3), 0.5); // 1:2
      expect(l.canvasAspect, lessThan(1.0));
      expect(l.assembledHeightIn, greaterThan(l.assembledWidthIn));
    });

    test('fit-to-shape matches the image at least as well as the square', () {
      const aspect = 1.6;
      final fitted = computePosterLayout(const PosterOptions(size: 3), aspect);
      final square = computePosterLayout(
        const PosterOptions(size: 3, fitShape: false),
        aspect,
      );
      expect(
        mismatch(fitted.canvasAspect, aspect),
        lessThanOrEqualTo(mismatch(square.canvasAspect, aspect)),
      );
    });

    test('A4 paper is carried through to the layout', () {
      final l = computePosterLayout(
        const PosterOptions(paper: PosterPaper.a4),
        1,
      );
      expect(l.paper, PosterPaper.a4);
    });

    test('orientation defaults to auto', () {
      expect(const PosterOptions().orientation, PosterOrientation.auto);
    });

    test(
      'forced portrait keeps every page portrait, even for a wide image',
      () {
        final l = computePosterLayout(
          const PosterOptions(size: 3, orientation: PosterOrientation.portrait),
          2.5, // very wide image that auto would tile on landscape pages
        );
        expect(l.landscape, isFalse);
        expect(math.max(l.cols, l.rows), 3); // grid still honors size
      },
    );

    test(
      'forced landscape keeps every page landscape, even for a tall image',
      () {
        final l = computePosterLayout(
          const PosterOptions(
            size: 3,
            orientation: PosterOrientation.landscape,
          ),
          0.4, // very tall image
        );
        expect(l.landscape, isTrue);
        expect(math.max(l.cols, l.rows), 3);
      },
    );

    test('forced orientation applies to the plain square grid too', () {
      final l = computePosterLayout(
        const PosterOptions(
          size: 3,
          fitShape: false,
          orientation: PosterOrientation.landscape,
        ),
        1,
      );
      expect(l.cols, 3);
      expect(l.rows, 3);
      expect(l.landscape, isTrue);
    });
  });

  group('posterCoverCrop (fill)', () {
    test('a wider-than-canvas image crops the sides, keeps full height', () {
      final (l, t, w, h) = posterCoverCrop(2000, 1000, letterAspect);
      expect(t, 0); // no vertical crop
      expect(h, 1000); // full height kept
      expect(w, closeTo(1000 * letterAspect, 1e-6)); // width trimmed to aspect
      expect(l, closeTo((2000 - 1000 * letterAspect) / 2, 1e-6)); // centered
      expect(w / h, closeTo(letterAspect, 1e-9)); // crop matches canvas
    });

    test('a taller-than-canvas image crops top/bottom, keeps full width', () {
      final (l, t, w, h) = posterCoverCrop(1000, 3000, letterAspect);
      expect(l, 0); // no horizontal crop
      expect(w, 1000); // full width kept
      expect(h, closeTo(1000 / letterAspect, 1e-6));
      expect(t, closeTo((3000 - 1000 / letterAspect) / 2, 1e-6)); // centered
      expect(w / h, closeTo(letterAspect, 1e-9));
    });

    test('the crop region always matches the canvas aspect', () {
      for (final dims in const [
        [800, 800],
        [1600, 900],
        [600, 2000],
      ]) {
        final (_, _, w, h) = posterCoverCrop(
          dims[0].toDouble(),
          dims[1].toDouble(),
          letterAspect,
        );
        expect(w / h, closeTo(letterAspect, 1e-9));
      }
    });
  });

  group('posterContainPlacement (whole)', () {
    test('a square image fits the narrow axis, centers with margins', () {
      // Canvas is portrait (letter); a square image fits to width.
      final (l, t, w, h) = posterContainPlacement(1000, 1000, 850, 1100);
      expect(w, closeTo(850, 1e-6)); // limited by width
      expect(h, closeTo(850, 1e-6)); // square stays square (no distortion)
      expect(l, closeTo(0, 1e-6));
      expect(t, closeTo((1100 - 850) / 2, 1e-6)); // vertical margins
    });

    test('a wide image fits to width, leaves top/bottom margins', () {
      final (l, t, w, h) = posterContainPlacement(2000, 1000, 850, 1100);
      expect(w, closeTo(850, 1e-6));
      expect(h, closeTo(425, 1e-6)); // 850 * (1000/2000)
      expect(l, closeTo(0, 1e-6));
      expect(t, closeTo((1100 - 425) / 2, 1e-6));
    });

    test('the placed image preserves the source aspect (never distorts)', () {
      final (_, _, w, h) = posterContainPlacement(1600, 900, 850, 1100);
      expect(w / h, closeTo(1600 / 900, 1e-9));
    });
  });

  group('posterViewRect (fill reposition)', () {
    test('zoom 1 + centered focus equals the centered cover crop', () {
      final cover = posterCoverCrop(2000, 1000, letterAspect);
      final view = posterViewRect(2000, 1000, letterAspect, 1, 0.5, 0.5);
      expect(view.$1, closeTo(cover.$1, 1e-6));
      expect(view.$2, closeTo(cover.$2, 1e-6));
      expect(view.$3, closeTo(cover.$3, 1e-6));
      expect(view.$4, closeTo(cover.$4, 1e-6));
    });

    test('panning a wide image slides the crop across the slack', () {
      final left = posterViewRect(2000, 1000, letterAspect, 1, 0, 0.5);
      final right = posterViewRect(2000, 1000, letterAspect, 1, 1, 0.5);
      expect(left.$1, closeTo(0, 1e-6)); // focus 0 → hugs the left edge
      expect(right.$1, closeTo(2000 - right.$3, 1e-6)); // focus 1 → right edge
      expect(left.$3, closeTo(right.$3, 1e-9)); // same width, just moved
    });

    test('zoom shrinks the view (tighter crop)', () {
      final z1 = posterViewRect(2000, 1000, letterAspect, 1, 0.5, 0.5);
      final z2 = posterViewRect(2000, 1000, letterAspect, 2, 0.5, 0.5);
      expect(z2.$3, closeTo(z1.$3 / 2, 1e-6));
      expect(z2.$4, closeTo(z1.$4 / 2, 1e-6));
    });

    test('the view stays within the image at any focus / zoom', () {
      for (final f in const [0.0, 0.5, 1.0]) {
        for (final z in const [1.0, 2.0, 4.0]) {
          final (l, t, w, h) = posterViewRect(
            1500,
            1200,
            letterAspect,
            z,
            f,
            f,
          );
          expect(l, greaterThanOrEqualTo(-1e-6));
          expect(t, greaterThanOrEqualTo(-1e-6));
          expect(l + w, lessThanOrEqualTo(1500 + 1e-6));
          expect(t + h, lessThanOrEqualTo(1200 + 1e-6));
        }
      }
    });
  });

  // These exercise the real decode/crop/encode (+ PDF assembly), but via the
  // synchronous test seam — spawning Isolate.run() under the full-suite runner
  // is flaky. The thin isolate wrapper itself is verified on-device.
  group('tile render + assembly guides', () {
    Uint8List solidPng(int w, int h) {
      final image = img.Image(width: w, height: h);
      img.fill(image, color: img.ColorRgb8(120, 180, 240));
      return Uint8List.fromList(img.encodePng(image));
    }

    test('produces one tile per page (row-major)', () {
      final bytes = solidPng(600, 800);
      final layout = computePosterLayout(
        const PosterOptions(fitShape: false),
        600 / 800,
      );
      final tiles = renderPosterTilesForTest(bytes, layout, PosterFit.fill);
      expect(tiles.length, layout.pageCount); // 2×2 → 4
    });

    test('guides shrink each tile to leave a trim margin', () {
      final bytes = solidPng(600, 800);
      final layout = computePosterLayout(
        const PosterOptions(fitShape: false),
        600 / 800,
      );
      final plain = renderPosterTilesForTest(bytes, layout, PosterFit.fill);
      final guided = renderPosterTilesForTest(
        bytes,
        layout,
        PosterFit.fill,
        guides: true,
      );
      final p0 = img.decodeImage(plain.first)!;
      final g0 = img.decodeImage(guided.first)!;
      expect(g0.width, lessThan(p0.width));
      expect(g0.height, lessThan(p0.height));
    });

    test('a guided PDF is valid and non-empty', () async {
      final bytes = solidPng(400, 400);
      final layout = computePosterLayout(
        const PosterOptions(fitShape: false),
        1,
      );
      final tiles = renderPosterTilesForTest(
        bytes,
        layout,
        PosterFit.fill,
        guides: true,
      );
      final pdf = await buildPosterPdf(
        tiles: tiles,
        layout: layout,
        guides: true,
      );
      expect(pdf, isNotEmpty);
      expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
    });
  });

  group('print quality', () {
    Uint8List solid(int w, int h) {
      final image = img.Image(width: w, height: h);
      img.fill(image, color: img.ColorRgb8(80, 160, 200));
      return Uint8List.fromList(img.encodePng(image));
    }

    test('High renders larger tiles than Standard on a big grid', () {
      // A 3×3 (33" long) exceeds Standard's 3600px cap (→ ~109 DPI) but not
      // High's 6000px cap (→ 150 DPI), so High's tiles are larger.
      final bytes = solid(2000, 2000);
      final layout = computePosterLayout(const PosterOptions(size: 3), 1);
      final std = renderPosterTilesForTest(bytes, layout, PosterFit.fill);
      final hi = renderPosterTilesForTest(
        bytes,
        layout,
        PosterFit.fill,
        quality: PosterQuality.high,
      );
      final s0 = img.decodeImage(std.first)!;
      final h0 = img.decodeImage(hi.first)!;
      expect(h0.width, greaterThan(s0.width));
      expect(h0.height, greaterThan(s0.height));
    });

    test('Lossless emits PNG tiles; the others emit JPEG', () {
      final bytes = solid(800, 800);
      final layout = computePosterLayout(
        const PosterOptions(fitShape: false),
        1,
      );
      final jpg = renderPosterTilesForTest(bytes, layout, PosterFit.fill).first;
      final png = renderPosterTilesForTest(
        bytes,
        layout,
        PosterFit.fill,
        quality: PosterQuality.lossless,
      ).first;
      expect(jpg[0], 0xFF); // JPEG SOI
      expect(jpg[1], 0xD8);
      expect(png[0], 0x89); // PNG signature
      expect(png[1], 0x50);
    });
  });

  group('renderPosterImagePng (single-image export)', () {
    Uint8List solidPng(int w, int h) {
      final image = img.Image(width: w, height: h);
      img.fill(image, color: img.ColorRgb8(200, 120, 60));
      return Uint8List.fromList(img.encodePng(image));
    }

    test('emits one valid PNG sized to the assembled canvas', () {
      final bytes = solidPng(800, 800);
      final layout = computePosterLayout(
        const PosterOptions(fitShape: false),
        1,
      );
      final out = renderPosterImagePngForTest(bytes, layout, PosterFit.fill);
      expect(out, isNotEmpty);
      expect(out[0], 0x89); // PNG signature
      expect(out[1], 0x50);
      // One continuous image spanning the whole grid (cols·pageW × rows·pageH),
      // not a single page.
      final decoded = img.decodeImage(out)!;
      final tiles = renderPosterTilesForTest(bytes, layout, PosterFit.fill);
      final tile0 = img.decodeImage(tiles.first)!;
      expect(decoded.width, tile0.width * layout.cols);
      expect(decoded.height, tile0.height * layout.rows);
    });

    test('whole-fit also produces a valid PNG', () {
      final bytes = solidPng(1200, 600);
      final layout = computePosterLayout(const PosterOptions(size: 3), 2);
      final out = renderPosterImagePngForTest(bytes, layout, PosterFit.whole);
      expect(out, isNotEmpty);
      expect(out[0], 0x89);
      expect(out[1], 0x50);
    });
  });

  group('custom grid', () {
    test('explicit 3x3 wins over size and fitShape', () {
      final layout = computePosterLayout(
        const PosterOptions(size: 2, customCols: 3, customRows: 3),
        1.5,
      );
      expect(layout.cols, 3);
      expect(layout.rows, 3);
    });

    test('1x4 banner honors forced orientation', () {
      final layout = computePosterLayout(
        const PosterOptions(
          customCols: 1,
          customRows: 4,
          orientation: PosterOrientation.landscape,
        ),
        0.3,
      );
      expect(layout.cols, 1);
      expect(layout.rows, 4);
      expect(layout.landscape, isTrue);
    });

    test('auto orientation picks the better aspect match', () {
      // A wide image on a 2x2 grid → landscape pages match better.
      final layout = computePosterLayout(
        const PosterOptions(customCols: 2, customRows: 2),
        2.0,
      );
      expect(layout.landscape, isTrue);
    });

    test('customCols alone (rows 0) stays on the auto path', () {
      final auto = computePosterLayout(const PosterOptions(size: 3), 1.0);
      final half = computePosterLayout(
        const PosterOptions(size: 3, customCols: 4),
        1.0,
      );
      expect(half.cols, auto.cols);
      expect(half.rows, auto.rows);
    });
  });
}
