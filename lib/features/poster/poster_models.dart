/// Poster print options — how a single image is tiled across multiple
/// pages so it can be printed and taped into one big image.
library;

/// How the source image is mapped onto the assembled poster grid.
enum PosterFit {
  /// Fill every page edge-to-edge, cropping the overflow. No white margins —
  /// the assembled poster is solid image, but anything outside the page grid
  /// is cut off. Opt-in (use when you specifically want a borderless photo).
  fill,

  /// Fit the *whole* image; add thin white margins on the axis whose aspect
  /// doesn't match the grid. **Nothing is cropped — the default**, so a
  /// drawing / map / banner prints complete out of the box.
  whole,
}

/// Paper stock the poster tiles onto.
enum PosterPaper {
  /// US Letter — 8.5 × 11 in.
  letter,

  /// ISO A4 — 210 × 297 mm (8.27 × 11.69 in).
  a4,
}

/// How each printed page is turned — overrides the auto-pick.
enum PosterOrientation {
  /// Let the grid search choose per the image's shape (the default — a wide
  /// image lands on landscape pages, a tall one on portrait).
  auto,

  /// Force every page portrait (tall), whatever the image's shape.
  portrait,

  /// Force every page landscape (wide), whatever the image's shape.
  landscape,
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

/// How the printed pages become one poster — the physical step after the
/// printer stops. Each mode changes what's printed on the page, so the
/// paper matches the method.
enum PosterAssembly {
  /// Edge-to-edge printing, taped from behind. Nothing to cut, but a home
  /// printer's unprintable border eats a sliver of every page.
  tape,

  /// Every page prints inside a white border with a dashed cut line. Trim
  /// on the line, butt the pages, tape. Seamless — but only as straight as
  /// your scissors.
  trim,

  /// Same white border, but the line is a FOLD line, printed only on the
  /// edges that lie ON TOP of a neighbour (left + top). Crease the margin
  /// behind the page and lay it over the next one. No cutting, re-doable
  /// if the crease is off, and with a seam cushion the position is free.
  fold,

  /// No cutting and no folding: butt the printed pages edge to edge and
  /// the white borders become deliberate gutters, like split-canvas wall
  /// art. Zero precision required.
  panels
  ;

  /// True for every mode that prints the image inside a white border.
  bool get insetsPages => this != PosterAssembly.tape;
}

/// One poster job's configuration. The concrete page grid (columns ×
/// rows + page orientation) is *derived* from this plus the image's
/// aspect ratio — see `computePosterLayout` in poster_engine.dart.
class PosterOptions {
  const PosterOptions({
    this.size = 2,
    this.fitShape = true,
    this.orientation = PosterOrientation.auto,
    // Default to keeping the WHOLE image — cropping (fill) is destructive and
    // surprised a user into a wasted print. Opt into fill explicitly.
    this.fit = PosterFit.whole,
    this.paper = PosterPaper.letter,
    this.quality = PosterQuality.standard,
    this.labels = true,
    this.customCols = 0,
    this.customRows = 0,
    this.overlapIn = 0,
    this.marks = true,
    this.assembly = PosterAssembly.tape,
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

  /// Page turn. [PosterOrientation.auto] keeps the shape-fitting behavior;
  /// portrait / landscape force every page that way (the grid search is then
  /// constrained to the forced orientation when [fitShape] is on).
  final PosterOrientation orientation;

  /// Cover vs contain.
  final PosterFit fit;

  /// Letter vs A4.
  final PosterPaper paper;

  /// Standard / High / Lossless.
  final PosterQuality quality;

  /// Print a faint "R1·C2" registration label in each page's corner so
  /// the assembly order is obvious when you lay the pages out.
  final bool labels;

  /// Explicit grid override — pages wide × pages tall (each 1-6). When BOTH
  /// are > 0 the grid is exactly this (3×3, 1×4 banners, …) and [size] /
  /// [fitShape] are ignored. 0 = auto (the derived grid above). Zero (not
  /// null) so copyWith round-trips without sentinel gymnastics.
  final int customCols;
  final int customRows;

  bool get hasCustomGrid => customCols > 0 && customRows > 0;

  /// Seam cushion, in inches (0 / 0.25 / 0.5). When > 0, every interior
  /// seam prints the SAME strip of image on both adjacent pages, so the
  /// pages shingle: cut anywhere inside the shared strip — or skip cutting
  /// and lay one page over its neighbor — and an uneven cut costs nothing.
  final double overlapIn;

  /// Alignment marks: small ticks printed on both sides of every interior
  /// seam that meet into a continuous line when the pages are lined up —
  /// plus, with a seam cushion, a dashed line showing exactly where the
  /// next page's edge lands (hidden once the pages overlap).
  final bool marks;

  /// How the pages get joined — see [PosterAssembly]. Governs the printed
  /// border, the line style, and the instructions.
  final PosterAssembly assembly;

  /// Every mode except [PosterAssembly.tape] prints the image inside a
  /// white border (the trim / fold margin, and the printer's own safe
  /// area).
  bool get insetPages => assembly.insetsPages;

  /// The cushion actually applied. Panels BUTT rather than shingle, so a
  /// cushion there would duplicate a strip AND leave a gutter — wrong on
  /// both counts. Every other mode honours the pick.
  double get effectiveOverlapIn =>
      assembly == PosterAssembly.panels ? 0 : overlapIn;

  /// Alignment marks only mean something where two pages MEET over the
  /// image. Panels register on the page edges themselves, so marks there
  /// would just be stray ink inside a gutter-framed panel.
  bool get effectiveMarks => marks && assembly != PosterAssembly.panels;

  PosterOptions copyWith({
    int? size,
    bool? fitShape,
    PosterOrientation? orientation,
    PosterFit? fit,
    PosterPaper? paper,
    PosterQuality? quality,
    bool? labels,
    int? customCols,
    int? customRows,
    double? overlapIn,
    bool? marks,
    PosterAssembly? assembly,
  }) => PosterOptions(
    size: size ?? this.size,
    fitShape: fitShape ?? this.fitShape,
    orientation: orientation ?? this.orientation,
    fit: fit ?? this.fit,
    paper: paper ?? this.paper,
    quality: quality ?? this.quality,
    labels: labels ?? this.labels,
    customCols: customCols ?? this.customCols,
    customRows: customRows ?? this.customRows,
    overlapIn: overlapIn ?? this.overlapIn,
    marks: marks ?? this.marks,
    assembly: assembly ?? this.assembly,
  );
}
