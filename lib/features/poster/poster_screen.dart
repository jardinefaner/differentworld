import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:differentworld/features/poster/poster_engine.dart';
import 'package:differentworld/features/poster/poster_models.dart';
import 'package:differentworld/features/poster/poster_prefs.dart';
import 'package:differentworld/features/poster/poster_text.dart';
import 'package:differentworld/shared/platform.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:differentworld/shared/widgets/primary_action_button.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

/// How the finished poster leaves the app.
enum _PosterDelivery {
  /// Save the multi-page PDF (share sheet → Files / Drive / email → computer).
  savePdf,

  /// Save one image PER PAGE — the same pages the PDF prints, for anyone
  /// who prints images instead of PDFs. Named R1C1, R1C2, … so the taping
  /// order survives the share.
  savePages,

  /// Save the whole poster as ONE giant image (for a print shop / plotter).
  savePng,

  /// Hand the PDF straight to the OS print dialog on this device.
  printPdf,
}

/// `/poster` — the Poster tool. Pick one image, choose a size, and it slices
/// the image across several pages you print and tape together into one big
/// image (a kid's drawing blown up, a welcome banner, a giant map). The grid
/// auto-fits the image's shape (a wide banner tiles wide, a tall portrait
/// tiles tall) so the least gets cropped / wasted. The heavy slicing runs in
/// an isolate; the output is a multi-page PDF (or a single PNG) you save to a
/// computer to print, or send straight to the OS print dialog.
class PosterScreen extends ConsumerStatefulWidget {
  const PosterScreen({this.seedImage, super.key});

