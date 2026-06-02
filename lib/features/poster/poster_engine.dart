import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:differentworld/features/poster/poster_models.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ---------------------------------------------------------------------------
// Pure geometry — the tiling math. Extracted so it's unit-testable without an
// image, a Flutter binding, or an isolate. The isolate renderer and the
// on-screen preview both lean on these so they agree on framing.
// ---------------------------------------------------------------------------

/// US Letter in inches (portrait).
const double kLetterWidthIn = 8.5;
const double kLetterHeightIn = 11;

/// The canvas aspect (width / height) for a square N×N grid of pages.
/// Because the grid scales both axes equally, it always equals the
/// single-page aspect regardless of N — the key fact that lets the
/// preview frame the image exactly as the engine will.
double posterCanvasAspect(double pageW, double pageH) => pageW / pageH;

/// Number of pages an [n]×[n] poster prints to.
int posterPageCount(int n) => n * n;

/// Page (row, col) sub-rectangle within an [n]×[n] grid over a canvas of
/// [canvasW]×[canvasH]. Row-major; (0, 0) is the top-left page. Returns
/// `(left, top, width, height)`.
(double, double, double, double) posterPageRect(
  int n,
  int row,
  int col,
  double canvasW,
  double canvasH,
) {
  final pw0 = canvasW / n;
  final ph0 = canvasH / n;
  return (col * pw0, row * ph0, pw0, ph0);
}

/// For [PosterFit.fill] (cover): the centered crop rect *in source-image
/// pixels* that fills a canvas of the given [canvasAspect]. Overflow on
/// the longer axis is cropped. Returns `(left, top, width, height)`.
(double, double, double, double) posterCoverCrop(
  double imgW,
  double imgH,
  double canvasAspect,
) {
  final imgAspect = imgW / imgH;
  if (imgAspect > canvasAspect) {
    // Image is wider than the canvas → crop the sides.
    final w = imgH * canvasAspect;
    return ((imgW - w) / 2, 0, w, imgH);
  }
  // Image is taller (or equal) → crop top & bottom.
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
/// allocating a huge bitmap (a 4×4 at 150 DPI would be 6600 px tall).
const int _targetDpi = 150;
const int _maxCanvasLongPx = 3600;

/// Per-page pixel dimensions for an [n]×[n] poster, after the long-edge cap.
({int pageW, int pageH, double dpi}) _pagePixels(int n) {
  final desiredLongPx = n * kLetterHeightIn * _targetDpi;
  final dpi = desiredLongPx > _maxCanvasLongPx
      ? _maxCanvasLongPx / (n * kLetterHeightIn)
      : _targetDpi.toDouble();
  return (
    pageW: (kLetterWidthIn * dpi).round(),
    pageH: (kLetterHeightIn * dpi).round(),
    dpi: dpi,
  );
}

/// Decode [bytes], tile per [opts], and return the page images (JPEG bytes,
/// row-major: index `r*n + c`). Runs the CPU-heavy decode/resize/crop in an
/// isolate so the UI thread stays free for the spinner (falls back to the
/// main thread on web, which has no isolates).
///
/// Throws [FormatException] if the bytes can't be decoded as an image.
Future<List<Uint8List>> renderPosterTiles(
  Uint8List bytes,
  PosterOptions opts,
) {
  final n = opts.grid;
  final fit = opts.fit;
  if (kIsWeb) {
    return Future.value(_renderPosterTilesSync(bytes, n, fit));
  }
  return Isolate.run(() => _renderPosterTilesSync(bytes, n, fit));
}

/// Top-level (isolate-safe — no closure over instance state).
List<Uint8List> _renderPosterTilesSync(
  Uint8List bytes,
  int n,
  PosterFit fit,
) {
  final src = img.decodeImage(bytes);
  if (src == null) {
    throw const FormatException('Could not decode the chosen image.');
  }
  final px = _pagePixels(n);
  final pageW = px.pageW;
  final pageH = px.pageH;
  final canvasAspect = pageW / pageH;
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
      for (var row = 0; row < n; row++) {
        for (var col = 0; col < n; col++) {
          final sx = (cl + col * cw / n).round();
          final sy = (ct + row * ch / n).round();
          final sw = math.min((cw / n).round(), src.width - sx).clamp(1, src.width);
          final sh = math.min((ch / n).round(), src.height - sy).clamp(1, src.height);
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
      final canvasW = pageW * n;
      final canvasH = pageH * n;
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
      for (var row = 0; row < n; row++) {
        for (var col = 0; col < n; col++) {
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
// PDF assembly — runs on the main isolate (the `pdf` package's document
// model isn't sendable; tile bytes are cheap to ship back and embed).
// ---------------------------------------------------------------------------

/// Build the multi-page PDF from rendered [tiles] (row-major, length n²).
/// Each tile fills one full-bleed US-Letter page so adjacent pages abut
/// when assembled. When [labels] is on, a faint "R1·C2" chip is printed in
/// each page's corner.
Future<Uint8List> buildPosterPdf({
  required List<Uint8List> tiles,
  required int n,
  bool labels = true,
  String title = 'Poster',
}) async {
  final doc = pw.Document(title: title, creator: 'Different World');
  // Built-in standard PDF font — NOT PdfGoogleFonts (which downloads the
  // TTF from Google's CDN at print time and would break offline-first, the
  // app's core invariant; labels are on by default so it'd hit every first
  // offline print). Helvetica is embedded in every PDF reader — zero
  // network, zero asset.
  final font = labels ? pw.Font.helvetica() : null;

  for (var i = 0; i < tiles.length; i++) {
    final row = i ~/ n;
    final col = i % n;
    final image = pw.MemoryImage(tiles[i]);
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: pw.EdgeInsets.zero,
        build: (context) {
          return pw.Stack(
            fit: pw.StackFit.expand,
            children: [
              pw.Image(image, fit: pw.BoxFit.fill),
              if (labels && font != null)
                pw.Positioned(
                  bottom: 8,
                  right: 8,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: pw.BoxDecoration(
                      color: const PdfColor(1, 1, 1, 0.72),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text(
                      'R${row + 1}·C${col + 1}',
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 9,
                        color: PdfColors.grey800,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
  return doc.save();
}

/// One-shot: render [bytes] per [opts] and assemble the printable PDF.
Future<Uint8List> renderPosterPdf(
  Uint8List bytes,
  PosterOptions opts, {
  String title = 'Poster',
}) async {
  final tiles = await renderPosterTiles(bytes, opts);
  return buildPosterPdf(
    tiles: tiles,
    n: opts.grid,
    labels: opts.labels,
    title: title,
  );
}
