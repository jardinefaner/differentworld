import 'dart:async';
import 'dart:ui' as ui;

import 'package:differentworld/features/poster/poster_engine.dart';
import 'package:differentworld/features/poster/poster_models.dart';
import 'package:differentworld/features/poster/poster_prefs.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:differentworld/shared/widgets/primary_action_button.dart';
import 'package:differentworld/shared/widgets/secondary_action_button.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';

/// `/poster` — the Poster tool. Pick one image, choose a size, and it slices
/// the image across several pages you print and tape together into one big
/// image (a kid's drawing blown up, a welcome banner, a giant map). The grid
/// auto-fits the image's shape (a wide banner tiles wide, a tall portrait
/// tiles tall) so the least gets cropped / wasted. The heavy slicing runs in
/// an isolate; the output is a multi-page PDF handed to the OS print / share
/// sheet.
class PosterScreen extends ConsumerStatefulWidget {
  const PosterScreen({super.key});

  @override
  ConsumerState<PosterScreen> createState() => _PosterScreenState();
}

class _PosterScreenState extends ConsumerState<PosterScreen> {
  Uint8List? _bytes;
  // Aspect of the WORKING image (rotation is baked into the bytes, so this is
  // always "as displayed").
  double _imageAspect = 1;
  // Fill-mode reposition (per image; not persisted). 0.5/0.5 = centered,
  // zoom 1 = the full cover crop.
  double _zoom = 1;
  double _focusX = 0.5;
  double _focusY = 0.5;
  PosterOptions _opts = const PosterOptions();
  bool _working = false;
  bool _lastShare = false; // whether the last output attempt was Share vs Print
  String? _error;

  @override
  void initState() {
    super.initState();
    // Restore the teacher's last size / fit / paper / labels choices.
    unawaited(PosterPrefs.load().then((saved) {
      if (mounted) setState(() => _opts = saved);
    }));
  }

  /// The concrete page grid for the current image + options.
  PosterLayout get _layout => computePosterLayout(_opts, _imageAspect);

  bool get _repositioned => _zoom != 1 || _focusX != 0.5 || _focusY != 0.5;

  /// Mutate options + persist so they come back next session.
  void _update(PosterOptions next) {
    setState(() => _opts = next);
    unawaited(PosterPrefs.save(next));
  }

  void _resetCrop() => setState(() {
        _zoom = 1;
        _focusX = 0.5;
        _focusY = 0.5;
      });