  /// An image to start from instead of the chooser — e.g. a kid's Pattern
  /// rasterized into a poster (docs/FEATURE_CHECKLISTS.md, the Artifact
  /// contract). Null = the normal pick-from-gallery / camera flow.
  final Uint8List? seedImage;

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
  // Which output the last attempt used, so the error banner can retry it.
  _PosterDelivery _lastDelivery = _PosterDelivery.savePdf;
  // Determinate render progress (pages encoded / total) while _working. 0/0
  // before the first tile lands — the banner shows an indeterminate bar then.
  int _progressDone = 0;
  int _progressTotal = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Restore the teacher's last size / fit / paper / labels choices.
    unawaited(
      PosterPrefs.load().then((saved) {
        if (mounted) setState(() => _opts = saved);
      }),
    );
    // Seeded from another tool (e.g. a Pattern): skip the chooser, go straight
    // to the editor with this image + its aspect.
    final seed = widget.seedImage;
    if (seed != null) {
      _bytes = seed;
      unawaited(
        _decodeAspect(seed).then((aspect) {
          if (mounted) setState(() => _imageAspect = aspect);
        }),
      );
    }
  }

  /// The concrete page grid for the current image + options.
  PosterLayout get _layout => computePosterLayout(_opts, _imageAspect);

  bool get _repositioned => _zoom != 1 || _focusX != 0.5 || _focusY != 0.5;

  /// Mutate options + persist so they come back next session.
  void _update(PosterOptions next) {
    // Every option control shares this path — one selection tick for all.
    unawaited(HapticFeedback.selectionClick());
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

  /// Ingest raw image bytes (the sign renderer / a seeded caller) into the
  /// same working state a gallery pick lands in.
  Future<void> _ingestBytes(Uint8List bytes) async {
    final aspect = await _decodeAspect(bytes);
    if (!mounted) return;
    setState(() {
      _bytes = bytes;
      _imageAspect = aspect;
      _zoom = 1;
      _focusX = 0.5;
      _focusY = 0.5;
      _error = null;
    });
  }

  /// "Make a sign" — type the words, render them in the brand serif on warm
  /// paper, and drop the result into the normal poster pipeline.
  Future<void> _makeSign() async {
    if (_working) return;
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Make a sign'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Welcome to Maple Room',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Make it big'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text == null || text.isEmpty || !mounted) return;
    final bytes = await renderTextPoster(text);
    if (!mounted) return;
    await _ingestBytes(bytes);
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
        // A fresh image starts on WHOLE — never silently carry a prior "Fill"
        // (which crops) onto a new image. Fill is destructive + image-specific
        // (it owns the per-image zoom/focus we just reset), so it's a
        // deliberate opt-in per image, not a sticky global. This was the
        // "parts of the image aren't printing" bug: Fill stuck from a past use.
        _opts = _opts.copyWith(fit: PosterFit.whole);
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
            // No in-app camera on web/desktop — offering it there is a dead
            // button (docs/PLATFORM_RUBRIC.md P1). Gallery still works
            // everywhere, so the sheet keeps its point.
            if (isMobileCapturePlatform)
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

  /// Render + deliver the poster. PDF (paged, to tape) or PNG (one image),
  /// saved via the share sheet (→ Files / Drive / email, i.e. onto a
  /// computer) or sent straight to the OS print dialog.
  Future<void> _export(_PosterDelivery delivery) async {
    final bytes = _bytes;
    if (bytes == null || _working) return;
    final layout = _layout;
    final onePng = delivery == _PosterDelivery.savePng;
    setState(() {
      _working = true;
      _lastDelivery = delivery;
      _error = null;
      _progressDone = 0;
      // The giant single image has no per-page count → indeterminate banner.
      _progressTotal = onePng ? 0 : layout.pageCount;
    });
    final tag = '${layout.cols}×${layout.rows}';
    final stem = 'poster-${layout.cols}x${layout.rows}';
    try {
      switch (delivery) {
        case _PosterDelivery.savePdf:
        case _PosterDelivery.printPdf:
          final pdf = await renderPosterPdf(
            bytes,
            layout,
            _opts.fit,
            labels: _opts.labels,
            title: 'Poster $tag',
            assembly: _opts.assembly,
            marks: _opts.effectiveMarks,
            zoom: _zoom,
            focusX: _focusX,
            focusY: _focusY,
            quality: _opts.quality,
            onProgress: (done, total) {
              if (!mounted) return;
              setState(() {
                _progressDone = done;
                _progressTotal = total;
              });
            },
          );
          if (!mounted) return;
          if (delivery == _PosterDelivery.printPdf) {
            await Printing.layoutPdf(onLayout: (_) => pdf, name: 'Poster $tag');
          } else {
            await Printing.sharePdf(bytes: pdf, filename: '$stem.pdf');
          }
        case _PosterDelivery.savePages:
          // The SAME tiles the PDF prints (guides margin included), shared
          // as one image file per page so what you save matches the preview.
          final tiles = await renderPosterTiles(
            bytes,
            layout,
            _opts.fit,
            assembly: _opts.assembly,
            marks: _opts.effectiveMarks,
            zoom: _zoom,
            focusX: _focusX,
            focusY: _focusY,
            quality: _opts.quality,
            onProgress: (done, total) {
              if (!mounted) return;
              setState(() {
                _progressDone = done;
                _progressTotal = total;
              });
            },
          );
          if (!mounted) return;
          // Tiles are JPEG except on lossless (PNG) — name them honestly.
          final png = _opts.quality == PosterQuality.lossless;
          await _shareManyBytes([
            for (var i = 0; i < tiles.length; i++)
              (
                '$stem-R${i ~/ layout.cols + 1}C${i % layout.cols + 1}'
                    '.${png ? 'png' : 'jpg'}',
                tiles[i],
              ),
          ], png ? 'image/png' : 'image/jpeg');
        case _PosterDelivery.savePng:
          final png = await renderPosterImagePng(
            bytes,
            layout,
            _opts.fit,
            zoom: _zoom,
            focusX: _focusX,
            focusY: _focusY,
            quality: _opts.quality,
          );
          if (!mounted) return;
          await _shareBytes(png, '$stem.png', 'image/png');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_outcomeMessage(delivery, layout.pageCount))),
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

  /// Save arbitrary bytes via the share sheet (mirrors the survey export):
  /// in-memory on web, a temp file elsewhere. The share sheet is the path
  /// onto a computer — "Save to Files", Drive, AirDrop, or email-to-self.
  Future<void> _shareBytes(
    Uint8List bytes,
    String filename,
    String mime,
  ) async {
    if (kIsWeb) {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, name: filename, mimeType: mime)],
          fileNameOverrides: [filename],
        ),
      );
      return;
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }

  /// Share several files at once (the per-page image export). Same web /
  /// device split as [_shareBytes].
  Future<void> _shareManyBytes(
    List<(String, Uint8List)> files,
    String mime,
  ) async {
    if (kIsWeb) {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            for (final (name, bytes) in files)
              XFile.fromData(bytes, name: name, mimeType: mime),
          ],
          fileNameOverrides: [for (final (name, _) in files) name],
        ),
      );
      return;
    }
    final dir = await getTemporaryDirectory();
    final paths = <String>[];
    for (final (name, bytes) in files) {
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(bytes);
      paths.add(file.path);
    }
    await SharePlus.instance.share(
      ShareParams(files: [for (final p in paths) XFile(p)]),
    );
  }

  String _outcomeMessage(_PosterDelivery delivery, int pages) =>
      switch (delivery) {
        _PosterDelivery.printPdf =>
          'Sent to print — $pages pages. Print at 100%, then tape them!',
        _PosterDelivery.savePdf =>
          'PDF saved ($pages pages). Open it on a computer and print at 100%.',
        _PosterDelivery.savePages =>
          '$pages page images saved. Print each at 100%, then tape them!',
        _PosterDelivery.savePng =>
          'One full-size image saved — hand it to a print shop.',
      };

  Future<void> _showExportSheet() {
    final layout = _layout;
    return showGlassSheet<void>(
      context: context,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text(
                  'Save your poster',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: _HowToPrint(
                  pageCount: layout.pageCount,
                  assembly: _opts.assembly,
                  overlapIn: _opts.overlapIn,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: const Text('Save as PDF'),
                subtitle: Text(
                  '${layout.pageCount} pages to print and tape together',
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_export(_PosterDelivery.savePdf));
                },
              ),
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('Save as images'),
                subtitle: Text(
                  '${layout.pageCount} image files — one per page, same as '
                  'the preview',
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_export(_PosterDelivery.savePages));
                },
              ),
              ListTile(
                leading: const Icon(Icons.wallpaper_outlined),
                title: const Text('One giant image'),
                subtitle: const Text(
                  'The whole poster as a single full-size file — for a '
                  'print shop, not a home printer',
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_export(_PosterDelivery.savePng));
                },
              ),
              ListTile(
                leading: const Icon(Icons.print_outlined),
                title: const Text('Print from this device'),
                subtitle: const Text('Opens your phone’s print dialog'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_export(_PosterDelivery.printPdf));
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _bytes != null;
    return EdgeScaffold(
      actions: [
        PrimaryActionButton(
          tooltip: 'Save or print',
          icon: Icons.save_alt,
          onPressed: (hasImage && !_working) ? _showExportSheet : null,
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
                  subtitle:
                      'Blow up an image across printed pages you tape '
                      'together',
                ),
                // Banners ease in/out instead of snapping the layout.
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  alignment: Alignment.topCenter,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_working)
                        _WorkingBanner(
                          key: const ValueKey('poster-working'),
                          done: _progressDone,
                          total: _progressTotal,
                        ),
                      if (_error != null)
                        _ErrorBanner(
                          key: const ValueKey('poster-error'),
                          message: _error!,
                          // Retry the SAME action that failed, and only when
                          // there's an image to retry with.
                          onRetry: (_bytes != null && !_working)
                              ? () => _export(_lastDelivery)
                              : null,
                        ),
                    ],
                  ),
                ),
                // Chooser ↔ editor crossfade (with a whisper of rise) —
                // landing an image should feel like arriving, not swapping.
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.02),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: !hasImage
                      ? _Chooser(
                          key: const ValueKey('poster-chooser'),
                          onPick: _pick,
                          onMakeSign: () => unawaited(_makeSign()),
                        )
                      : Column(
                          key: const ValueKey('poster-editor'),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: _editor(context),
                        ),
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
          // Grid/orientation changes glide between shapes instead of
          // snapping — the preview is the screen's anchor; it should move
          // like paper, not flicker like state.
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: layout.canvasAspect),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            builder: (context, aspect, child) =>
                AspectRatio(aspectRatio: aspect, child: child),
            child: _PosterPreview(
              bytes: _bytes!,
              layout: layout,
              fit: _opts.fit,
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
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            'Prints as ${layout.cols}×${layout.rows} '
            '${layout.landscape ? 'landscape' : 'portrait'} · ${layout.pageCount} '
            '${_paperName(layout.paper)} page${layout.pageCount == 1 ? '' : 's'} · '
            'about ${_assembledSize(layout)} assembled\n'
            '${_assemblySummary(layout)}'
            '${_opts.insetPages ? '\nIncludes an assembly map page.' : ''}',
            key: ValueKey(
              '${layout.cols}-${layout.rows}-${layout.landscape}-'
              '${layout.paper}-${_opts.assembly}-${_opts.effectiveOverlapIn}',
            ),
            textAlign: TextAlign.center,
            style: caption,
          ),
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
            // 0 = pick the exact grid yourself below.
            ButtonSegment(value: 0, label: Text('Custom')),
          ],
          selected: {
            if (_opts.hasCustomGrid) 0 else _opts.size,
          },
          onSelectionChanged: (s) {
            final v = s.first;
            if (v == 0) {
              // Enter custom mode seeded from the current derived grid.
              _update(
                _opts.copyWith(
                  customCols: _layout.cols.clamp(1, 6),
                  customRows: _layout.rows.clamp(1, 6),
                ),
              );
            } else {
              _update(_opts.copyWith(size: v, customCols: 0, customRows: 0));
            }
          },
        ),
      ),
      const SizedBox(height: 4),
      // The custom rows reveal / retract as one smooth motion.
      AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: !_opts.hasCustomGrid
              ? [Text('Pages along the poster’s longest edge.', style: caption)]
              : [
                  Text(
                    'Pick the exact page grid — wide × tall.',
                    style: caption,
                  ),
                  const SizedBox(height: 8),
                  _gridChips(
                    context,
                    label: 'Wide',
                    value: _opts.customCols,
                    onPick: (v) => _update(_opts.copyWith(customCols: v)),
                  ),
                  const SizedBox(height: 6),
                  _gridChips(
                    context,
                    label: 'Tall',
                    value: _opts.customRows,
                    onPick: (v) => _update(_opts.copyWith(customRows: v)),
                  ),
                ],
        ),
      ),
      const SizedBox(height: 4),
      if (!_opts.hasCustomGrid)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Fit to image shape'),
          subtitle: const Text(
            'Auto-pick the grid so a wide or tall image isn’t cropped hard or '
            'printed with big margins',
          ),
          value: _opts.fitShape,
          onChanged: (v) => _update(_opts.copyWith(fitShape: v)),
        ),
      const SizedBox(height: 12),
      _label(context, 'Fit'),
      const SizedBox(height: 6),
      Align(
        alignment: Alignment.centerLeft,
        child: SegmentedButton<PosterFit>(
          // Whole image leads — it's the default and keeps everything.
          segments: const [
            ButtonSegment(
              value: PosterFit.whole,
              label: Text('Whole image'),
              icon: Icon(Icons.fit_screen_outlined),
            ),
            ButtonSegment(
              value: PosterFit.fill,
              label: Text('Edge to edge'),
              icon: Icon(Icons.crop_free),
            ),
          ],
          selected: {_opts.fit},
          onSelectionChanged: (s) => _update(_opts.copyWith(fit: s.first)),
        ),
      ),
      const SizedBox(height: 4),
      if (_opts.fit == PosterFit.fill)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: theme.colorScheme.error,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Crops anything outside the grid — parts of the image won’t '
                'print. Use “Whole image” to keep all of it.',
                style: caption?.copyWith(color: theme.colorScheme.error),
              ),
            ),
          ],
        )
      else
        Text(
          'Keeps the whole image — nothing cut off. Thin white borders where '
          'the shape doesn’t match the pages.',
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
            // Page orientation moved here (off first paint) so Size + Fit lead
            // (poster was 🔴 — docs/CLARITY_RUBRIC.md). Auto handles it for
            // most; the override lives with the other print details.
            _label(context, 'Page orientation'),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<PosterOrientation>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: PosterOrientation.auto,
                    label: Text('Auto', overflow: TextOverflow.ellipsis),
                    icon: Icon(Icons.auto_awesome_outlined),
                  ),
                  ButtonSegment(
                    value: PosterOrientation.portrait,
                    label: Text('Portrait', overflow: TextOverflow.ellipsis),
                    icon: Icon(Icons.crop_portrait),
                  ),
                  ButtonSegment(
                    value: PosterOrientation.landscape,
                    label: Text('Landscape', overflow: TextOverflow.ellipsis),
                    icon: Icon(Icons.crop_landscape),
                  ),
                ],
                selected: {_opts.orientation},
                onSelectionChanged: (s) =>
                    _update(_opts.copyWith(orientation: s.first)),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              switch (_opts.orientation) {
                PosterOrientation.auto =>
                  'Picks the page turn that best fits the image.',
                PosterOrientation.portrait =>
                  'Forces every page portrait (tall).',
                PosterOrientation.landscape =>
                  'Forces every page landscape (wide).',
              },
              style: caption,
            ),
            const SizedBox(height: 16),
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
              title: const Text('Alignment marks'),
              subtitle: const Text(
                'Tiny ticks on both sides of every seam — slide the pages '
                'until the ticks join and everything is lined up. With a '
                'seam cushion it\u2019s a dashed line showing exactly where '
                'the next page lands instead — completely hidden once the '
                'pages overlap.',
              ),
              value: _opts.effectiveMarks,
              onChanged: _opts.assembly == PosterAssembly.panels
                  ? null
                  : (v) => _update(_opts.copyWith(marks: v)),
            ),
            const SizedBox(height: 8),
            _label(context, 'Putting it together'),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<PosterAssembly>(
                segments: const [
                  ButtonSegment(
                    value: PosterAssembly.panels,
                    label: Text('Panels'),
                    icon: Icon(Icons.grid_view_outlined),
                  ),
                  ButtonSegment(
                    value: PosterAssembly.fold,
                    label: Text('Fold'),
                    icon: Icon(Icons.flip_to_back_outlined),
                  ),
                  ButtonSegment(
                    value: PosterAssembly.trim,
                    label: Text('Trim'),
                    icon: Icon(Icons.content_cut),
                  ),
                  ButtonSegment(
                    value: PosterAssembly.tape,
                    label: Text('Tape'),
                    icon: Icon(Icons.link),
                  ),
                ],
                selected: {_opts.assembly},
                onSelectionChanged: (sel) =>
                    _update(_opts.copyWith(assembly: sel.first)),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: Text(_assemblyHint(_opts.assembly), style: caption),
            ),
            const SizedBox(height: 8),
            _label(context, 'Seam cushion'),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<double>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('None')),
                  ButtonSegment(value: 0.25, label: Text('¼ inch')),
                  ButtonSegment(value: 0.5, label: Text('½ inch')),
                ],
                selected: {_opts.overlapIn},
                onSelectionChanged: (sel) =>
                    _update(_opts.copyWith(overlapIn: sel.first)),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: Text(
                _opts.overlapIn > 0
                    ? 'Every seam prints on both pages, so you can lay each '
                          'page over the last — an uneven cut just disappears '
                          'into the shared strip.'
                    : 'For imperfect scissors: print a shared strip on both '
                          'sides of every seam, then overlap the pages.',
                style: caption,
              ),
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
    PosterQuality.standard => 'Smaller files, quick — good for most photos.',
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
      if (_opts.effectiveMarks) 'marks',
      _assemblyLabel(_opts.assembly),
      if (_opts.effectiveOverlapIn > 0)
        '${_ovLabel(_opts.effectiveOverlapIn)} cushion',
    ];
    return parts.join(' · ');
  }

  String _paperName(PosterPaper p) => p == PosterPaper.a4 ? 'A4' : 'letter';

  String _ovLabel(double inches) => inches >= 0.5 ? '½″' : '¼″';

  /// The one-line "what you'll physically do" under the size read-out.
  String _assemblySummary(PosterLayout l) {
    final n = l.pageCount;
    return switch (_opts.assembly) {
      PosterAssembly.panels =>
        'Print all $n and butt them together — no cutting; the white borders '
            'become even gutters.',
      PosterAssembly.fold =>
        'Print all $n, fold each page’s top and left border behind it, and '
            'lay it over its neighbour.',
      PosterAssembly.trim =>
        'Print all $n, trim each on the dashed line, then butt and tape.',
      PosterAssembly.tape =>
        _opts.overlapIn > 0
            ? 'Print all $n and overlap each page onto the last — the '
                  '${_ovLabel(_opts.overlapIn)} shared strip hides uneven cuts.'
            : 'Print all $n, line them up, and tape them together.',
    };
  }

  String _assemblyLabel(PosterAssembly a) => switch (a) {
    PosterAssembly.panels => 'panels',
    PosterAssembly.fold => 'fold',
    PosterAssembly.trim => 'trim',
    PosterAssembly.tape => 'tape',
  };

  String _assemblyHint(PosterAssembly a) => switch (a) {
    PosterAssembly.panels =>
      'No cutting at all. Each page prints inside a white border; butt them '
          'together and the borders become even gutters, like split-canvas '
          'wall art.',
    PosterAssembly.fold =>
      'No cutting. Fold each page’s top and left border behind it on the '
          'printed line, then lay it over its neighbour. A crease can be '
          'redone — a cut can’t.',
    PosterAssembly.trim =>
      'Seamless, but needs a steady hand: trim every page on the dashed line, '
          'then butt and tape.',
    PosterAssembly.tape =>
      'Simplest: print edge to edge and tape from behind. Your printer’s own '
          'border may trim a sliver off each page.',
  };

  String _assembledSize(PosterLayout l) {
    if (l.paper == PosterPaper.a4) {
      final w = (l.assembledWidthIn * 2.54).round();
      final h = (l.assembledHeightIn * 2.54).round();
      return '$w × $h cm';
    }
    final base =
        '${_inches(l.assembledWidthIn)}″ × ${_inches(l.assembledHeightIn)}″';
    // Big posters read better in feet — "50″" means little at a glance.
    if (l.assembledWidthIn >= 24 || l.assembledHeightIn >= 24) {
      return '$base  (${_feet(l.assembledWidthIn)} × '
          '${_feet(l.assembledHeightIn)})';
    }
    return base;
  }

  String _feet(double inches) {
    final ft = inches ~/ 12;
    final rem = (inches - ft * 12).round();
    if (ft == 0) return '$rem in';
    return rem == 0 ? '$ft ft' : '$ft ft $rem in';
  }

  /// One row of 1-6 grid chips for the custom wide/tall pick.
  Widget _gridChips(
    BuildContext context, {
    required String label,
    required int value,
    required ValueChanged<int> onPick,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: Wrap(
            spacing: 4,
            children: [
              for (var n = 1; n <= 6; n++)
                ChoiceChip(
                  label: Text('$n'),
                  visualDensity: VisualDensity.compact,
                  selected: value == n,
                  onSelected: (_) => onPick(n),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _label(BuildContext context, String text) => Text(
    text,
    style: Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
  );
}

String _inches(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

/// The empty state: pick a source to start.
class _Chooser extends StatelessWidget {
  const _Chooser({required this.onPick, required this.onMakeSign, super.key});

  final Future<void> Function(ImageSource) onPick;
  final VoidCallback onMakeSign;

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
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onMakeSign,
            icon: const Icon(Icons.title),
            label: const Text('Make a sign'),
          ),
        ],
      ),
    );
  }
}

