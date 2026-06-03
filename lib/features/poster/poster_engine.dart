import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:differentworld/features/poster/poster_models.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ---------------------------------------------------------------------------
// Paper dimensions (inches). Long / short edge per stock.
// ---------------------------------------------------------------------------

double _paperShortIn(PosterPaper p) => p == PosterPaper.a4 ? 8.27 : 8.5;
double _paperLongIn(PosterPaper p) => p == PosterPaper.a4 ? 11.69 : 11.0;

// ---------------------------------------------------------------------------
// PosterLayout — the concrete page grid derived from PosterOptions + the
// image aspect. This is what the renderer, the PDF builder, and the on-screen
// preview all consume, so they agree on exactly how the image is tiled.
// ---------------------------------------------------------------------------

/// The resolved page grid for a poster: [cols]×[rows] pages of a given
/// orientation + paper. Pure data — no image, no Flutter binding.
@immutable
class PosterLayout {
  const PosterLayout({
    required this.cols,
    required this.rows,
    required this.landscape,
    required this.paper,
  });

  final int cols;
  final int rows;
  final bool landscape;
  final PosterPaper paper;

  int get pageCount => cols * rows;

  /// One page's printable size in inches (orientation applied).
  double get pageWidthIn =>
      landscape ? _paperLongIn(paper) : _paperShortIn(paper);
  double get pageHeightIn =>
      landscape ? _paperShortIn(paper) : _paperLongIn(paper);

  /// The assembled poster's size in inches.
  double get assembledWidthIn => cols * pageWidthIn;
  double get assembledHeightIn => rows * pageHeightIn;

  /// Aspect (width / height) of the assembled poster.
  double get canvasAspect => assembledWidthIn / assembledHeightIn;

  @override
  bool operator ==(Object other) =>
      other is PosterLayout &&
      other.cols == cols &&
      other.rows == rows &&
      other.landscape == landscape &&
      other.paper == paper;

  @override
  int get hashCode => Object.hash(cols, rows, landscape, paper);

  @override
  String toString() =>
      'PosterLayout(${cols}x$rows, ${landscape ? 'landscape' : 'portrait'}, '
      '${paper.name})';
}

/// Choose the page grid for [opts] given the source image's [imageAspect]
/// (width / height). When [PosterOptions.fitShape] is off, returns a plain
/// square `size`×`size` of portrait pages. When on, searches every
/// columns×rows (with the longer edge == `size`) in both page orientations
/// and picks the grid whose assembled aspect best matches the image — the
/// least cropping (fill) / least wasted paper (whole). Ties break toward
/// fewer pages, then the orientation matching the image.
PosterLayout computePosterLayout(PosterOptions opts, double imageAspect) {
  final size = opts.size;
  if (!opts.fitShape) {
    return PosterLayout(
      cols: size,
      rows: size,
      landscape: false,
      paper: opts.paper,
    );
  }

  final aspect = imageAspect.isFinite && imageAspect > 0 ? imageAspect : 1.0;
  PosterLayout? best;
  var bestScore = double.infinity;

  double mismatch(double a, double b) => a > b ? a / b : b / a;

  for (final landscape in [false, true]) {
    for (var minor = 1; minor <= size; minor++) {
      // The longer page-count is always `size`; pair it both ways so the
      // poster can be wide (cols=size) or tall (rows=size).
      for (final dims in [
        (size, minor),
        (minor, size),
      ]) {
        final cand = PosterLayout(
          cols: dims.$1,
          rows: dims.$2,
          landscape: landscape,
          paper: opts.paper,
        );
        final score = mismatch(cand.canvasAspect, aspect);
        // Primary: closest aspect. Tie-break: fewer pages, then the page
        // orientation that matches the image's orientation.
        final orientationMatch =
            (aspect >= 1) == landscape ? 0 : 1; // 0 = matches
        final better = score < bestScore - 1e-9 ||
            (score < bestScore + 1e-9 &&
                (cand.pageCount < best!.pageCount ||
                    (cand.pageCount == best.pageCount &&
                        orientationMatch <
                            ((aspect >= 1) == best.landscape ? 0 : 1))));
        if (better) {
          best = cand;
          bestScore = score;
        }
      }
    }
  }
  return best!;
}

// ---------------------------------------------------------------------------
// Pure geometry — the tiling math. Unit-testable without an image, a Flutter
// binding, or an isolate. The isolate renderer and the preview both lean on
// these so they agree on framing.
// ---------------------------------------------------------------------------

