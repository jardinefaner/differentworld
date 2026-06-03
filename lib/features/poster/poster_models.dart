/// Poster print options — how a single image is tiled across multiple
/// pages so it can be printed and taped into one big image.
library;

/// How the source image is mapped onto the assembled poster grid.
enum PosterFit {
  /// Fill every page edge-to-edge, cropping the overflow. No white
  /// margins — the assembled poster is solid image. The default.
  fill,

  /// Fit the *whole* image; add thin white margins on the axis whose
  /// aspect doesn't match the grid. Nothing is cropped.
  whole,
}

/// Paper stock the poster tiles onto.
enum PosterPaper {
  /// US Letter — 8.5 × 11 in.
  letter,

  /// ISO A4 — 210 × 297 mm (8.27 × 11.69 in).
  a4,
}

/// Print quality — trades file size + render time for sharpness.
enum PosterQuality {
  /// JPEG, modest resolution cap. Fast, small files. The default.
  standard,

  /// JPEG at higher quality + a higher resolution cap — sharper on big
  /// grids (where Standard goes soft). Bigger, slower.
  high,

  /// Lossless PNG tiles — no JPEG artifacts, razor-crisp edges. Best for
  /// drawings, line art, logos, and text. Largest files / slowest.
  lossless,
}

/// One poster job's configuration. The concrete page grid (columns ×
/// rows + page orientation) is *derived* from this plus the image's
/// aspect ratio — see `computePosterLayout` in poster_engine.dart.
class PosterOptions {
  const PosterOptions({
    this.size = 2,
    this.fitShape = true,
    this.fit = PosterFit.fill,
    this.paper = PosterPaper.letter,
    this.quality = PosterQuality.standard,
    this.labels = true,
    this.guides = false,
  });

  /// How big — the number of pages along the poster's *longest* edge
  /// (2 → up to 2 pages, 3 → up to 3, …). The minor edge is chosen to
  /// match the image when [fitShape] is on.
  final int size;

  /// When true, the grid (columns × rows) and page orientation are
  /// auto-chosen to match the image's shape — so a wide banner or a
  /// tall portrait tiles with the least cropping / wasted paper. When
  /// false, the poster is a plain square [size]×[size] of portrait
  /// pages.
  final bool fitShape;

  /// Cover vs contain.
  final PosterFit fit;

  /// Letter vs A4.
  final PosterPaper paper;

  /// Standard / High / Lossless.
  final PosterQuality quality;

  /// Print a faint "R1·C2" registration label in each page's corner so
  /// the assembly order is obvious when you lay the pages out.
  final bool labels;

  /// Add a white trim border with a dashed cut line + corner crop marks on
  /// every page, plus an "Assembly map" index page — so the seams line up
  /// cleanly when you trim and tape. Off by default (the simple full-bleed
  /// path).
  final bool guides;

  PosterOptions copyWith({
    int? size,
    bool? fitShape,
    PosterFit? fit,
    PosterPaper? paper,
    PosterQuality? quality,
    bool? labels,
    bool? guides,
  }) =>
      PosterOptions(
        size: size ?? this.size,
        fitShape: fitShape ?? this.fitShape,
        fit: fit ?? this.fit,
        paper: paper ?? this.paper,
        quality: quality ?? this.quality,
        labels: labels ?? this.labels,
        guides: guides ?? this.guides,
      );
}
