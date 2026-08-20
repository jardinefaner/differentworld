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
    this.overlapIn = 0,
  });

  final int cols;
  final int rows;
  final bool landscape;
  final PosterPaper paper;

  /// Seam cushion (inches): interior seams duplicate this much image on
  /// both adjacent pages so uneven cuts are harmless (see PosterOptions).
  final double overlapIn;

  int get pageCount => cols * rows;

  /// One page's printable size in inches (orientation applied).
  double get pageWidthIn =>
      landscape ? _paperLongIn(paper) : _paperShortIn(paper);
  double get pageHeightIn =>
      landscape ? _paperShortIn(paper) : _paperLongIn(paper);

  /// The horizontal / vertical step between consecutive pages' content —
  /// a full page minus the shared seam strip.
  double get stepWidthIn => pageWidthIn - overlapIn;
  double get stepHeightIn => pageHeightIn - overlapIn;

  /// The assembled poster's size in inches. With overlap the pages
  /// shingle, so each page past the first only advances by a step.
  double get assembledWidthIn => pageWidthIn + (cols - 1) * stepWidthIn;
  double get assembledHeightIn => pageHeightIn + (rows - 1) * stepHeightIn;

  /// Aspect (width / height) of the assembled poster.
  double get canvasAspect => assembledWidthIn / assembledHeightIn;

  @override
  bool operator ==(Object other) =>
      other is PosterLayout &&
      other.cols == cols &&
      other.rows == rows &&
      other.landscape == landscape &&
      other.overlapIn == overlapIn &&
      other.paper == paper;

  @override
  int get hashCode => Object.hash(cols, rows, landscape, paper, overlapIn);

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

  // Explicit custom grid (3×3, 1×4, …): the grid IS the choice; only the
  // page orientation is still picked (forced, or whichever matches the
  // image's shape better).
  if (opts.hasCustomGrid) {
    final a = imageAspect.isFinite && imageAspect > 0 ? imageAspect : 1.0;
    PosterLayout candidate({required bool landscape}) => PosterLayout(
      cols: opts.customCols,
      rows: opts.customRows,
      landscape: landscape,
      paper: opts.paper,
      overlapIn: opts.overlapIn,
    );
    return switch (opts.orientation) {
      PosterOrientation.portrait => candidate(landscape: false),
      PosterOrientation.landscape => candidate(landscape: true),
      PosterOrientation.auto => () {
        final p = candidate(landscape: false);
        final l = candidate(landscape: true);
        double mm(double x, double y) => x > y ? x / y : y / x;
        return mm(p.canvasAspect, a) <= mm(l.canvasAspect, a) ? p : l;
      }(),
    };
  }

  // Which page orientations the grid search may use. Auto weighs both and
  // lets the image's shape decide; a forced orientation pins it.
  final orientations = switch (opts.orientation) {
    PosterOrientation.auto => const [false, true],
    PosterOrientation.portrait => const [false],
    PosterOrientation.landscape => const [true],
  };

  if (!opts.fitShape) {
    // Plain square grid. Honor a forced landscape; auto + portrait keep the
    // historical portrait default.
    return PosterLayout(
      cols: size,
      rows: size,
      landscape: opts.orientation == PosterOrientation.landscape,
      paper: opts.paper,
      overlapIn: opts.overlapIn,
    );
  }

  final aspect = imageAspect.isFinite && imageAspect > 0 ? imageAspect : 1.0;
  PosterLayout? best;
  var bestScore = double.infinity;

  double mismatch(double a, double b) => a > b ? a / b : b / a;

  for (final landscape in orientations) {
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
          overlapIn: opts.overlapIn,
        );
        final score = mismatch(cand.canvasAspect, aspect);
        // Primary: closest aspect. Tie-break: fewer pages, then the page
        // orientation that matches the image's orientation.
        final orientationMatch = (aspect >= 1) == landscape
            ? 0
            : 1; // 0 = matches
        final better =
            score < bestScore - 1e-9 ||
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

/// Overlap as a fraction of one page's printed content along an axis.
/// Clamped so a page can never overlap more than 45% of itself — beyond
/// that the "shingle" stops being a seam cushion and starts eating pages.
double posterOverlapFrac(double overlapIn, double contentIn) {
  if (overlapIn <= 0 || contentIn <= 0) return 0;
  return (overlapIn / contentIn).clamp(0.0, 0.45);
}