/// WYSIWYG preview: the image framed exactly as it'll print, with faint page
/// cut-lines overlaid so you see where it splits — nothing drawn over the art.
/// In Fill mode it's interactive — drag to pan the crop, pinch to zoom — and
/// the framing (`Transform.scale` + cover alignment) mirrors the engine's
/// [posterViewRect] one-to-one, so what you set is what prints.
class _PosterPreview extends StatefulWidget {
  const _PosterPreview({
    required this.bytes,
    required this.layout,
    required this.fit,
    required this.zoom,
    required this.focusX,
    required this.focusY,
    required this.onReposition,
  });

  final Uint8List bytes;
  final PosterLayout layout;
  final PosterFit fit;
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
      label:
          'Poster preview — ${widget.layout.cols} by ${widget.layout.rows} '
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
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: CustomPaint(
                    key: ValueKey(
                      'grid-${widget.layout.cols}x${widget.layout.rows}-'
                      '${widget.layout.overlapIn}',
                    ),
                    painter: _GridPainter(
                      cols: widget.layout.cols,
                      rows: widget.layout.rows,
                      ovFracX: posterOverlapFrac(
                        widget.layout.overlapIn,
                        widget.layout.pageWidthIn,
                      ),
                      ovFracY: posterOverlapFrac(
                        widget.layout.overlapIn,
                        widget.layout.pageHeightIn,
                      ),
                    ),
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
            final fx =
                (widget.focusX -
                        details.focalPointDelta.dx / boxW / widget.zoom)
                    .clamp(0.0, 1.0);
            final fy =
                (widget.focusY -
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
  _GridPainter({
    required this.cols,
    required this.rows,
    this.ovFracX = 0,
    this.ovFracY = 0,
  });

  final int cols;
  final int rows;

  /// Seam cushion as a fraction of one page (0 = pages abut). With a
  /// cushion, each interior seam is a shared BAND (both pages print it),
  /// so the preview shows a band, not a line.
  final double ovFracX;
  final double ovFracY;

  @override
  void paint(Canvas canvas, Size size) {
    // FAINT hairlines — show WHERE the pages split without hiding the art
    // beneath. NO labels drawn over the image: the preview stays clean so you
    // can read your whole picture. (The "R1·C2" registration labels, when on,
    // print only in the page corners — a white chip per cell here was
    // covering the content, which is the bug this removes.)
    final under = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..strokeWidth = 1;
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    final band = Paint()..color = Colors.white.withValues(alpha: 0.22);

    // Shingled span in page units — with no cushion this is just cols/rows
    // and the bands collapse to the classic single seam lines.
    final unitsX = 1 + (cols - 1) * (1 - ovFracX);
    final unitsY = 1 + (rows - 1) * (1 - ovFracY);

    void vSeam(double x0, double x1) {
      if (x1 - x0 >= 1) {
        canvas.drawRect(Rect.fromLTRB(x0, 0, x1, size.height), band);
      }
      for (final x in [x0, if (x1 - x0 >= 1) x1]) {
        canvas
          ..drawLine(Offset(x, 0), Offset(x, size.height), under)
          ..drawLine(Offset(x, 0), Offset(x, size.height), line);
      }
    }

    void hSeam(double y0, double y1) {
      if (y1 - y0 >= 1) {
        canvas.drawRect(Rect.fromLTRB(0, y0, size.width, y1), band);
      }
      for (final y in [y0, if (y1 - y0 >= 1) y1]) {
        canvas
          ..drawLine(Offset(0, y), Offset(size.width, y), under)
          ..drawLine(Offset(0, y), Offset(size.width, y), line);
      }
    }

    for (var c = 1; c < cols; c++) {
      final start = c * (1 - ovFracX) / unitsX * size.width;
      vSeam(start, start + ovFracX / unitsX * size.width);
    }
    for (var r = 1; r < rows; r++) {
      final start = r * (1 - ovFracY) / unitsY * size.height;
      hSeam(start, start + ovFracY / unitsY * size.height);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.cols != cols ||
      old.rows != rows ||
      old.ovFracX != ovFracX ||
      old.ovFracY != ovFracY;
}

/// Determinate render progress. While the worker streams page counts the bar
/// fills "page N of M"; before the first tile (or on web, where the count
/// can't stream) it shows an indeterminate bar so it never looks stuck at 0.
class _WorkingBanner extends StatelessWidget {
  const _WorkingBanner({required this.done, required this.total, super.key});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasCount = total > 0 && done > 0;
    final binding = total > 0 && done >= total;
    // During the binding phase the count is done but the PDF is still
    // being stitched — switch to an indeterminate bar so the motion
    // itself says "alive" (the bind runs in an isolate, so it animates).
    final value = binding
        ? null
        : hasCount
        ? (done / total).clamp(0.0, 1.0)
        : null;
    final String label;
    if (binding) {
      label = 'Stitching the pages into one file…';
    } else if (hasCount) {
      label = 'Rendering page $done of $total…';
    } else {
      label = 'Preparing your poster…';
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label, style: theme.textTheme.bodyMedium),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 6,
              // Voice the same "page N of M" text so the progress is reachable
              // from the bar itself, not only the sibling Text (E2).
              semanticsLabel: label,
            ),
          ),
        ],
      ),
    );
  }
}