  /// Rotate the working image 90° — baked into the bytes (off-thread) so pan /
  /// zoom + the engine all share one "as-displayed" coordinate space.
  Future<void> _rotate() async {
    final bytes = _bytes;
    if (bytes == null || _working) return;
    setState(() => _working = true);
    try {
      final rotated = await rotateImageQuarterTurn(bytes);
      final aspect = await _decodeAspect(rotated);
      if (!mounted) return;
      setState(() {
        _bytes = rotated;
        _imageAspect = aspect;
        _zoom = 1;
        _focusX = 0.5;
        _focusY = 0.5;
      });
    } on Object {
      if (!mounted) return;
      setState(() => _error = 'Could not rotate the image.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  /// Read just the image's pixel dimensions (header decode — no full
  /// rasterize) so the grid can fit the image's shape.
  Future<double> _decodeAspect(Uint8List bytes) async {
    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final w = descriptor.width;
      final h = descriptor.height;
      descriptor.dispose();
      buffer.dispose();
      return h <= 0 ? 1.0 : w / h;
    } on Object {
      return 1; // fall back to square framing if the header won't decode
    }
  }

  Future<void> _pick(ImageSource source) async {
    // Don't start a pick while a rotate / render is in flight — its later
    // setState could otherwise clobber the freshly-picked bytes. (The Replace
    // entry points are already gated on `_working`; this is belt-and-braces.)
    if (_working) return;
    try {
      // Cap the longest edge at 6000 px — enough to feed High / Lossless
      // quality (their canvas tops out at 6000 px), while still bounding
      // memory + render time. The preview decodes downsized (see
      // `cacheWidth`), so a bigger source doesn't cost preview memory; the
      // full decode only happens per-tile in the render isolate. The picker
      // downsamples natively at decode time.
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 6000,
        maxHeight: 6000,
        requestFullMetadata: false,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final aspect = await _decodeAspect(bytes);
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _imageAspect = aspect;
        _zoom = 1; // fresh image — clear any prior reposition
        _focusX = 0.5;
        _focusY = 0.5;
        _error = null;
      });
    } on Object {
      if (!mounted) return;
      setState(() => _error = 'Could not open that image.');
    }
  }

  Future<void> _showSourceSheet() {
    return showGlassSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                unawaited(_pick(ImageSource.gallery));
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                unawaited(_pick(ImageSource.camera));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _output({required bool share}) async {
    final bytes = _bytes;
    if (bytes == null || _working) return;
    setState(() {
      _working = true;
      _lastShare = share;
      _error = null;
    });
    final layout = _layout;
    final tag = '${layout.cols}×${layout.rows}';
    try {
      final pdf = await renderPosterPdf(
        bytes,
        layout,
        _opts.fit,
        labels: _opts.labels,
        title: 'Poster $tag',
        guides: _opts.guides,
        zoom: _zoom,
        focusX: _focusX,
        focusY: _focusY,
        quality: _opts.quality,
      );
      if (!mounted) return;
      if (share) {
        await Printing.sharePdf(
          bytes: pdf,
          filename: 'poster-${layout.cols}x${layout.rows}.pdf',
        );
      } else {
        await Printing.layoutPdf(
          onLayout: (_) => pdf,
          name: 'Poster $tag',
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            share
                ? 'Poster shared — ${layout.pageCount} pages.'
                : 'Sent to print — ${layout.pageCount} pages. Tape them together!',
          ),
        ),
      );
    } on Object catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'poster'),
      );
      if (!mounted) return;
      setState(
        () => _error =
            "Couldn't build the poster. Try a smaller grid or another image.",
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _bytes != null;
    return EdgeScaffold(
      actions: [
        if (hasImage)
          SecondaryActionButton(
            tooltip: 'Share PDF',
            icon: Icons.ios_share,
            onPressed: _working ? null : () => _output(share: true),
          ),
        PrimaryActionButton(
          tooltip: 'Print',
          icon: Icons.print_outlined,
          onPressed: (hasImage && !_working) ? () => _output(share: false) : null,
        ),
      ],
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                const ContentHeader(
                  title: 'Poster',
                  subtitle: 'Blow up an image across printed pages you tape '
                      'together',
                ),
                if (_working)
                  const _WorkingBanner(key: ValueKey('poster-working')),
                if (_error != null)
                  _ErrorBanner(
                    key: const ValueKey('poster-error'),
                    message: _error!,
                    // Retry the SAME action that failed (Print vs Share), and
                    // only when there's an image to retry with.
                    onRetry: (_bytes != null && !_working)
                        ? () => _output(share: _lastShare)
                        : null,
                  ),
                if (!hasImage)
                  _Chooser(key: const ValueKey('poster-chooser'), onPick: _pick)
                else
                  Column(
                    key: const ValueKey('poster-editor'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _editor(context),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _editor(BuildContext context) {
    final theme = Theme.of(context);
    final layout = _layout;
    final caption = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return [
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340, maxHeight: 460),
          child: AspectRatio(
            aspectRatio: layout.canvasAspect,
            child: _PosterPreview(
              bytes: _bytes!,
              layout: layout,
              fit: _opts.fit,
              labels: _opts.labels,
              zoom: _zoom,
              focusX: _focusX,
              focusY: _focusY,
              onReposition: (z, fx, fy) => setState(() {
                _zoom = z;
                _focusX = fx;
                _focusY = fy;
              }),
            ),
          ),
        ),
      ),
      if (_opts.fit == PosterFit.fill) ...[
        const SizedBox(height: 6),
        Center(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 2,
            children: [
              Text('Drag to reposition · pinch to zoom', style: caption),
              if (_repositioned)
                TextButton(
                  onPressed: _resetCrop,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('Reset'),
                ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 8),
      Center(
        child: Text(
          'Prints as ${layout.cols}×${layout.rows} '
          '${layout.landscape ? 'landscape' : 'portrait'} · ${layout.pageCount} '
          '${_paperName(layout.paper)} page${layout.pageCount == 1 ? '' : 's'} · '
          'about ${_assembledSize(layout)} assembled\n'
          'Print all ${layout.pageCount}, line them up, and tape them together.'
          '${_opts.guides ? '\nIncludes trim guides + an assembly map page.' : ''}',
          textAlign: TextAlign.center,
          style: caption,
        ),
      ),
      const SizedBox(height: 20),
      _label(context, 'Size'),
      const SizedBox(height: 6),
      Align(
        alignment: Alignment.centerLeft,
        child: SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 2, label: Text('2')),
            ButtonSegment(value: 3, label: Text('3')),
            ButtonSegment(value: 4, label: Text('4')),
            ButtonSegment(value: 5, label: Text('5')),
          ],
          selected: {_opts.size},
          onSelectionChanged: (s) => _update(_opts.copyWith(size: s.first)),
        ),
      ),
      const SizedBox(height: 4),
      Text('Pages along the poster’s longest edge.', style: caption),
      const SizedBox(height: 4),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Fit to image shape'),
        subtitle: const Text(
          'Auto-pick the grid + page orientation so a wide or tall image '
          'isn’t cropped hard or printed with big margins',
        ),
        value: _opts.fitShape,
        onChanged: (v) => _update(_opts.copyWith(fitShape: v)),
      ),
      const SizedBox(height: 8),
      _label(context, 'Fit'),
      const SizedBox(height: 6),
      Align(
        alignment: Alignment.centerLeft,
        child: SegmentedButton<PosterFit>(
          segments: const [
            ButtonSegment(
              value: PosterFit.fill,
              label: Text('Edge to edge'),
              icon: Icon(Icons.crop_free),
            ),
            ButtonSegment(
              value: PosterFit.whole,
              label: Text('Whole image'),
              icon: Icon(Icons.fit_screen_outlined),
            ),
          ],
          selected: {_opts.fit},
          onSelectionChanged: (s) => _update(_opts.copyWith(fit: s.first)),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        _opts.fit == PosterFit.fill
            ? 'Fills every page — crops the edges that don’t fit.'
            : 'Shows the whole image — thin white margins where it doesn’t fit.',
        style: caption,
      ),
      const SizedBox(height: 16),
      Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          // PageStorageKey keeps the expanded/collapsed state across the many
          // rebuilds this screen does (every control change, every drag frame).
          key: const PageStorageKey('poster-print-options'),
          title: const Text('Print options'),
          subtitle: Text(_printOptionsSummary(), style: caption),
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(context, 'Paper'),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<PosterPaper>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: PosterPaper.letter,
                    label: Text('Letter'),
                  ),
                  ButtonSegment(value: PosterPaper.a4, label: Text('A4')),
                ],
                selected: {_opts.paper},
                onSelectionChanged: (s) =>
                    _update(_opts.copyWith(paper: s.first)),
              ),
            ),
            const SizedBox(height: 16),
            _label(context, 'Print quality'),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<PosterQuality>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: PosterQuality.standard,
                    label: Text('Standard'),
                  ),
                  ButtonSegment(value: PosterQuality.high, label: Text('High')),
                  ButtonSegment(
                    value: PosterQuality.lossless,
                    label: Text('Lossless'),
                  ),
                ],
                selected: {_opts.quality},
                onSelectionChanged: (s) =>
                    _update(_opts.copyWith(quality: s.first)),
              ),
            ),
            const SizedBox(height: 4),
            Text(_qualityHint(_opts.quality), style: caption),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Corner labels'),
              subtitle: const Text(
                'Print a small row/column tag in each page corner so you know '
                'how to line them up',
              ),
              value: _opts.labels,
              onChanged: (v) => _update(_opts.copyWith(labels: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Assembly guides'),
              subtitle: const Text(
                'Add a trim border with a dashed cut line + crop marks so '
                'seams line up, plus a map page showing where each page goes',
              ),
              value: _opts.guides,
              onChanged: (v) => _update(_opts.copyWith(guides: v)),
            ),
          ],
        ),
      ),
      const SizedBox(height: 4),
      Row(
        children: [
          TextButton.icon(
            onPressed: _working ? null : _rotate,
            icon: const Icon(Icons.rotate_90_degrees_cw_outlined),
            label: const Text('Rotate'),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _working ? null : _showSourceSheet,
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Replace'),
          ),
        ],
      ),
    ];
  }

  String _qualityHint(PosterQuality q) => switch (q) {
        PosterQuality.standard =>
          'Smaller files, quick — good for most photos.',
        PosterQuality.high =>
          'Sharper on big grids. Larger files, slower to build.',
        PosterQuality.lossless =>
          'Crispest for drawings, line art & text — but the largest files.',
      };

  String _qualityLabel(PosterQuality q) => switch (q) {
        PosterQuality.standard => 'Standard',
        PosterQuality.high => 'High',
        PosterQuality.lossless => 'Lossless',
      };

  /// Live one-line summary of the collapsed "Print options" group.
  String _printOptionsSummary() {
    final parts = <String>[
      if (_opts.paper == PosterPaper.a4) 'A4' else 'Letter',
      _qualityLabel(_opts.quality),
      if (_opts.labels) 'labels',
      if (_opts.guides) 'guides',
    ];
    return parts.join(' · ');
  }

  String _paperName(PosterPaper p) => p == PosterPaper.a4 ? 'A4' : 'letter';

  String _assembledSize(PosterLayout l) {
    if (l.paper == PosterPaper.a4) {
      final w = (l.assembledWidthIn * 2.54).round();
      final h = (l.assembledHeightIn * 2.54).round();
      return '$w × $h cm';
    }
    return '${_inches(l.assembledWidthIn)}″ × ${_inches(l.assembledHeightIn)}″';
  }

  Widget _label(BuildContext context, String text) => Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.w600),
      );
}

