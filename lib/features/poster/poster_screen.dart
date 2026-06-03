import 'dart:async';
import 'dart:ui' as ui;

import 'package:differentworld/features/poster/poster_engine.dart';
import 'package:differentworld/features/poster/poster_models.dart';
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
  double _imageAspect = 1; // width / height of the picked image
  PosterOptions _opts = const PosterOptions();
  bool _working = false;
  String? _error;

  /// The concrete page grid for the current image + options.
  PosterLayout get _layout => computePosterLayout(_opts, _imageAspect);

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
    try {
      // Cap the longest edge at 4096 px. That's still far more detail than
      // the poster needs (the assembled canvas tops out at 3600 px, so a
      // bigger source is never fully used) and it bounds memory + render
      // time — critical on web, which has no isolate and renders on the
      // main thread. The picker downsamples natively at decode time.
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 4096,
        maxHeight: 4096,
        requestFullMetadata: false,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final aspect = await _decodeAspect(bytes);
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _imageAspect = aspect;
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
                if (_working) const _WorkingBanner(),
                if (_error != null)
                  _ErrorBanner(
                    message: _error!,
                    // Only offer retry when there's an image to retry with.
                    onRetry: (_bytes != null && !_working)
                        ? () => _output(share: false)
                        : null,
                  ),
                if (!hasImage)
                  _Chooser(onPick: _pick)
                else
                  ..._editor(context),
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
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Center(
        child: Text(
          'Prints as ${layout.cols}×${layout.rows} '
          '${layout.landscape ? 'landscape' : 'portrait'} · ${layout.pageCount} '
          '${_paperName(layout.paper)} page${layout.pageCount == 1 ? '' : 's'} · '
          'about ${_assembledSize(layout)} assembled\n'
          'Print all ${layout.pageCount}, line them up, and tape them together.',
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
          onSelectionChanged: (s) =>
              setState(() => _opts = _opts.copyWith(size: s.first)),
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
        onChanged: (v) => setState(() => _opts = _opts.copyWith(fitShape: v)),
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
          onSelectionChanged: (s) =>
              setState(() => _opts = _opts.copyWith(fit: s.first)),
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
      _label(context, 'Paper'),
      const SizedBox(height: 6),
      Align(
        alignment: Alignment.centerLeft,
        child: SegmentedButton<PosterPaper>(
          segments: const [
            ButtonSegment(value: PosterPaper.letter, label: Text('Letter')),
            ButtonSegment(value: PosterPaper.a4, label: Text('A4')),
          ],
          selected: {_opts.paper},
          onSelectionChanged: (s) =>
              setState(() => _opts = _opts.copyWith(paper: s.first)),
        ),
      ),
      const SizedBox(height: 8),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Corner labels'),
        subtitle: const Text(
          'Print a small row/column tag in each page corner so you know how '
          'to line them up',
        ),
        value: _opts.labels,
        onChanged: (v) => setState(() => _opts = _opts.copyWith(labels: v)),
      ),
      const SizedBox(height: 4),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _working ? null : _showSourceSheet,
          icon: const Icon(Icons.refresh),
          label: const Text('Replace image'),
        ),
      ),
    ];
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
  const _Chooser({required this.onPick});

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
            'Pick an image and we’ll split it across several letter pages. '
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
class _PosterPreview extends StatelessWidget {
  const _PosterPreview({
    required this.bytes,
    required this.layout,
    required this.fit,
    required this.labels,
  });

  final Uint8List bytes;
  final PosterLayout layout;
  final PosterFit fit;
  final bool labels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFill = fit == PosterFit.fill;
    return Semantics(
      label: 'Poster preview — ${layout.cols} by ${layout.rows} pages, '
          '${isFill ? 'edge to edge' : 'whole image'}. The lines show where '
          'the pages divide.',
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
                Image.memory(
                  bytes,
                  fit: isFill ? BoxFit.cover : BoxFit.contain,
                  gaplessPlayback: true,
                ),
                CustomPaint(
                  painter: _GridPainter(
                    cols: layout.cols,
                    rows: layout.rows,
                    labels: labels,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
  const _WorkingBanner();

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
  const _ErrorBanner({required this.message, this.onRetry});

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