/// How many "page units" the assembled canvas spans along an axis when
/// [n] pages shingle with [ovFrac] of a page shared at every seam:
/// the first page contributes a full unit, each later one a step.
double posterAxisUnits(int n, double ovFrac) => 1 + (n - 1) * (1 - ovFrac);

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

/// For [PosterFit.fill] with repositioning: the source rect to show, given a
/// [zoom] (≥1, crops tighter) and a focal point [focusX]/[focusY] ∈ [0,1].
/// At zoom 1 + focus (0.5, 0.5) this equals [posterCoverCrop] (centered
/// cover). Panning slides the crop across the cover slack; zooming shrinks it
/// around the focal point. The result is always within the image — no clamp
/// needed — and exactly matches the preview's `Transform.scale` + cover-
/// alignment so what you drag is what prints.
(double, double, double, double) posterViewRect(
  double imgW,
  double imgH,
  double canvasAspect,
  double zoom,
  double focusX,
  double focusY,
) {
  final (_, _, cw, ch) = posterCoverCrop(imgW, imgH, canvasAspect);
  final z = zoom < 1 ? 1.0 : zoom;
  final fx = focusX.clamp(0.0, 1.0);
  final fy = focusY.clamp(0.0, 1.0);
  final vw = cw / z;
  final vh = ch / z;
  return (fx * (imgW - vw), fy * (imgH - vh), vw, vh);
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

/// Target print density. The assembled poster's long edge is capped per
/// [_maxCanvasLongPx] so a big grid degrades DPI gracefully instead of
/// allocating a huge bitmap.
const int _targetDpi = 150;

/// Max assembled long-edge px, by quality + fit. Fill is rendered tile-by-
/// tile (peak memory = source + one page), so it scales safely to a high
/// cap. Whole builds ONE full canvas before slicing, so it's held lower to
/// bound peak memory (a 6000-long canvas would be ~80 MB).
int _maxCanvasLongPx(PosterQuality quality, PosterFit fit) {
  if (quality == PosterQuality.standard) return 3600;
  return fit == PosterFit.whole ? 4200 : 6000;
}

/// The white border (inches) reserved on each page when assembly guides are
/// on — room for the dashed cut line + crop marks, and a safe trim margin
/// (most printers can't print the outer ~0.25"). After trimming on the
/// dashed line, the pages butt together seamlessly.
const double kGuideMarginIn = 0.35;

/// Encode one rendered tile per [quality] — lossless PNG, or JPEG at a
/// quality that tracks the level.
Uint8List _encodeTile(img.Image tile, PosterQuality quality) {
  if (quality == PosterQuality.lossless) {
    return Uint8List.fromList(img.encodePng(tile));
  }
  return Uint8List.fromList(
    img.encodeJpg(tile, quality: quality == PosterQuality.high ? 95 : 85),
  );
}

/// Per-page pixel dimensions for [layout] + the chosen print density, after
/// the long-edge cap [maxLongPx].
({int pageW, int pageH, double dpi}) _pagePixels(
  PosterLayout layout,
  int maxLongPx,
) {
  final longIn = math.max(layout.assembledWidthIn, layout.assembledHeightIn);
  final desiredLongPx = longIn * _targetDpi;
  final dpi = desiredLongPx > maxLongPx
      ? maxLongPx / longIn
      : _targetDpi.toDouble();
  return (
    pageW: (layout.pageWidthIn * dpi).round(),
    pageH: (layout.pageHeightIn * dpi).round(),
    dpi: dpi,
  );
}

/// Rotate [bytes] 90° clockwise (lossless decode → re-encode), off the UI
/// thread. The poster tool bakes rotation into the working image so pan /
/// zoom + the engine all operate in one "as-displayed" coordinate space.
Future<Uint8List> rotateImageQuarterTurn(Uint8List bytes) {
  if (kIsWeb) return Future.value(_rotateSync(bytes));
  return Isolate.run(() => _rotateSync(bytes));
}

Uint8List _rotateSync(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    // Throw rather than silently return the input unchanged, so the caller
    // can surface "Could not rotate" instead of a no-op tap.
    throw const FormatException('Could not decode the image to rotate.');
  }
  final rotated = img.copyRotate(decoded, angle: 90);
  return Uint8List.fromList(img.encodeJpg(rotated, quality: 95));
}