/// The "exactly what to do" card shown in the export sheet. Step 3 (print at
/// 100% / actual size) is the one that actually keeps the tiles lined up — a
/// printer "fit to page" silently rescales every page and breaks the seams.
class _HowToPrint extends StatelessWidget {
  const _HowToPrint({
    required this.pageCount,
    required this.assembly,
    this.overlapIn = 0,
  });

  final int pageCount;
  final PosterAssembly assembly;
  final double overlapIn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Wrapped strings live in locals (not inline list elements) to avoid the
    // adjacent-strings-in-list footgun.
    const printStep =
        'Print at 100% / “Actual size” — turn OFF “Fit to page” '
        '/ “Scale to fit”. This is what keeps the pieces lined up.';
    // Every wrapped string lives in a local — adjacent string literals
    // directly inside a list literal are the documented footgun here.
    const panelsLay =
        'Lay the pages out in order (R1-C1 at the top-left), edges touching.';
    const panelsTape =
        'Tape them together from behind. The white borders line up into even '
        'gutters — that’s the look, not a mistake.';
    const foldCrease =
        'On every page except the top row and left column, fold the top and '
        'left border behind the page, creasing on the printed line. A ruler '
        'edge helps, and a crease that’s off can just be redone.';
    const foldOverlap =
        'Lay each folded page over its neighbour and slide until the picture '
        'matches — the shared strip means the exact position is free. Tape '
        'the overlap flat.';
    const foldButt =
        'Butt each folded edge against its neighbour’s picture and tape from '
        'behind.';
    const trimCut = 'Trim each page on the dashed line.';
    const trimTape =
        'Line them up (R1-C1 at the top-left) and tape from behind.';
    final tapeOverlap =
        'Lay the $pageCount pages out in order, overlapping each onto the one '
        'before it — match the picture across the shared strip, then tape the '
        'overlap flat. Any trimming can be rough: the strip swallows an '
        'uneven cut.';
    final tapePlain =
        'Lay the $pageCount pages out in order and tape them together.';
    final assembleSteps = switch (assembly) {
      // No blade, no crease — the only skill is laying paper on a table.
      PosterAssembly.panels => const [panelsLay, panelsTape],
      PosterAssembly.fold => [
        foldCrease,
        if (overlapIn > 0) foldOverlap else foldButt,
      ],
      PosterAssembly.trim => const [trimCut, trimTape],
      PosterAssembly.tape => [if (overlapIn > 0) tapeOverlap else tapePlain],
    };
    final steps = <String>[
      'Save it to your phone (Files or Drive), or email it to yourself.',
      'Open the file on your computer.',
      printStep,
      ...assembleSteps,
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'How to print it',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${i + 1}.  ',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Expanded(
                    child: Text(steps[i], style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
          // Seam guidance — only for plain edge-to-edge taping with no
          // cushion (the at-risk case; every other mode already prints a
          // border, and the cushion makes trimming forgiving).
          if (assembly == PosterAssembly.tape && overlapIn <= 0) ...[
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.content_cut,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'White borders at the seams? Most printers can’t print to '
                    'the edge. Switch “Putting it together” to Panels (no '
                    'cutting) or Fold — or print Borderless.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
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