/// US Letter in inches (portrait). Kept for the preview's default framing
/// and back-compat with existing geometry tests.
const double kLetterWidthIn = 8.5;
const double kLetterHeightIn = 11;

/// The canvas aspect (width / height) for a square N×N grid of pages.
double posterCanvasAspect(double pageW, double pageH) => pageW / pageH;

/// Number of pages an [n]×[n] poster prints to.
int posterPageCount(int n) => n * n;

/// Page (row, col) sub-rectangle within a [cols]×[rows] grid over a canvas
/// of [canvasW]×[canvasH]. Row-major; (0, 0) is the top-left page. Returns
/// `(left, top, width, height)`.
(double, double, double, double) posterPageRect(
  int cols,
  int rows,
  int row,
  int col,
  double canvasW,
  double canvasH,
) {
  final pw0 = canvasW / cols;
  final ph0 = canvasH / rows;
  return (col * pw0, row * ph0, pw0, ph0);
}

/// For [PosterFit.fill] (cover): the centered crop rect *in source-image
/// pixels* that fills a canvas of the given [canvasAspect]. Overflow on the
/// longer axis is cropped. Returns `(left, top, width, height)`.
(double, double, double, double) posterCoverCrop(
  double imgW,
  double imgH,
  double canvasAspect,
) {
  final imgAspect = imgW / imgH;
  if (imgAspect > canvasAspect) {
    final w = imgH * canvasAspect;
    return ((imgW - w) / 2, 0, w, imgH);
  }
  final h = imgW / canvasAspect;
  return (0, (imgH - h) / 2, imgW, h);
}

/// For [PosterFit.whole] (contain): where the whole image lands, centered,
/// on a canvas of [canvasW]×[canvasH]. The rest of the canvas is white.
/// Returns `(left, top, width, height)` in canvas pixels.
(double, double, double, double) posterContainPlacement(
  double imgW,
  double imgH,
  double canvasW,
  double canvasH,
) {
  final scale = math.min(canvasW / imgW, canvasH / imgH);
  final w = imgW * scale;
  final h = imgH * scale;
  return ((canvasW - w) / 2, (canvasH - h) / 2, w, h);
}

// ---------------------------------------------------------------------------
// Render — heavy image work, run in an isolate (off the UI thread).
// ---------------------------------------------------------------------------

/// Target print density. The assembled poster's long edge is capped at
/// [_maxCanvasLongPx] so a big grid degrades DPI gracefully instead of
/// allocating a huge bitmap.
const int _targetDpi = 150;
const int _maxCanvasLongPx = 3600;

/// The white border (inches) reserved on each page when assembly guides are
/// on — room for the dashed cut line + crop marks, and a safe trim margin
/// (most printers can't print the outer ~0.25"). After trimming on the
/// dashed line, the pages butt together seamlessly.
const double kGuideMarginIn = 0.35;

/// Per-page pixel dimensions for [layout] + the chosen print density, after
/// the long-edge cap.
({int pageW, int pageH, double dpi}) _pagePixels(PosterLayout layout) {
  final longIn = math.max(layout.assembledWidthIn, layout.assembledHeightIn);
  final desiredLongPx = longIn * _targetDpi;
  final dpi =
      desiredLongPx > _maxCanvasLongPx ? _maxCanvasLongPx / longIn : _targetDpi.toDouble();
  return (
    pageW: (layout.pageWidthIn * dpi).round(),
    pageH: (layout.pageHeightIn * dpi).round(),
    dpi: dpi,
  );
}

/// Decode [bytes], rotate by [quarterTurns] × 90° (lossless), and tile per
/// [layout] + [fit], returning the page images (JPEG bytes, row-major:
/// index `row * cols + col`). Runs the CPU-heavy decode/rotate/resize/crop
/// in an isolate (falls back to the main thread on web, which has no
/// isolates).
///
/// Throws [FormatException] if the bytes can't be decoded as an image.
Future<List<Uint8List>> renderPosterTiles(
  Uint8List bytes,
  PosterLayout layout,
  PosterFit fit, {
  int quarterTurns = 0,
  bool guides = false,
}) {
  if (kIsWeb) {
    return Future.value(
      _renderPosterTilesSync(bytes, layout, fit, quarterTurns, guides),
    );
  }
  return Isolate.run(
    () => _renderPosterTilesSync(bytes, layout, fit, quarterTurns, guides),
  );
}