/// Decode [bytes] and tile per [layout] + [fit], returning the page images
/// (JPEG bytes, row-major: index `row * cols + col`). In [PosterFit.fill],
/// [zoom] / [focusX] / [focusY] reposition the crop (see [posterViewRect]).
/// Runs the CPU-heavy decode/resize/crop in an isolate (falls back to the
/// main thread on web, which has no isolates).
///
/// Throws [FormatException] if the bytes can't be decoded as an image.
Future<List<Uint8List>> renderPosterTiles(
  Uint8List bytes,
  PosterLayout layout,
  PosterFit fit, {
  bool guides = false,
  double zoom = 1,
  double focusX = 0.5,
  double focusY = 0.5,
  PosterQuality quality = PosterQuality.standard,
  void Function(int done, int total)? onProgress,
}) {
  final total = layout.pageCount;
  if (kIsWeb) {
    // No isolates on web — render on the main thread. We still drive the
    // progress callback so the caller's UI completes (it just can't animate
    // mid-decode, since the main thread is busy).
    onProgress?.call(0, total);
    final tiles = _renderPosterTilesSync(
      bytes,
      layout,
      fit,
      guides,
      zoom,
      focusX,
      focusY,
      quality,
      onTile: onProgress == null ? null : (done) => onProgress(done, total),
    );
    return Future.value(tiles);
  }
  if (onProgress == null) {
    // Fast path: a one-shot worker, no progress channel.
    return Isolate.run(
      () => _renderPosterTilesSync(
        bytes,
        layout,
        fit,
        guides,
        zoom,
        focusX,
        focusY,
        quality,
      ),
    );
  }
  // Progress path: a worker that streams the running page count back.
  return _renderTilesWithProgress(
    bytes,
    layout,
    fit,
    guides,
    zoom,
    focusX,
    focusY,
    quality,
    onProgress,
  );
}

// --- Progress-reporting render worker --------------------------------------
//
// `Isolate.run` is one-shot (no callback channel), so to report determinate
// per-page progress we spawn a worker that streams the running tile count over
// a port, then the finished tiles (or a failure). Every terminal path closes
// the port; an unexpected worker exit (e.g. OOM) is caught via `onExit` so the
// returned future can never hang.

class _PosterRenderRequest {
  const _PosterRenderRequest({
    required this.sendPort,
    required this.bytes,
    required this.layout,
    required this.fit,
    required this.guides,
    required this.zoom,
    required this.focusX,
    required this.focusY,
    required this.quality,
  });
  final SendPort sendPort;
  final Uint8List bytes;
  final PosterLayout layout;
  final PosterFit fit;
  final bool guides;
  final double zoom;
  final double focusX;
  final double focusY;
  final PosterQuality quality;
}

class _PosterRenderError {
  const _PosterRenderError(this.message);
  final String message;
}

/// The finished tiles, in a dedicated wrapper so the listener classifies the
/// terminal message by TYPE (never `is List`, which a stray list could spoof
/// and whose reified generic can be erased across the isolate boundary).
class _PosterRenderResult {
  const _PosterRenderResult(this.tiles);
  final List<Uint8List> tiles;
}

/// Worker entry — top-level so it's isolate-safe (no capture of instance
/// state). Streams `int` progress ticks, then a [_PosterRenderResult], or a
/// [_PosterRenderError] if the render throws.
void _renderWorker(_PosterRenderRequest req) {
  final port = req.sendPort;
  try {
    final tiles = _renderPosterTilesSync(
      req.bytes,
      req.layout,
      req.fit,
      req.guides,
      req.zoom,
      req.focusX,
      req.focusY,
      req.quality,
      onTile: port.send,
    );
    port.send(_PosterRenderResult(tiles));
  } on Object catch (e) {
    port.send(_PosterRenderError(e.toString()));
  }
}