String _inches(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

/// The empty state: pick a source to start.
class _Chooser extends StatelessWidget {
  const _Chooser({required this.onPick, super.key});

  final Future<void> Function(ImageSource) onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          Icon(
            Icons.grid_view_rounded,
            size: 56,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Make something big',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Pick an image and we’ll split it across several printed pages. '
            'Print them and tape them into one big poster.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => onPick(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Choose from gallery'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => onPick(ImageSource.camera),
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Take a photo'),
          ),
        ],
      ),
    );
  }
}

/// WYSIWYG preview: the image framed exactly as it'll print, with the page
/// cut-lines (and corner labels, if on) overlaid so you see what lands where.
/// In Fill mode it's interactive — drag to pan the crop, pinch to zoom — and
/// the framing (`Transform.scale` + cover alignment) mirrors the engine's
/// [posterViewRect] one-to-one, so what you set is what prints.
class _PosterPreview extends StatefulWidget {
  const _PosterPreview({
    required this.bytes,
    required this.layout,
    required this.fit,
    required this.labels,
    required this.zoom,
    required this.focusX,
    required this.focusY,
    required this.onReposition,
  });

  final Uint8List bytes;
  final PosterLayout layout;
  final PosterFit fit;
  final bool labels;
  final double zoom;
  final double focusX;
  final double focusY;
  final void Function(double zoom, double focusX, double focusY) onReposition;

