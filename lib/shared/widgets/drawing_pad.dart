import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart' show XFile;

/// A finger/stylus **drawing surface** shared by the kid "draw yourself" screen
/// (`DrawSelfScreen`) and the Heroes creator. One drawing is held as a list of
/// strokes, painted onto warm opaque paper, and rasterised to a PNG — the SAME
/// [XFile] shape `image_picker` returns, so a drawing flows through the
/// identical photo-upload pipeline (compression, the private bucket, the
/// offline upload queue) with no special-casing downstream.
///
/// The surface itself is a RAW canvas — warm paper + a fixed, kid-legible
/// palette + dark drawing chrome. Those colors are CONTENT, not theme (a brush
/// red is a brush red in light and dark); the file is on the raw-canvas
/// allowlist in `scripts/check_theme_adherence.sh`. Host chrome that *launches*
/// the pad (a button, a form row) stays themed.

/// One pen stroke — a color, a width, and the points it passes through.
class DrawingStroke {
  DrawingStroke({
    required this.color,
    required this.width,
    required this.points,
  });

  final Color color;
  final double width;
  final List<Offset> points;
}

/// Fat, bold, kid-legible. The last swatch is paper-coloured — it "erases"
/// against the paper.
const List<Color> kDrawingPalette = <Color>[
  Color(0xFF1A1A1A), // near-black
  Color(0xFFE53935), // red
  Color(0xFFFB8C00), // orange
  Color(0xFFFDD835), // yellow
  Color(0xFF43A047), // green
  Color(0xFF1E88E5), // blue
  Color(0xFF8E24AA), // purple
  Color(0xFF6D4C41), // brown
  Color(0xFFEC407A), // pink
  Color(0xFFFFFDF7), // paper (erase)
];

const List<double> kDrawingWidths = <double>[6, 12, 22];

/// Warm paper. MUST be opaque: the upload path re-encodes to JPEG (no alpha),
/// so a transparent background would otherwise composite to black.
const Color kDrawingPaper = Color(0xFFFFFDF7);

/// The model + imperative handle behind a [DrawingSurface]: holds the strokes,
/// the active pen, and the [boundaryKey] used to rasterise. A `ChangeNotifier`
/// so the surface (and any chrome that reflects "can undo / has drawing")
/// rebuilds as the drawing changes.
class DrawingController extends ChangeNotifier {
  /// Attached to the surface's `RepaintBoundary`; the raster source on save.
  final GlobalKey boundaryKey = GlobalKey();

  final List<DrawingStroke> strokes = <DrawingStroke>[];
  DrawingStroke? active;
  Color color = kDrawingPalette.first;
  double width = kDrawingWidths[1];

  bool get hasDrawing => strokes.isNotEmpty;
  bool get canUndo => strokes.isNotEmpty;

  void startStroke(Offset p) {
    active = DrawingStroke(color: color, width: width, points: <Offset>[p]);
    notifyListeners();
  }

  void extendStroke(Offset p) {
    final a = active;
    if (a == null) return;
    a.points.add(p);
    notifyListeners();
  }

  void endStroke() {
    final a = active;
    if (a == null) return;
    strokes.add(a);
    active = null;
    notifyListeners();
  }

  void undo() {
    if (strokes.isEmpty) return;
    strokes.removeLast();
    notifyListeners();
  }

  void clear() {
    if (strokes.isEmpty && active == null) return;
    strokes.clear();
    active = null;
    notifyListeners();
  }

  void setColor(Color c) {
    color = c;
    notifyListeners();
  }

  void setWidth(double w) {
    width = w;
    notifyListeners();
  }

  /// Rasterise the current drawing to a PNG. Returns null if the boundary isn't
  /// mounted. The scale is capped — the upload path re-encodes to ≤1024px
  /// anyway, so a huge devicePixelRatio on a big tablet is wasted work.
  Future<Uint8List?> rasterize(double pixelRatio) async {
    final boundary =
        boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final scale = pixelRatio.clamp(1.0, 3.0);
    final image = await boundary.toImage(pixelRatio: scale);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }
}

/// The painting surface — a `RepaintBoundary` (isolates repaints AND is the
/// raster source) over a `GestureDetector` feeding the [controller], repainting
/// via a `CustomPaint` as the controller changes.
class DrawingSurface extends StatelessWidget {
  const DrawingSurface({
    required this.controller,
    this.borderRadius = 24,
    super.key,
  });