Future<List<Uint8List>> _renderTilesWithProgress(
  Uint8List bytes,
  PosterLayout layout,
  PosterFit fit,
  bool guides,
  double zoom,
  double focusX,
  double focusY,
  PosterQuality quality,
  void Function(int done, int total) onProgress,
) async {
  final total = layout.pageCount;
  onProgress(0, total);
  final receive = ReceivePort();
  final completer = Completer<List<Uint8List>>();
  late final StreamSubscription<dynamic> sub;

  sub = receive.listen((message) {
    // Once settled, ignore everything — a late progress tick, or the `onExit`
    // null that always trails the success message. This makes receive.close()
    // run exactly once (on the first terminal message) and tolerates any
    // message arriving after we've resolved.
    if (completer.isCompleted) return;
    if (message is int) {
      // A progress tick (running page count) — not terminal; keep listening.
      onProgress(message, total);
      return;
    }
    if (message is _PosterRenderResult) {
      // Reconstruct a strongly-typed list defensively — the reified generic
      // can be erased crossing the isolate boundary.
      completer.complete(
        message.tiles.cast<Uint8List>().toList(growable: false),
      );
    } else if (message is _PosterRenderError) {
      completer.completeError(Exception(message.message));
    } else {
      // `onExit` fired (null) — or any unexpected message. If we reach here
      // unresolved, the worker died without a result; surface it rather than
      // hang the future forever.
      completer.completeError(
        Exception('The poster render stopped unexpectedly.'),
      );
    }
    receive.close();
  });

  try {
    await Isolate.spawn(
      _renderWorker,
      _PosterRenderRequest(
        sendPort: receive.sendPort,
        bytes: bytes,
        layout: layout,
        fit: fit,
        guides: guides,
        zoom: zoom,
        focusX: focusX,
        focusY: focusY,
        quality: quality,
      ),
      onExit: receive.sendPort,
      debugName: 'poster-render',
    );
  } on Object catch (e, st) {
    if (!completer.isCompleted) completer.completeError(e, st);
    receive.close();
  }

  try {
    return await completer.future;
  } finally {
    await sub.cancel();
  }
}

/// Synchronous tile render — the same work [renderPosterTiles] does, minus
/// the isolate hop. Exposed for tests so they stay deterministic (spawning
/// isolates under the full-suite runner is flaky); production goes through
/// [renderPosterTiles].
@visibleForTesting
List<Uint8List> renderPosterTilesForTest(
  Uint8List bytes,
  PosterLayout layout,
  PosterFit fit, {
  bool guides = false,
  double zoom = 1,
  double focusX = 0.5,
  double focusY = 0.5,
  PosterQuality quality = PosterQuality.standard,
}) => _renderPosterTilesSync(
  bytes,
  layout,
  fit,
  guides,
  zoom,
  focusX,
  focusY,
  quality,
);