  @override
  State<_PosterPreview> createState() => _PosterPreviewState();
}

class _PosterPreviewState extends State<_PosterPreview> {
  double _startZoom = 1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFill = widget.fit == PosterFit.fill;
    // Focal point as a cover alignment (-1..1). At zoom 1 this pans the crop
    // across the cover slack; scaling around the same point zooms in.
    final align = Alignment(widget.focusX * 2 - 1, widget.focusY * 2 - 1);

    final framed = Semantics(
      label: 'Poster preview — ${widget.layout.cols} by ${widget.layout.rows} '
          'pages, ${isFill ? 'edge to edge' : 'whole image'}. The lines show '
          'where the pages divide.',
      image: true,
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ColoredBox(
            color: isFill
                ? theme.colorScheme.surfaceContainerHighest
                : Colors.white,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (isFill)
                  Transform.scale(
                    scale: widget.zoom,
                    alignment: align,
                    child: Image.memory(
                      widget.bytes,
                      fit: BoxFit.cover,
                      alignment: align,
                      gaplessPlayback: true,
                      // Decode at preview size, not full source res — keeps
                      // the preview cheap even for a 6000 px source.
                      cacheWidth: 1280,
                    ),
                  )
                else
                  Image.memory(
                    widget.bytes,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    cacheWidth: 1280,
                  ),
                CustomPaint(
                  painter: _GridPainter(
                    cols: widget.layout.cols,
                    rows: widget.layout.rows,
                    labels: widget.labels,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!isFill) return framed;

    return LayoutBuilder(
      builder: (context, constraints) {
        final boxW = constraints.maxWidth;
        final boxH = constraints.maxHeight;
        return GestureDetector(
          onScaleStart: (_) => _startZoom = widget.zoom,
          onScaleUpdate: (details) {
            final z = (_startZoom * details.scale).clamp(1.0, 5.0);
            // Drag right reveals the left of the image → focus moves left.
            // Divide by zoom so a given finger move pans the same on-screen
            // distance at every zoom (the visible crop shrinks as you zoom in).
            final fx = (widget.focusX -
                    details.focalPointDelta.dx / boxW / widget.zoom)
                .clamp(0.0, 1.0);
            final fy = (widget.focusY -
                    details.focalPointDelta.dy / boxH / widget.zoom)
                .clamp(0.0, 1.0);
            widget.onReposition(z, fx, fy);
          },
          child: framed,
        );
      },
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({required this.cols, required this.rows, required this.labels});

  final int cols;
  final int rows;
  final bool labels;

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / cols;
    final cellH = size.height / rows;
    final under = Paint()
      ..color = Colors.black26
      ..strokeWidth = 3;
    final line = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5;

    for (var c = 1; c < cols; c++) {
      final x = cellW * c;
      canvas
        ..drawLine(Offset(x, 0), Offset(x, size.height), under)
        ..drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (var r = 1; r < rows; r++) {
      final y = cellH * r;
      canvas
        ..drawLine(Offset(0, y), Offset(size.width, y), under)
        ..drawLine(Offset(0, y), Offset(size.width, y), line);
    }

    if (labels) {
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          final tp = TextPainter(
            text: TextSpan(
              text: 'R${r + 1}·C${c + 1}',
              style: const TextStyle(
                fontSize: 9,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          final dx = c * cellW + cellW - tp.width - 6;
          final dy = r * cellH + cellH - tp.height - 6;
          final chip = RRect.fromRectAndRadius(
            Rect.fromLTWH(dx - 3, dy - 2, tp.width + 6, tp.height + 4),
            const Radius.circular(3),
          );
          canvas.drawRRect(chip, Paint()..color = Colors.white70);
          tp.paint(canvas, Offset(dx, dy));
        }
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.cols != cols || old.rows != rows || old.labels != labels;
}

class _WorkingBanner extends StatelessWidget {
  const _WorkingBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text('Building your poster…', style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, this.onRetry, super.key});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.fromLTRB(12, 12, 12, onRetry != null ? 4 : 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline,
                color: theme.colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
          if (onRetry != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
            ),
        ],
      ),
    );
  }
}