  final DrawingController controller;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: controller.boundaryKey,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: GestureDetector(
          onPanStart: (d) => controller.startStroke(d.localPosition),
          onPanUpdate: (d) => controller.extendStroke(d.localPosition),
          onPanEnd: (_) => controller.endStroke(),
          child: AnimatedBuilder(
            animation: controller,
            builder: (_, _) => CustomPaint(
              painter: _DrawingPainter(
                strokes: controller.strokes,
                active: controller.active,
              ),
              // A finite size so the paint area fills the bounds the parent
              // (an AspectRatio) gives it.
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawingPainter extends CustomPainter {
  _DrawingPainter({required this.strokes, required this.active});

  final List<DrawingStroke> strokes;
  final DrawingStroke? active;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = kDrawingPaper);
    for (final stroke in strokes) {
      _paintStroke(canvas, stroke);
    }
    final a = active;
    if (a != null) _paintStroke(canvas, a);
  }

  void _paintStroke(Canvas canvas, DrawingStroke stroke) {
    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final points = stroke.points;
    if (points.isEmpty) return;
    if (points.length == 1) {
      // A tap = a dot. Draw a filled circle so it isn't invisible.
      canvas.drawCircle(
        points.first,
        stroke.width / 2,
        Paint()..color = stroke.color,
      );
      return;
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_DrawingPainter old) =>
      old.strokes != strokes ||
      old.active != active ||
      old.active?.points.length != active?.points.length;
}

/// The color + brush-thickness tools, styled for the dark drawing chrome.
/// Reflects + drives the [controller]; [enabled] off while saving.
class DrawingTools extends StatelessWidget {
  const DrawingTools({
    required this.controller,
    this.enabled = true,
    super.key,
  });

  final DrawingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            // Colors.
            SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                itemCount: kDrawingPalette.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final c = kDrawingPalette[i];
                  final selected = c == controller.color;
                  // The last swatch erases against the paper — name it so
                  // VoiceOver doesn't read "Color 10".
                  final isErase = i == kDrawingPalette.length - 1;
                  return Semantics(
                    label: isErase ? 'Erase' : 'Color ${i + 1}',
                    selected: selected,
                    button: true,
                    // 48 dp hit target (rubric E1); 44 dp visible circle.
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: enabled ? () => controller.setColor(c) : null,
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected ? Colors.white : Colors.white24,
                                width: selected ? 4 : 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            // Brush thickness.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final w in kDrawingWidths) ...[
                  Semantics(
                    label: 'Brush size ${kDrawingWidths.indexOf(w) + 1}',
                    selected: w == controller.width,
                    button: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: enabled ? () => controller.setWidth(w) : null,
                      child: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: w == controller.width
                              ? Colors.white24
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Container(
                          width: w + 6,
                          height: w + 6,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Present a full-screen drawing pad and return the drawing as a PNG [XFile]
/// (null if cancelled or left empty). The host-present, staff-facing sibling of
/// the kid `DrawSelfScreen` — NO kid-mode lock; the returned XFile is the same
/// shape the photo pickers return, so the caller treats a drawing exactly like
/// a snapped photo.
Future<XFile?> showDrawingPad(
  BuildContext context, {
  required String title,
  String doneLabel = 'Use this drawing',
}) {
  return Navigator.of(context).push<XFile>(
    MaterialPageRoute<XFile>(
      fullscreenDialog: true,
      builder: (_) => _DrawingPadScreen(title: title, doneLabel: doneLabel),
    ),
  );
}

class _DrawingPadScreen extends StatefulWidget {
  const _DrawingPadScreen({required this.title, required this.doneLabel});

  final String title;
  final String doneLabel;

  @override
  State<_DrawingPadScreen> createState() => _DrawingPadScreenState();
}

class _DrawingPadScreenState extends State<_DrawingPadScreen> {
  final DrawingController _controller = DrawingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChange);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onChange)
      ..dispose();
    super.dispose();
  }

  // The chrome (undo/clear/done enablement) reflects the drawing state.
  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _done() async {
    if (_saving || !_controller.hasDrawing) return;
    setState(() => _saving = true);
    // Capture cross-pop-safe handles BEFORE the await (interaction invariant #3).
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    try {
      final png = await _controller.rasterize(pixelRatio);
      if (png == null) throw StateError('Could not capture the drawing.');
      final file = XFile.fromData(
        png,
        mimeType: 'image/png',
        name: 'drawing.png',
      );
      navigator.pop(file);
    } on Object catch (e, st) {
      if (kDebugMode) debugPrint('[drawing-pad] save failed: $e\n$st');
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't use that drawing — try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // A raw drawing canvas (dark chrome + warm paper) — see the file header.
    return Scaffold(
      backgroundColor: const Color(0xFF2B2A33),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Cancel',
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                    iconSize: 28,
                  ),
                  Expanded(
                    child: Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Undo',
                    onPressed: _controller.canUndo && !_saving
                        ? _controller.undo
                        : null,
                    icon: const Icon(Icons.undo, color: Colors.white),
                    iconSize: 26,
                  ),
                  IconButton(
                    tooltip: 'Clear',
                    onPressed: _controller.hasDrawing && !_saving
                        ? _controller.clear
                        : null,
                    icon: const Icon(Icons.delete_outline, color: Colors.white),
                    iconSize: 26,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: DrawingSurface(controller: _controller),
                  ),
                ),
              ),
            ),
            DrawingTools(controller: _controller, enabled: !_saving),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: SizedBox(
                height: 56,
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _controller.hasDrawing && !_saving ? _done : null,
                  icon: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(
                    _saving ? 'Saving…' : widget.doneLabel,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