/// Top-level (isolate-safe — no closure over instance state).
List<Uint8List> _renderPosterTilesSync(
  Uint8List bytes,
  PosterLayout layout,
  PosterFit fit,
  int quarterTurns,
  bool guides,
) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('Could not decode the chosen image.');
  }
  final turns = quarterTurns % 4;
  final src =
      turns == 0 ? decoded : img.copyRotate(decoded, angle: 90.0 * turns);
  final px = _pagePixels(layout);
  // With guides on, the image only fills the trimmable area inside each
  // page's margin — so the tiles are smaller and the white border is added
  // in the PDF. The continuous image still spans the IMAGE areas, so after
  // trimming the margins the pages butt together seamlessly.
  final marginPx = guides ? (kGuideMarginIn * px.dpi).round() : 0;
  final pageW = math.max(1, px.pageW - 2 * marginPx);
  final pageH = math.max(1, px.pageH - 2 * marginPx);
  final cols = layout.cols;
  final rows = layout.rows;
  final canvasAspect = (cols * pageW) / (rows * pageH);
  final tiles = <Uint8List>[];

  switch (fit) {
    case PosterFit.fill:
      // Cover: crop the source to the canvas aspect, then slice each page
      // directly out of the (un-resized) source and resize only that tile.
      // Peak memory = source + one page (never the whole canvas at once).
      final (cl, ct, cw, ch) = posterCoverCrop(
        src.width.toDouble(),
        src.height.toDouble(),
        canvasAspect,
      );
      for (var row = 0; row < rows; row++) {
        for (var col = 0; col < cols; col++) {
          final sx = (cl + col * cw / cols).round();
          final sy = (ct + row * ch / rows).round();
          final sw =
              math.min((cw / cols).round(), src.width - sx).clamp(1, src.width);
          final sh = math
              .min((ch / rows).round(), src.height - sy)
              .clamp(1, src.height);
          final crop = img.copyCrop(
            src,
            x: sx.clamp(0, src.width - 1),
            y: sy.clamp(0, src.height - 1),
            width: sw,
            height: sh,
          );
          final tile = img.copyResize(
            crop,
            width: pageW,
            height: pageH,
            interpolation: img.Interpolation.average,
          );
          tiles.add(Uint8List.fromList(img.encodeJpg(tile, quality: 85)));
        }
      }

    case PosterFit.whole:
      // Contain: place the whole image centered on a white canvas, then
      // slice. Builds the full canvas once (less common path).
      final canvasW = pageW * cols;
      final canvasH = pageH * rows;
      final canvas = img.Image(width: canvasW, height: canvasH);
      img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
      final (pl, pt, pw0, ph0) = posterContainPlacement(
        src.width.toDouble(),
        src.height.toDouble(),
        canvasW.toDouble(),
        canvasH.toDouble(),
      );
      final scaled = img.copyResize(
        src,
        width: pw0.round().clamp(1, canvasW),
        height: ph0.round().clamp(1, canvasH),
        interpolation: img.Interpolation.average,
      );
      img.compositeImage(canvas, scaled, dstX: pl.round(), dstY: pt.round());
      for (var row = 0; row < rows; row++) {
        for (var col = 0; col < cols; col++) {
          final tile = img.copyCrop(
            canvas,
            x: col * pageW,
            y: row * pageH,
            width: pageW,
            height: pageH,
          );
          tiles.add(Uint8List.fromList(img.encodeJpg(tile, quality: 85)));
        }
      }
  }
  return tiles;
}

// ---------------------------------------------------------------------------
// PDF assembly — runs on the main isolate.
// ---------------------------------------------------------------------------

/// Build the multi-page PDF from rendered [tiles] (row-major, length
/// `layout.pageCount`). Without [guides], each tile fills one full-bleed page
/// so adjacent pages abut. With [guides], each tile is inset by a white trim
/// margin carrying a dashed cut line + corner crop marks, and an "Assembly
/// map" page is appended. When [labels] is on, a faint "R1·C2" chip is
/// printed in each page's corner.
Future<Uint8List> buildPosterPdf({
  required List<Uint8List> tiles,
  required PosterLayout layout,
  bool labels = true,
  bool guides = false,
  String title = 'Poster',
}) async {
  final doc = pw.Document(title: title, creator: 'Different World');
  // Built-in standard PDF fonts — NOT PdfGoogleFonts (which downloads the
  // TTF from Google's CDN at print time and would break offline-first).
  final font = pw.Font.helvetica();
  final fontBold = pw.Font.helveticaBold();

  var format = layout.paper == PosterPaper.a4
      ? PdfPageFormat.a4
      : PdfPageFormat.letter;
  if (layout.landscape) format = format.landscape;

  final marginPt = guides ? kGuideMarginIn * PdfPageFormat.inch : 0.0;
  final cols = layout.cols;

  for (var i = 0; i < tiles.length; i++) {
    final row = i ~/ cols;
    final col = i % cols;
    final image = pw.MemoryImage(tiles[i]);
    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.zero,
        build: (context) {
          return pw.Stack(
            fit: pw.StackFit.expand,
            children: [
              pw.Positioned(
                left: marginPt,
                top: marginPt,
                right: marginPt,
                bottom: marginPt,
                child: pw.Image(image, fit: pw.BoxFit.fill),
              ),
              if (guides)
                pw.CustomPaint(
                  size: PdfPoint(format.width, format.height),
                  painter: (canvas, size) =>
                      _drawTrimGuides(canvas, size, marginPt),
                ),
              if (labels)
                pw.Positioned(
                  bottom: marginPt + 6,
                  right: marginPt + 6,
                  // ASCII only — built-in Helvetica can't render "·"/"×".
                  child: _labelChip(font, 'R${row + 1}-C${col + 1}'),
                ),
            ],
          );
        },
      ),
    );
  }

  if (guides) {
    doc.addPage(_mapPage(format, layout, font, fontBold));
  }
  return doc.save();
}