/// Top-level (isolate-safe — no closure over instance state). [onTile] (when
/// given) is called with the running tile count after each page is encoded,
/// so a caller can report determinate progress.
List<Uint8List> _renderPosterTilesSync(
  Uint8List bytes,
  PosterLayout layout,
  PosterFit fit,
  bool guides,
  double zoom,
  double focusX,
  double focusY,
  PosterQuality quality, {
  void Function(int done)? onTile,
}) {
  final src = img.decodeImage(bytes);
  if (src == null) {
    throw const FormatException('Could not decode the chosen image.');
  }
  final px = _pagePixels(layout, _maxCanvasLongPx(quality, fit));
  // With guides on, the image only fills the trimmable area inside each
  // page's margin — so the tiles are smaller and the white border is added
  // in the PDF. The continuous image still spans the IMAGE areas, so after
  // trimming the margins the pages butt together seamlessly.
  final marginPx = guides ? (kGuideMarginIn * px.dpi).round() : 0;
  final pageW = math.max(1, px.pageW - 2 * marginPx);
  final pageH = math.max(1, px.pageH - 2 * marginPx);
  final cols = layout.cols;
  final rows = layout.rows;
  // Seam cushion: each page past the first advances by a step (one page
  // minus the shared strip), so every interior seam prints the same
  // [layout.overlapIn] inches of image on both adjacent pages. With guides
  // the printed content is inset by the trim margin, so the fraction is
  // taken of the CONTENT inches — the physical overlap stays true.
  final contentWIn = layout.pageWidthIn - (guides ? 2 * kGuideMarginIn : 0);
  final contentHIn = layout.pageHeightIn - (guides ? 2 * kGuideMarginIn : 0);
  final ovFx = posterOverlapFrac(layout.overlapIn, contentWIn);
  final ovFy = posterOverlapFrac(layout.overlapIn, contentHIn);
  final unitsX = posterAxisUnits(cols, ovFx);
  final unitsY = posterAxisUnits(rows, ovFy);
  final canvasAspect = (unitsX * pageW) / (unitsY * pageH);
  final tiles = <Uint8List>[];

  switch (fit) {
    case PosterFit.fill:
      // Cover, with optional reposition: crop the source to the chosen view
      // (zoom + focal point) at the canvas aspect, then slice each page
      // directly out of the (un-resized) source and resize only that tile.
      // Peak memory = source + one page (never the whole canvas at once).
      final (cl, ct, cw, ch) = posterViewRect(
        src.width.toDouble(),
        src.height.toDouble(),
        canvasAspect,
        zoom,
        focusX,
        focusY,
      );
      final unitW = cw / unitsX; // source px per page along x
      final unitH = ch / unitsY;
      for (var row = 0; row < rows; row++) {
        for (var col = 0; col < cols; col++) {
          final sx = (cl + col * (1 - ovFx) * unitW).round();
          final sy = (ct + row * (1 - ovFy) * unitH).round();
          final sw = math
              .min(unitW.round(), src.width - sx)
              .clamp(1, src.width);
          final sh = math
              .min(unitH.round(), src.height - sy)
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
          tiles.add(_encodeTile(tile, quality));
          onTile?.call(tiles.length);
        }
      }

    case PosterFit.whole:
      // Contain: place the whole image centered on a white canvas, then
      // slice. Builds the full canvas once (less common path). With a seam
      // cushion the canvas shrinks to the shingled span and consecutive
      // slices advance by a step, re-reading the shared strip.
      final canvasW = math.max(1, (pageW * unitsX).round());
      final canvasH = math.max(1, (pageH * unitsY).round());
      final canvas = _containOnWhite(src, canvasW, canvasH);
      for (var row = 0; row < rows; row++) {
        for (var col = 0; col < cols; col++) {
          final tile = img.copyCrop(
            canvas,
            x: (col * (1 - ovFx) * pageW).round().clamp(
              0,
              math.max(0, canvasW - pageW),
            ),
            y: (row * (1 - ovFy) * pageH).round().clamp(
              0,
              math.max(0, canvasH - pageH),
            ),
            width: pageW,
            height: pageH,
          );
          tiles.add(_encodeTile(tile, quality));
          onTile?.call(tiles.length);
        }
      }
  }
  return tiles;
}

// ---------------------------------------------------------------------------
// PDF assembly — off the UI thread.
// ---------------------------------------------------------------------------

/// Build the multi-page PDF from rendered [tiles] (row-major, length
/// `layout.pageCount`). Without [guides], each tile fills one full-bleed page
/// so adjacent pages abut. With [guides], each tile is inset by a white trim
/// margin carrying a dashed cut line + corner crop marks, and an "Assembly
/// map" page is appended. When [labels] is on, a faint "R1·C2" chip is
/// printed in each page's corner.
///
/// Runs in an isolate: binding a 36-tile lossless document takes seconds,
/// and on the main isolate it froze the whole UI — the working banner's
/// spinner included — right after the progress bar filled, which read as
/// "the app is hanging" (the exact moment users would kill it).
Future<Uint8List> buildPosterPdf({
  required List<Uint8List> tiles,
  required PosterLayout layout,
  bool labels = true,
  bool guides = false,
  String title = 'Poster',
}) {
  return Isolate.run(
    () => _buildPosterPdfBody(
      tiles: tiles,
      layout: layout,
      labels: labels,
      guides: guides,
      title: title,
    ),
  );
}