/// Draw the dashed cut line (at the image-area boundary, [m] points in from
/// every edge) + solid corner crop marks reaching out into the trim margin.
/// The guides are symmetric, so the raw-PDF bottom-left origin doesn't change
/// how they look.
void _drawTrimGuides(PdfGraphics canvas, PdfPoint size, double m) {
  final w = size.x;
  final h = size.y;
  canvas
    ..setStrokeColor(PdfColors.grey500)
    ..setLineWidth(0.5)
    ..setLineDashPattern([3, 3])
    ..drawRect(m, m, w - 2 * m, h - 2 * m)
    ..strokePath()
    ..setLineDashPattern() // back to solid
    ..setStrokeColor(PdfColors.grey700)
    ..setLineWidth(0.7);
  const tick = 10.0;
  for (final x in [m, w - m]) {
    for (final y in [m, h - m]) {
      final hx = x == m ? x - tick : x + tick;
      final vy = y == m ? y - tick : y + tick;
      canvas
        ..moveTo(x, y)
        ..lineTo(hx, y)
        ..strokePath()
        ..moveTo(x, y)
        ..lineTo(x, vy)
        ..strokePath();
    }
  }
}

pw.Widget _labelChip(pw.Font font, String text) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: pw.BoxDecoration(
        color: const PdfColor(1, 1, 1, 0.72),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey800),
      ),
    );

/// A final index page: a labeled cols×rows grid so you can see, at a glance,
/// which numbered page goes where.
pw.Page _mapPage(
  PdfPageFormat format,
  PosterLayout layout,
  pw.Font font,
  pw.Font fontBold,
) {
  final cols = layout.cols;
  final rows = layout.rows;
  return pw.Page(
    pageFormat: format,
    margin: const pw.EdgeInsets.all(36),
    build: (context) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Assembly map',
          style: pw.TextStyle(font: fontBold, fontSize: 24),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          '$cols x $rows, ${layout.pageCount} pages. Trim each page on the '
          'dashed line, line them up with R1-C1 at the top-left, and tape.',
          style: pw.TextStyle(
            font: font,
            fontSize: 12,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 18),
        pw.Expanded(
          child: pw.Column(
            children: [
              for (var r = 0; r < rows; r++)
                pw.Expanded(
                  child: pw.Row(
                    children: [
                      for (var c = 0; c < cols; c++)
                        pw.Expanded(
                          child: pw.Container(
                            margin: const pw.EdgeInsets.all(3),
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(
                                color: PdfColors.grey600,
                                width: 0.7,
                              ),
                            ),
                            alignment: pw.Alignment.center,
                            child: pw.Text(
                              'R${r + 1}-C${c + 1}',
                              style: pw.TextStyle(font: font, fontSize: 12),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// One-shot: render [bytes] per [layout] + [fit] (+ optional rotation) and
/// assemble the PDF.
Future<Uint8List> renderPosterPdf(
  Uint8List bytes,
  PosterLayout layout,
  PosterFit fit, {
  bool labels = true,
  String title = 'Poster',
  int quarterTurns = 0,
  bool guides = false,
}) async {
  final tiles = await renderPosterTiles(
    bytes,
    layout,
    fit,
    quarterTurns: quarterTurns,
    guides: guides,
  );
  return buildPosterPdf(
    tiles: tiles,
    layout: layout,
    labels: labels,
    guides: guides,
    title: title,
  );
}