Future<Uint8List> _buildPosterPdfBody({
  required List<Uint8List> tiles,
  required PosterLayout layout,
  required bool labels,
  required bool guides,
  required String title,
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

/// One-shot: render [bytes] per [layout] + [fit] (+ optional reposition) and
/// assemble the PDF.
Future<Uint8List> renderPosterPdf(
  Uint8List bytes,
  PosterLayout layout,
  PosterFit fit, {
  bool labels = true,
  String title = 'Poster',
  bool guides = false,
  double zoom = 1,
  double focusX = 0.5,
  double focusY = 0.5,
  PosterQuality quality = PosterQuality.standard,
  void Function(int done, int total)? onProgress,
}) async {
  final tiles = await renderPosterTiles(
    bytes,
    layout,
    fit,
    guides: guides,
    zoom: zoom,
    focusX: focusX,
    focusY: focusY,
    quality: quality,
    onProgress: onProgress,
  );
  return buildPosterPdf(
    tiles: tiles,
    layout: layout,
    labels: labels,
    guides: guides,
    title: title,
  );
}

// ---------------------------------------------------------------------------
// Single-image (PNG) export — the whole assembled poster as ONE continuous
// image rather than paged tiles. For saving the image to a computer / sending
// to a print shop, or printing on one large sheet. Same framing as the tiled
// output; no guide margins (those are a per-page tape aid).
// ---------------------------------------------------------------------------

/// Render the whole assembled poster as a single PNG. Runs off the UI thread
/// (isolate on mobile/desktop, main thread on web). Throws [FormatException]
/// if the bytes can't be decoded.
Future<Uint8List> renderPosterImagePng(
  Uint8List bytes,
  PosterLayout layout,
  PosterFit fit, {
  double zoom = 1,
  double focusX = 0.5,
  double focusY = 0.5,
  PosterQuality quality = PosterQuality.standard,
}) {
  if (kIsWeb) {
    return Future.value(
      _renderPosterImageSync(bytes, layout, fit, zoom, focusX, focusY, quality),
    );
  }
  return Isolate.run(
    () => _renderPosterImageSync(
      bytes,
      layout,
      fit,
      zoom,
      focusX,
      focusY,
      quality,
    ),
  );
}

/// Synchronous single-image render — exposed for deterministic tests (see
/// [renderPosterTilesForTest] for why production avoids isolates under test).
@visibleForTesting
Uint8List renderPosterImagePngForTest(
  Uint8List bytes,
  PosterLayout layout,
  PosterFit fit, {
  double zoom = 1,
  double focusX = 0.5,
  double focusY = 0.5,
  PosterQuality quality = PosterQuality.standard,
}) => _renderPosterImageSync(bytes, layout, fit, zoom, focusX, focusY, quality);

/// Top-level (isolate-safe). Builds the assembled canvas (cols·pageW ×
/// rows·pageH) at the print-density cap, places the source per [fit], and
/// encodes ONE PNG.
Uint8List _renderPosterImageSync(
  Uint8List bytes,
  PosterLayout layout,
  PosterFit fit,
  double zoom,
  double focusX,
  double focusY,
  PosterQuality quality,
) {
  final src = img.decodeImage(bytes);
  if (src == null) {
    throw const FormatException('Could not decode the chosen image.');
  }
  final px = _pagePixels(layout, _maxCanvasLongPx(quality, fit));
  // One seamless image has no seams to cushion — but with overlap on, the
  // assembled (shingled) poster spans fewer page-units, so the single PNG
  // matches that span (and the tiled pages' framing).
  final unitsX = posterAxisUnits(
    layout.cols,
    posterOverlapFrac(layout.overlapIn, layout.pageWidthIn),
  );
  final unitsY = posterAxisUnits(
    layout.rows,
    posterOverlapFrac(layout.overlapIn, layout.pageHeightIn),
  );
  final canvasW = math.max(1, (px.pageW * unitsX).round());
  final canvasH = math.max(1, (px.pageH * unitsY).round());

  final img.Image out;
  switch (fit) {
    case PosterFit.fill:
      final (cl, ct, cw, ch) = posterViewRect(
        src.width.toDouble(),
        src.height.toDouble(),
        canvasW / canvasH,
        zoom,
        focusX,
        focusY,
      );
      final x = cl.round().clamp(0, src.width - 1);
      final y = ct.round().clamp(0, src.height - 1);
      final w = math.min(cw.round(), src.width - x).clamp(1, src.width);
      final h = math.min(ch.round(), src.height - y).clamp(1, src.height);
      final crop = img.copyCrop(src, x: x, y: y, width: w, height: h);
      out = img.copyResize(
        crop,
        width: canvasW,
        height: canvasH,
        interpolation: img.Interpolation.average,
      );
    case PosterFit.whole:
      out = _containOnWhite(src, canvasW, canvasH);
  }
  return Uint8List.fromList(img.encodePng(out));
}

/// Compose [src] contained + centered on a white `canvasW × canvasH` canvas
/// (the PosterFit.whole path, shared by the tile slicer and the preview
/// renderer).
img.Image _containOnWhite(img.Image src, int canvasW, int canvasH) {
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
  return canvas;
}
